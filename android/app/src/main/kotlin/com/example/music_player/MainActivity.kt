package com.example.music_player // <-- Your package name

import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    // ========================================================================
    // STEP 1: NEED TO TALK TO FLUTTER -> ADD EVENTCHANNEL
    // ========================================================================
    // PROBLEM: Flutter (Dart) and Android (Kotlin) are two completely separate
    // apps. They cannot directly share variables or call each other's functions.
    //
    // SOLUTION: We need a "bridge" to send data from Kotlin to Flutter.
    // An EventChannel is a one-way street that lets Android continuously
    // stream data to Flutter.
    
    // This is the "address" of our bridge. Both Kotlin and Dart must use
    // this exact same string to find each other.
    private val EVENT_CHANNEL = "com.example.music_player/media_store_observer"
    
    // This is the "mailbox" where we drop data for Flutter to pick up.
    // It's nullable because it only exists when Flutter is actively listening.
    private var eventSink: EventChannel.EventSink? = null


    // ========================================================================
    // STEP 3: UI IS FREEZING -> ADD HANDLERTHREAD (BACKGROUND THREAD)
    // ========================================================================
    // PROBLEM: When we detect a file change, we need to query the database
    // to figure out what changed. Database queries take 50-200ms. If we do
    // this on the Main UI Thread, the app will freeze/stutter for 200ms
    // every time a song is added.
    //
    // SOLUTION: We create a dedicated "Background Thread" (a second worker)
    // to handle all the heavy database work. This keeps the Main Thread
    // free to draw the UI smoothly at 60fps.
    
    // We create a brand new background thread and start it immediately.
    // Think of this as hiring a second worker whose ONLY job is to handle
    // database queries.
    private val observerThread = HandlerThread("MediaStoreObserverThread").apply { start() }
    
    // A "Handler" is like a remote control for a specific thread.
    // This handler lets us send tasks to our background worker thread.
    private val bgHandler = Handler(observerThread.looper)
    
    // This is the remote control for the MAIN UI Thread.
    // We'll need this later to safely send data back to Flutter.
    private val mainHandler = Handler(Looper.getMainLooper())


    // ========================================================================
    // STEP 2: NEED TO LISTEN TO ANDROID -> ADD CONTENTOBSERVER
    // ========================================================================
    // PROBLEM: We need Android to tell us when a song is added, deleted,
    // or modified. We can't just check the database every second (that
    // would drain the battery). We need a way for Android to "notify" us.
    //
    // SOLUTION: Android has a built-in class called ContentObserver.
    // It's like a security guard that watches the MediaStore database
    // and rings a bell whenever something changes.
    
    // This variable holds our security guard. It's nullable because we
    // only hire the guard when Flutter starts listening.
    private var contentObserver: ContentObserver? = null


    // ========================================================================
    // STEP 4: ANDROID IS SPAMMING ME -> ADD DEBOUNCE TIMER
    // ========================================================================
    // PROBLEM: When you download a song, Android updates the database 5-10
    // times in rapid succession (creates file, writes metadata, writes
    // artwork, etc.). This means our observer's onChange() fires 10 times
    // in one second. If we query the database 10 times, we waste battery
    // and might crash by reading a half-written file.
    //
    // SOLUTION: We add a "debounce timer". When an event fires, we wait
    // 800ms. If another event fires within those 800ms, we reset the timer.
    // We only do the heavy work when Android stops spamming us for 800ms.
    
    // This holds the URI of the file that changed while we're waiting
    // for the spam to stop.
    private var pendingUri: Uri? = null
    
    // This is our timer task. We can cancel and restart it as needed.
    private var debounceRunnable: Runnable? = null


    // ========================================================================
    // SETTING UP THE BRIDGE (Continuation of Step 1)
    // ========================================================================
    // This function is called automatically by Flutter when the app starts.
    // It's where we build the bridge between Kotlin and Flutter.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // We create the EventChannel bridge and tell it what to do when
        // Flutter starts or stops listening.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                
                // Called when Flutter says "I want to start listening"
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    // Save the mailbox so we can send data to Flutter later
                    eventSink = events
                    // Hire the security guard to start watching the database
                    registerMediaObserver()
                }

                // Called when Flutter says "I'm done listening"
                override fun onCancel(arguments: Any?) {
                    // Clear the mailbox
                    eventSink = null
                    // Fire the security guard
                    unregisterMediaObserver()
                }
            })
    }


    // ========================================================================
    // HIRING THE SECURITY GUARD (Continuation of Step 2)
    // ========================================================================
    // This function creates and registers our ContentObserver.
    private fun registerMediaObserver() {
        // Don't hire a second guard if we already have one
        if (contentObserver != null) return

        // We create our security guard.
        // IMPORTANT: We pass bgHandler here! This tells Android:
        // "When the database changes, run the onChange() function on
        // the BACKGROUND thread, not the Main UI thread."
        // This solves the UI freezing problem (Step 3).
        contentObserver = object : ContentObserver(bgHandler) {

            // This is the bell that rings when the database changes.
            // Android calls this function and passes the URI of the file
            // that changed (e.g., "content://media/external/audio/123")
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)

                // Ignore null URIs (shouldn't happen, but just in case)
                if (uri == null) return

                // ============================================================
                // STEP 4 CONTINUED: THE DEBOUNCE LOGIC
                // ============================================================
                // PROBLEM: Android is spamming us with onChange() calls.
                //
                // SOLUTION: Every time onChange() fires, we cancel any existing
                // timer and start a new 800ms countdown. We only do the heavy
                // work when the timer actually finishes (meaning Android has
                // been quiet for 800ms).
                
                // Cancel any existing timer if a new change happens immediately
                debounceRunnable?.let { mainHandler.removeCallbacks(it) }
                
                // Save the latest URI that changed
                pendingUri = uri

                // Create a new task to run after 800ms of silence
                debounceRunnable = Runnable {
                    // Once the timer finishes, process the change on the
                    // background thread (bgHandler)
                    bgHandler.post { processMediaChange(pendingUri) }
                }
                
                // Start the 800ms countdown
                mainHandler.postDelayed(debounceRunnable!!, 800)
            }
        }

        // Now we officially register the guard with Android and tell it
        // to watch the entire Audio database.
        // IMPORTANT: notifyForDescendants = true means "watch the main folder
        // AND every single song inside it". Without this, we wouldn't detect
        // changes to individual songs.
        contentResolver.registerContentObserver(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            true, // This is CRUCIAL - watch all descendants
            contentObserver!!
        )
    }


    // ========================================================================
    // STEP 5: DON'T KNOW IF IT'S AN ADD OR DELETE -> ADD DATABASE QUERY
    // ========================================================================
    // PROBLEM: The ContentObserver is dumb. It just says "Something changed
    // at URI 123". It doesn't tell us if the song was Added, Updated, or
    // Deleted. We need to figure that out ourselves.
    //
    // SOLUTION: We extract the Song ID from the URI (e.g., "123"), then
    // query the database to ask: "Does a song with ID 123 exist right now?"
    // If yes -> It was Added or Updated.
    // If no -> It was Deleted.
    
    // This function runs on the BACKGROUND thread (thanks to bgHandler).
    // It investigates what actually changed and packages the data for Flutter.
    private fun processMediaChange(uri: Uri?) {
        if (uri == null) return

        try {
            // Extract the specific Song ID from the URI
            // Example: "content://media/external/audio/media/123" -> "123"
            val songId = uri.lastPathSegment ?: return

            // Define which columns we want to read from the database
            val projection = arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.DURATION,
                MediaStore.Audio.Media.DATA // The file path
                MediaStore.Audio.Media.SIZE 
            )

            // We only want to query the specific song that changed
            val selection = "${MediaStore.Audio.Media._ID} = ?"
            val selectionArgs = arrayOf(songId)

            // Query the MediaStore database for this specific song
            // This runs on the background thread, so it won't freeze the UI
            val cursor = contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection, selection, selectionArgs, null
            )

            // ============================================================
            // STEP 6: FLUTTER CRASHED BECAUSE ON WRONG THREAD -> ADD mainHandler.post
            // ============================================================
            // PROBLEM: We're currently on the background thread. But Flutter's
            // EventChannel REQUIRES data to be sent on the Main UI Thread.
            // If we call eventSink?.success() from the background thread,
            // the app will crash with a CalledFromWrongThreadException.
            //
            // SOLUTION: We use mainHandler.post { } to temporarily jump back
            // to the Main Thread just long enough to send the data to Flutter.
            
            mainHandler.post {
                // cursor?.use { } automatically closes the cursor when done
                cursor?.use {
                    if (it.moveToFirst()) {
                        // ====================================================
                        // THE SONG EXISTS IN THE DATABASE
                        // This means it was Added or Updated
                        // ====================================================
                        val songData = mapOf(
                            "systemId" to songId,
                            "title" to it.getString(1),
                            "artist" to it.getString(2),
                            "duration" to it.getInt(3),
                            "filePath" to it.getString(4),
                            "fileSize" to it.getLong(5),
                            "action" to "upsert" // "upsert" = insert or update
                        )
                        // Send the data to Flutter through the EventChannel bridge
                        eventSink?.success(songData)
                    } else {
                        // ====================================================
                        // THE SONG DOES NOT EXIST IN THE DATABASE
                        // This means it was Deleted
                        // ====================================================
                        val deletionData = mapOf(
                            "id" to songId,
                            "action" to "delete"
                        )
                        // Send the deletion event to Flutter
                        eventSink?.success(deletionData)
                    }
                }
            }
        } catch (e: Exception) {
            // If anything goes wrong, send an error to Flutter instead of crashing
            mainHandler.post {
                eventSink?.error("OBSERVER_ERROR", e.message, null)
            }
        }
    }


    // ========================================================================
    // FIRING THE SECURITY GUARD
    // ========================================================================
    // This function unregisters the ContentObserver and cleans up resources.
    private fun unregisterMediaObserver() {
        // Fire the security guard
        contentObserver?.let {
            contentResolver.unregisterContentObserver(it)
            contentObserver = null
        }
        // Cancel any pending debounce timers
        debounceRunnable?.let { mainHandler.removeCallbacks(it) }
    }


    // ========================================================================
    // STEP 7: BATTERY DRAINING WHEN APP CLOSES -> ADD onDESTROY CLEANUP
    // ========================================================================
    // PROBLEM: When the user closes the app, the background thread we created
    // in Step 3 is still running. The ContentObserver is still registered.
    // Android keeps our thread alive in the background, draining the user's
    // battery even though the app is closed. This is a memory leak.
    //
    // SOLUTION: We hook into Android's onDestroy() lifecycle method. When the
    // app is destroyed, we fire the security guard and kill the background thread.
    
    // This function is called automatically by Android when the app is closing.
    override fun onDestroy() {
        // Fire the security guard
        unregisterMediaObserver()
        // Kill the background thread to prevent battery drain
        observerThread.quitSafely()
        // Call the parent class's onDestroy
        super.onDestroy()
    }
}