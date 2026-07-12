import 'dart:typed_data';
import 'package:music_player/models/music_modal.dart';

/// Abstract repository defining the contract for music data operations.
/// 
/// This interface separates the data layer from the business logic,
/// making the code testable and allowing for different implementations
/// (e.g., real implementation, mock for testing, fake for development).
abstract class MusicRepository {
  
  /// Fetches the initial library of songs from the device.
  /// 
  /// This performs a full scan of the device's audio files,
  /// applies filtering (duration, system paths, etc.),
  /// and returns a sorted list of songs.
  /// 
  /// Returns an empty list if an error occurs or no songs are found.
  Future<List<Song>> fetchInitialLibrary();

  /// Watches for real-time changes to the music library.
  /// 
  /// This stream emits a new list of songs whenever:
  /// - A song is added to the device
  /// - A song is deleted from the device
  /// - A song's metadata is updated
  /// - [forceRefresh] is called manually
  /// 
  /// The stream uses a debounced ContentObserver on Android to avoid
  /// excessive updates during bulk operations (e.g., downloading multiple songs).
  Stream<List<Song>> watchLibraryChanges();

  /// Manually triggers a rescan of the music library.
  /// 
  /// This is useful for:
  /// - Pull-to-refresh functionality in the UI
  /// - Recovering from potential missed events
  /// - Forcing an update after a known change
  /// 
  /// The new list will be emitted through [watchLibraryChanges].
  Future<void> forceRefresh();

  /// Extracts the album artwork for a specific song.
  /// 
  /// [songId] The unique identifier of the song in the MediaStore.
  /// 
  /// Returns the artwork as a JPEG-encoded byte array, or `null` if:
  /// - The song has no embedded artwork
  /// - The artwork cannot be extracted
  /// - An error occurs during extraction
  /// 
  /// The returned image is typically resized to optimize memory usage.
  Future<Uint8List?> extractArtwork(String songId);

  /// Cleans up resources when the repository is no longer needed.
  /// 
  /// This should:
  /// - Cancel any active streams
  /// - Unregister observers
  /// - Close database connections
  void dispose();
}