import 'dart:async';
import 'package:flutter/services.dart';

// ============================================================================
// 1. DEFINE THE ACTIONS
// ============================================================================
// These are the exact same actions we defined in the Kotlin code.
// It tells Flutter whether the song was added/updated or deleted.
enum MediaAction { 
  upsert, // Insert or Update
  delete  // Delete
}

// ============================================================================
// 2. THE DATA PACKAGE (What Flutter actually uses)
// ============================================================================
// Instead of passing around raw, messy Maps, we convert the Kotlin data 
// into a clean, typed Dart class. This prevents typos and crashes later on.
class MediaStoreEvent {
  final MediaAction action;
  final String songId;
  
  // These are null if the action is 'delete' (because a deleted song has no data)
  final String? title;
  final String? artist;
  final int? duration;
  final String? filePath;
  final int? fileSize; // <-- NEW! Added to handle the file size from Kotlin

  MediaStoreEvent({
    required this.action,
    required this.songId,
    this.title,
    this.artist,
    this.duration,
    this.filePath,
    this.fileSize,
  });
}

// ============================================================================
// 3. THE SERVICE (The Bridge to Flutter)
// ============================================================================
class AudioObserverService {
  
  // IMPORTANT: This string MUST match the EVENT_CHANNEL in your Kotlin MainActivity exactly!
  static const EventChannel _eventChannel =
      EventChannel('com.example.music_player/media_store_observer');

  StreamSubscription? _subscription;
  
  // A broadcast stream allows multiple parts of your Flutter app 
  // (like the Library screen and the Search screen) to listen at the same time.
  final StreamController<MediaStoreEvent> _controller =
      StreamController<MediaStoreEvent>.broadcast();

  // This is what your UI or Repository will listen to
  Stream<MediaStoreEvent> get mediaChanges => _controller.stream;

  // Start listening to the native Android side
  void startListening() {
    _subscription?.cancel(); // Cancel any old listeners just in case
    
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      _handleNativeEvent, // <--- This function catches the data from Kotlin
      onError: (error) {
        throw(Exception(error));
      },
    );
  }

  // ========================================================================
  // THE PARSER: Translating Kotlin Maps into Dart Objects
  // ========================================================================
    // ========================================================================
  // THE PARSER: Translating Kotlin Maps into Dart Objects (STRICT MODE)
  // ========================================================================
    void _handleNativeEvent(dynamic event) {
    try {
      // 0. Verify the event is actually a Map
      if (event is! Map) {
        throw FormatException('Invalid event format: Expected a Map, got ${event.runtimeType}');
      }

      // 1. Extract the core identifiers STRICTLY
      final actionStr = event['action'] as String; 
      final songId = event['id'] as String; 
      final title = event['title'] as String;
      final artist = event['artist'] as String;
      final path = event['filePath'] as String;
      final duration = event['duration'] as int; 
      final size = event['fileSize'] as int;      

      // ====================================================================
      // EXPLICIT HANDLING FOR DELETION
      // ====================================================================
      if (actionStr == 'delete') {
        // A deleted song only needs its ID. We don't need title, artist, etc.
        final mediaEvent = MediaStoreEvent(
          action: MediaAction.delete,
          songId: songId,
          title: title,
          filePath : path,
          duration : duration
        );
        
        // Push the deletion event to the stream
        _controller.add(mediaEvent);
        
        // STOP HERE. We are completely done with this event. 
        // The code below will NOT run for deletions.
        return; 
      }

      // ====================================================================
      // EXPLICIT HANDLING FOR UPSERT (ADD/UPDATE)
      // ====================================================================
      // If the code reaches this point, we know it's NOT a delete.
      // Therefore, it MUST be an upsert, and Kotlin MUST have sent metadata.
      
      // STRICT CASTING: If any of these are missing, it throws an error!
      

      final mediaEvent = MediaStoreEvent(
        action: MediaAction.upsert,
        songId: songId,
        title: title,
        artist: artist,
        duration: duration,
        filePath: path,
        fileSize: size,
      );

      // Push the upsert event to the stream
      _controller.add(mediaEvent);

    } catch (e, stackTrace) {
      // If ANYTHING goes wrong (missing keys, wrong types, etc.), 
      // it jumps straight here.
      _controller.addError(e, stackTrace);
      throw(Exception('[AudioObserverService] Failed to parse native event: $e'));
    }
  }
}