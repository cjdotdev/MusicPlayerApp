// ignore_for_file: must_be_immutable
import "package:isar_community/isar.dart";
import "package:equatable/equatable.dart";
import "package:on_audio_query/on_audio_query.dart";

part "music_modal.g.dart";

@Collection(ignore: {'props'})
class Song extends Equatable 
{
    Id? id = Isar.autoIncrement;
    final String systemId;// Attribute tied to the Android indexation of the song on the device 
    final String title;
    final String? artist;
    final String filePath ;
    final Duration? duration;
    final DateTime dateAdded ;
    final double? filesize;

    Song({
        required this.systemId,
        required this.title,
        required this.filePath,
        this.artist,
        this.duration,
        this.filesize,
    }) : dateAdded = DateTime.now(); // Expression used in Dart to assign a specific value to an attribute of a class on the fly during the creation of a specific instance 


    /// A factory constructor used to transform the native instance by running 
    /// calculations and normalization changes on its properties.
    factory Song.fromDeviceToNativeSongModel(SongModel nativeSongModel)
    {
      final rawBytes = nativeSongModel.size;
      final double filesize = double.parse((rawBytes / (1024 * 1024)).toStringAsFixed(2));

      return Song(
          systemId: nativeSongModel.id.toString(),
          title : nativeSongModel.title,
          filePath: nativeSongModel.data,
          artist: nativeSongModel.artist ?? "Unknown artist",
          duration: Duration(
           minutes : (nativeSongModel.duration ?? 0) ~/ 60000, //Complex Mathematical Process used to turn the raw files duration into minutes and seconds
           seconds : ((nativeSongModel.duration ?? 0) ~/ 1000) % 60 
          ),
          filesize: filesize 
      );
    }


    @override
    List<Object?> get props => [id,title,dateAdded];// Equatable getter used here to specify how songs should be compared between one another
    
    //Note : Maybe in the future , why not think to add a folder path getter here 

}

@Collection(ignore: {'props'})
class PlaylistEntry extends Equatable
{
    Id id = Isar.autoIncrement;
    late DateTime dateSongAdded; 
    
    final song = IsarLink<Song>();

    @override
    List<Object?> get props => [song,dateSongAdded,id];
}

@Collection(ignore: {'props'})
class Playlist extends Equatable
{

    Id id  = Isar.autoIncrement;
    final String name;
    final DateTime dateCreated;
    final entries = IsarLink<PlaylistEntry>();
    Playlist({
        required this.name,
    }): dateCreated = DateTime.now();

    @override
    List<Object?> get props => [dateCreated,id];
}

@Collection(ignore: {'props'})
class HistoryEntry extends Equatable
{
    Id id = Isar.autoIncrement;
    late DateTime dateSongAdded; 
    final song = IsarLink<Song>();
    late int durationPlayed;

    @override
    List<Object?> get props => [song,dateSongAdded,id];
}

@Collection(ignore: {'props'})
class PlayerHistory extends Equatable
{
    Id id  = Isar.autoIncrement;
    final entries = IsarLink<HistoryEntry>();
    
    @override
    List<Object?> get props => [id];
}

