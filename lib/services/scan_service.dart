// Import the core audio query package to interact with Android's MediaStore
import "package:on_audio_query/on_audio_query.dart";

// Import the app's internal data models and utility enums
import "package:music_player/models/music_modal.dart";
import "package:music_player/utils/song_sort_option.dart";

// Import for handling raw image bytes (used for album artwork)
import 'dart:typed_data';

/// Service responsible for scanning the device's audio files,
/// filtering out non-music files (like ringtones or app sounds),
/// and extracting metadata such as album artwork.
class ScanAudioService {
  
  // Initialize the OnAudioQuery instance to bridge Flutter with native audio APIs
  final OnAudioQuery _onAudioQuery = OnAudioQuery();

  /// Scans the device for audio files, applies sorting, and filters out
  /// unwanted system/app sounds (e.g., ringtones, WhatsApp audio, cache).
  ///
  /// [sortOptions] determines how the resulting list of songs should be sorted.
  /// Returns a filtered and sorted list of native [Song] models.
  Future<List<Song>> fetchInitialLibrary(SortOptions sortOptions) async {
    
    // Initialize with default values to prevent "uninitialized variable" compile errors 
    // in case a new SortOptions case is added but not handled in the switch statement
    SongSortType songSortType = SongSortType.DATE_ADDED;
    OrderType orderType = OrderType.DESC_OR_GREATER;

    try {
      // Map the app's custom SortOptions enum to the native OnAudioQuery sorting enums
      switch (sortOptions) {
        case SortOptions.recentlyAdded:
          songSortType = SongSortType.DATE_ADDED;
          orderType = OrderType.DESC_OR_GREATER;
          break; // Added break to prevent Dart fall-through compile errors

        case SortOptions.alphabetical:
          songSortType = SongSortType.TITLE;
          orderType = OrderType.ASC_OR_SMALLER;
          break;
      }

      // Query the device's external storage for all audio files using the mapped sort parameters
      final List<SongModel> rawDeviceFiles = await _onAudioQuery.querySongs(
        sortType: songSortType,         
        orderType: orderType,   
        uriType: UriType.EXTERNAL, // Only scan external storage (SD card / internal shared storage)
        ignoreCase: true,          // Ensure case-insensitive sorting (e.g., 'a' and 'A' are treated equally)
      );

      // Initialize an empty list to hold the filtered and mapped songs
      final List<Song> sortedSongList = [];

      // Iterate through each raw audio file found on the device
      for (final rawFile in rawDeviceFiles) {
        
        // --- FILTER 1: Duration Filter ---
        // Drops short audio clips, notification sounds, and ringtones that are under 10 seconds (10,000 ms)
        final int fileDurationMs = rawFile.duration ?? 0;  
        if (fileDurationMs < 10000) continue;

        // --- FILTER 2: System Path Roadblock ---
        // Prevents the app from freezing or cluttering the library with system/app-specific audio
        final String standardizedPath = rawFile.data.toLowerCase();
        
        // Skip files located in Android system directories
        if (standardizedPath.contains('/android/')) continue;
        
        // Skip specific app folders (like WhatsApp voice notes) and cache directories
        if (standardizedPath.contains('whatsapp') || standardizedPath.contains('/cache/')) continue;

        // --- MAPPING ---
        // If the file passes all filters, convert the raw SongModel into the app's native Song model
        sortedSongList.add(Song.fromDeviceToNativeSongModel(rawFile));
      }

      // Return the final clean list of songs
      return sortedSongList;
      
    } catch (e) {
      // Gracefully handle any exceptions (e.g., permission denied, native crash) 
      // by returning an empty list instead of crashing the app
      return [];
    }
  }   

  /// Extracts the album artwork for a specific song.
  ///
  /// [songId] The unique ID of the song in the MediaStore.
  /// Returns the artwork as a JPEG byte array, or null if extraction fails.
  Future<Uint8List?> extractArtwork(String songId) async {
    try {
      // Query the native artwork using the song's ID
      return await _onAudioQuery.queryArtwork(
        int.parse(songId),          // Convert String ID to int required by the native API
        ArtworkType.AUDIO,          // Specify that we are querying audio artwork (not album or artist)
        format: ArtworkFormat.JPEG, // Request the image in JPEG format for optimal size/quality
        size: 300,                  // Resize the image to 300x300 pixels to save memory
      );
    } catch (e) {
      // Return null if the song has no artwork or if an error occurs during extraction
      return null;
    }
  }
}