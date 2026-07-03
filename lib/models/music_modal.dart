// ignore_for_file: must_be_immutable
import "package:isar_community/isar.dart";
import "package:equatable/equatable.dart";

part "music_modal.g.dart";

@Collection(ignore: {'props'})
class Song extends Equatable 
{
    Id id = Isar.autoIncrement;
    final String title;
    final String? artist;
    final String filePath ;
    final int? duration;
    final DateTime dateAdded ;
    final String? artworkPath;
    final int? filesize;

    Song({
        required this.title,
        required this.filePath,
        this.artist,
        this.duration,
        this.artworkPath,
        this.filesize,
   
    }) : dateAdded = DateTime.now(); // Expression used in Dart to assign a specific value to an attribute of a class on the fly during the creation of a specific instance 

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

