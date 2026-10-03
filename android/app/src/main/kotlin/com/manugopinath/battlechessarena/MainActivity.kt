package com.manugopinath.battlechessarena

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
import android.content.ComponentName
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
