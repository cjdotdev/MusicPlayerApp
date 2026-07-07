import "package:on_audio_query/on_audio_query.dart";
import "package:music_player/models/music_modal.dart";
import "package:music_player/utils/song_sort_option.dart";
import 'dart:typed_data';


class ScanAudioService
{
    final OnAudioQuery _onAudioQuery = OnAudioQuery();
    Future<List<Song>> scanAndFilterMusic(SortOptions sortOptions)
    async{
      SongSortType songSortType ;
      OrderType  orderType;
      try
      {
        switch(sortOptions)
      {
        case SortOptions.recentlyAdded :
         songSortType = SongSortType.DATE_ADDED;
         orderType  = OrderType.DESC_OR_GREATER;

        case SortOptions.alphabetical :
         songSortType = SongSortType.TITLE;
         orderType  = OrderType.ASC_OR_SMALLER;
      }

      final List<SongModel> rawDeviceFiles = await  _onAudioQuery.querySongs(
            sortType: songSortType,         
            orderType: orderType,   
            uriType: UriType.EXTERNAL,            
            ignoreCase: true,                      
      );
      final List<Song> sortedSongList = [];

      for (final rawFile in rawDeviceFiles)
      {
        // Filter 1: The Duration Filter (Drops clips/alerts under 10 seconds)
    final int fileDurationMs = rawFile.duration ?? 0;  
    if (fileDurationMs < 10000) continue;

    // Filter 2: System Path Roadblock (Instant freeze on system directories)
    final String standardizedPath = rawFile.data.toLowerCase();
    if (standardizedPath.contains('/android/')) continue;
    if (standardizedPath.contains('whatsapp') || standardizedPath.contains('/cache/')) continue;

    // Passed Checklist -> Execute Safe Custom Mapping
    sortedSongList.add(Song.fromDeviceToNativeSongModel(rawFile));
      }

  return sortedSongList;
      
    }
    catch(e)
    {
        return [];
    }
 }   
 Future<Uint8List?> extractArtwork(String songId) async {
try {
return await _onAudioQuery.queryArtwork(
int.parse(songId),
ArtworkType.AUDIO,
format: ArtworkFormat.JPEG,
size: 300,
);
} catch (e) {
return null;
}
}
/// 3. Storage State Watchdog (Action E)
/// Live Stream pipeline alerting upper controller states to rerun data cycles / Have to be changed anyway asap
// Stream<void> get onStorageChanged {
// return _onAudioQuery.onDeviceChange;
// }
// }
