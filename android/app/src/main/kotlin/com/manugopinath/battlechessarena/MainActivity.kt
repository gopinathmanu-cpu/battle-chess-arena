package com.manugopinath.battlechessarena

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
import android.content.ComponentName
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.media.AudioAttributes
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private var commentaryEngine: TextToSpeech? = null
    private var commentaryReady = false
    private var pendingCommentary: String? = null
    private var commentaryGeneration = 0
    private var commentaryUtterance = 0
    private val narrationHandler = Handler(Looper.getMainLooper())
    private var narrationEngine: TextToSpeech? = null
    private var narrationReady = false
    private var narrationGeneration = 0
    private var narrationSequence = 0
    private var narrationResult: MethodChannel.Result? = null
    private var narrationText: String? = null
    private var narrationRate = 1.0f
    private var narrationId: String? = null
    private var narrationOwner: String? = null
    private var narrationWatchdog: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationReceiver.ensureChannel(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "battle_chess_arena/beta_info")
            .setMethodCallHandler { call, result ->
                if (call.method != "getAppInfo") {
                    result.notImplemented()
                } else {
                    try {
                        @Suppress("DEPRECATION")
                        val info = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        val versionCode = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                        result.success(mapOf(
                            "version" to (info.versionName ?: "Unavailable"),
                            "build" to versionCode.toString(),
                            "platform" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
                            "device" to "${Build.MANUFACTURER} ${Build.MODEL}",
                            "architecture" to Build.SUPPORTED_ABIS.joinToString(", ")
                        ))
                    } catch (_: Exception) {
                        result.error("metadata_unavailable", "App metadata unavailable", null)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "battle_chess_arena/mobile_notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> requestNotificationPermission(result)
                    "playAlert" -> {
                        val sound = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION)
                        android.media.RingtoneManager.getRingtone(this, sound)?.play()
                        result.success(null)
                    }
                    "show" -> {
                        NotificationReceiver.show(
                            this,
                            call.argument<String>("id") ?: "online",
                            call.argument<String>("title") ?: "Battle Chess Arena",
                            call.argument<String>("body") ?: "Online game update",
                        )
                        result.success(null)
                    }
                    "schedule" -> {
                        NotificationReceiver.schedule(
                            this,
                            call.argument<String>("id") ?: "online",
                            call.argument<String>("title") ?: "Battle Chess Arena",
                            call.argument<String>("body") ?: "Online game update",
                            call.argument<Number>("at")?.toLong() ?: System.currentTimeMillis(),
                        )
                        result.success(null)
                    }
                    "cancel" -> {
                        val id = call.argument<String>("id") ?: "online"
                        NotificationReceiver.cancel(this, id)
                        result.success(null)
                    }
                    "cancelAll" -> {
                        NotificationReceiver.cancelAll(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "battle_chess_arena/app_icon")
            .setMethodCallHandler { call, result ->
                if (call.method != "setAppIcon") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val selected = call.argument<String>("icon")
                val selectedAlias = when (selected) {
                    "classic_gold" -> "LauncherClassicGold"
                    "light_purple" -> "LauncherLightPurple"
                    else -> {
                        result.error("unknown_icon", "That app icon is not available.", null)
                        return@setMethodCallHandler
                    }
                }
                try {
                    val componentPackage = MainActivity::class.java.packageName
                    packageManager.setComponentEnabledSetting(
                        ComponentName(packageName, "$componentPackage.$selectedAlias"),
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP,
                    )
                    listOf("LauncherClassicGold", "LauncherLightPurple")
                        .filter { it != selectedAlias }
                        .forEach { alias ->
                        packageManager.setComponentEnabledSetting(
                            ComponentName(packageName, "$componentPackage.$alias"),
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP,
                        )
                    }
                    result.success(null)
                } catch (error: Exception) {
                    result.error("icon_change_failed", error.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "battle_chess_arena/move_commentary")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "speak" -> {
                            val text = call.argument<String>("text")?.trim().orEmpty()
                            if (text.isNotEmpty()) speakCommentary(text)
                            result.success(null)
                        }
                        "stop" -> {
                            stopCommentary()
                            result.success(null)
                        }
                        "dispose" -> {
                            disposeCommentary()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("commentary_unavailable", "Move commentary is unavailable", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "battle_chess_arena/cinematic_narration")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "narrate" -> {
                            val text = call.argument<String>("text")?.trim().orEmpty()
                            val rate = call.argument<Number>("rate")?.toFloat() ?: 1.0f
                            val owner = call.argument<String>("owner").orEmpty()
                            if (owner.isBlank()) result.success(null) else narrateFilm(text, rate, owner, result)
                        }
                        "stop" -> {
                            val owner = call.argument<String>("owner")
                            if (owner != null && owner == narrationOwner) stopFilmNarration()
                            result.success(null)
                        }
                        "dispose" -> {
                            val owner = call.argument<String>("owner")
                            if (owner != null && owner == narrationOwner) disposeFilmNarration()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    // All pending scene waits are released, even if a voice
                    // service disconnects during a stop or speak operation.
                    val narrationCall = call.method == "narrate"
                    val held = narrationResult === result
                    completeFilmNarration()
                    if (!narrationCall || !held) result.success(null)
                    disposeFilmNarration()
                }
            }
    }

    private fun narrateFilm(text: String, rate: Float, owner: String, result: MethodChannel.Result) {
        stopFilmNarration()
        narrationOwner = owner
        try {
            // The game's final automatic move may still be speaking when its
            // result dialog launches a film. Hand audio over to the storyteller.
            stopCommentary()
        } catch (_: Exception) {
            // An already-disconnected move voice cannot block film narration.
        }
        if (text.isEmpty()) {
            result.success(null)
            return
        }
        narrationResult = result
        narrationText = text.take(TextToSpeech.getMaxSpeechInputLength())
        narrationRate = if (rate.isFinite()) rate.coerceIn(0.65f, 1.8f) else 1.0f
        narrationId = "film-${narrationGeneration}-${++narrationSequence}"
        if (narrationReady) {
            speakFilmNarration()
            return
        }
        // A broken installed engine must never hold a chapter indefinitely.
        armNarrationWatchdog(12000L)
        if (narrationEngine != null) return
        val generation = narrationGeneration
        narrationEngine = TextToSpeech(applicationContext) { status ->
            narrationHandler.post {
                if (generation != narrationGeneration) return@post
                val engine = narrationEngine ?: return@post
                try {
                    if (status != TextToSpeech.SUCCESS) {
                        disposeFilmNarration()
                        return@post
                    }
                    var language = engine.setLanguage(Locale.US)
                    if (language < TextToSpeech.LANG_AVAILABLE) {
                        language = engine.setLanguage(Locale.ENGLISH)
                    }
                    if (language < TextToSpeech.LANG_AVAILABLE) {
                        disposeFilmNarration()
                        return@post
                    }
                    engine.setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build(),
                    )
                    engine.setPitch(0.94f)
                    engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) = Unit
                        override fun onDone(utteranceId: String?) = finishFilmUtterance(generation, utteranceId)
                        @Deprecated("Required for engines using the legacy error callback")
                        override fun onError(utteranceId: String?) = finishFilmUtterance(generation, utteranceId)
                        override fun onError(utteranceId: String?, errorCode: Int) = finishFilmUtterance(generation, utteranceId)
                        override fun onStop(utteranceId: String?, interrupted: Boolean) = finishFilmUtterance(generation, utteranceId)
                    })
                    narrationReady = true
                    if (narrationResult != null) speakFilmNarration()
                } catch (_: Exception) {
                    disposeFilmNarration()
                }
            }
        }
    }

    private fun finishFilmUtterance(generation: Int, utteranceId: String?) {
        // Android engines may invoke callbacks on several binder threads.
        narrationHandler.post {
            if (generation == narrationGeneration && utteranceId != null && utteranceId == narrationId) {
                completeFilmNarration()
            }
        }
    }

    private fun speakFilmNarration() {
        val engine = narrationEngine ?: run {
            completeFilmNarration()
            return
        }
        val text = narrationText ?: return
        val id = narrationId ?: return
        engine.setSpeechRate(0.88f * narrationRate)
        // Give normal speech ample time while protecting against engines that
        // never emit an utterance completion callback after losing their service.
        armNarrationWatchdog((15000L + (text.length * 125L / narrationRate).toLong()).coerceAtMost(180000L))
        if (engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, id) == TextToSpeech.ERROR) {
            completeFilmNarration()
        }
    }

    private fun armNarrationWatchdog(delay: Long) {
        narrationWatchdog?.let { narrationHandler.removeCallbacks(it) }
        val id = narrationId
        val watchdog = Runnable {
            if (narrationId == id) {
                // Complete first; callbacks from stop cannot affect a new line.
                completeFilmNarration()
                try {
                    narrationEngine?.stop()
                } catch (_: Exception) {
                    disposeFilmNarration()
                }
            }
        }
        narrationWatchdog = watchdog
        narrationHandler.postDelayed(watchdog, delay)
    }

    private fun completeFilmNarration() {
        narrationWatchdog?.let { narrationHandler.removeCallbacks(it) }
        narrationWatchdog = null
        val result = narrationResult
        narrationResult = null
        narrationText = null
        narrationId = null
        result?.success(null)
    }

    private fun stopFilmNarration() {
        completeFilmNarration()
        narrationEngine?.stop()
    }

    private fun disposeFilmNarration() {
        narrationGeneration++
        narrationOwner = null
        completeFilmNarration()
        narrationReady = false
        val engine = narrationEngine
        narrationEngine = null
        try {
            engine?.stop()
        } catch (_: Exception) {
            // Continue to shutdown even if the engine has disconnected.
        } finally {
            try {
                engine?.shutdown()
            } catch (_: Exception) {
                // Optional speech must not prevent route or activity cleanup.
            }
        }
    }

    private fun speakCommentary(text: String) {
        if (commentaryReady) {
            commentaryEngine?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "move-${++commentaryUtterance}")
            return
        }
        // Keep only the latest move while the installed speech engine starts.
        pendingCommentary = text
        if (commentaryEngine != null) return
        val generation = commentaryGeneration
        commentaryEngine = TextToSpeech(applicationContext) { status ->
            // Posting also handles engines that report an immediate bind error
            // before the constructor has assigned commentaryEngine.
            Handler(Looper.getMainLooper()).post {
                if (generation != commentaryGeneration) return@post
                val engine = commentaryEngine ?: return@post
                try {
                    if (status != TextToSpeech.SUCCESS) {
                        disposeCommentary()
                        return@post
                    }
                    var language = engine.setLanguage(Locale.US)
                    if (language < TextToSpeech.LANG_AVAILABLE) {
                        language = engine.setLanguage(Locale.ENGLISH)
                    }
                    if (language < TextToSpeech.LANG_AVAILABLE) {
                        // Captions remain available when English voice data is missing.
                        disposeCommentary()
                        return@post
                    }
                    commentaryReady = true
                    val pending = pendingCommentary
                    pendingCommentary = null
                    if (pending != null) speakCommentary(pending)
                } catch (_: Exception) {
                    disposeCommentary()
                }
            }
        }
    }

    private fun stopCommentary() {
        pendingCommentary = null
        commentaryEngine?.stop()
    }

    private fun disposeCommentary() {
        commentaryGeneration++
        pendingCommentary = null
        commentaryReady = false
        val engine = commentaryEngine
        commentaryEngine = null
        try {
            engine?.stop()
        } finally {
            engine?.shutdown()
        }
    }

    override fun onDestroy() {
        disposeFilmNarration()
        disposeCommentary()
        super.onDestroy()
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.success(false)
            return
        }
        permissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequest,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationPermissionRequest) {
            permissionResult?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED,
            )
            permissionResult = null
        }
    }

    companion object {
        private const val notificationPermissionRequest = 9042
    }
}
