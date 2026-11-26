package com.qujianma.qujianma

import android.Manifest
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import java.lang.ref.WeakReference

class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null
    private var pendingLaunchAction: String? = null
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var pendingShizukuResult: MethodChannel.Result? = null
    private var pendingSmsResult: MethodChannel.Result? = null

    private val shizukuPermissionListener =
        Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
            if (requestCode == REQ_SHIZUKU_PERMISSION) {
                val granted = grantResult == PackageManager.PERMISSION_GRANTED
                pendingShizukuResult?.success(granted)
                pendingShizukuResult = null
                if (granted && !QuickScanAccessibilityService.isRunning()) {
                    ShizukuKeepAliveManager.restoreAccessibilityAsync(applicationContext)
                }
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activeActivityRef = WeakReference(this)
        captureLaunchAction(intent)
        try {
            Shizuku.addRequestPermissionResultListener(shizukuPermissionListener)
        } catch (_: Throwable) {
        }
    }

    override fun onResume() {
        super.onResume()
        // Silently keep AccessibilityService alive via Shizuku whenever the user returns
        if (!QuickScanAccessibilityService.isRunning() &&
            ShizukuKeepAliveManager.isShizukuPermissionGranted()
        ) {
            ShizukuKeepAliveManager.restoreAccessibilityAsync(applicationContext)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureLaunchAction(intent)
        val action = pendingLaunchAction
        if (action != null) {
            pendingLaunchAction = null
            channel?.invokeMethod("onLaunchAction", action)
        } else if (intent.action == Intent.ACTION_MAIN &&
            intent.hasCategory(Intent.CATEGORY_LAUNCHER)
        ) {
            channel?.invokeMethod("onLaunchAction", ACTION_OPEN_DEFAULT_TAB)
        }
    }

    override fun onDestroy() {
        try {
            Shizuku.removeRequestPermissionResultListener(shizukuPermissionListener)
        } catch (_: Throwable) {
        }
        if (activeActivityRef?.get() === this) {
            activeActivityRef = null
        }
        super.onDestroy()
    }

    private fun captureLaunchAction(intent: Intent?) {
        val action = intent?.getStringExtra(EXTRA_LAUNCH_ACTION)
        if (!action.isNullOrBlank()) {
            pendingLaunchAction = action
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel = methodChannel

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    val version = try {
                        @Suppress("DEPRECATION")
                        packageManager.getPackageInfo(packageName, 0).versionName ?: "0.1.0"
                    } catch (_: Throwable) {
                        "0.1.0"
                    }
                    result.success(version)
                }

                "getQuickTileStatus" -> {
                    result.success(
                        mapOf(
                            "accessibilityEnabled" to QuickScanAccessibilityService.isEnabledInSettings(this),
                            "accessibilityRunning" to QuickScanAccessibilityService.isRunning(),
                            "notificationEnabled" to PickupNotificationHelper.areNotificationsEnabled(this),
                            "supportsRequestAddTile" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU),
                            "supportsTakeScreenshot" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R),
                            "shizukuRunning" to ShizukuKeepAliveManager.isShizukuRunning(),
                            "shizukuAuthorized" to ShizukuKeepAliveManager.isShizukuPermissionGranted(),
                        )
                    )
                }

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                            PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            result.success(true)
                        } else {
                            pendingNotificationResult?.success(false)
                            pendingNotificationResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                REQ_POST_NOTIFICATIONS
                            )
                        }
                    } else {
                        result.success(PickupNotificationHelper.areNotificationsEnabled(this))
                    }
                }

                "openNotificationSettings" -> {
                    val intent = Intent().apply {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                            data = Uri.parse("package:$packageName")
                        }
                    }
                    startActivity(intent)
                    result.success(true)
                }

                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }

                "openAppDetailsSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                    result.success(true)
                }

                "requestShizukuPermission" -> {
                    if (!ShizukuKeepAliveManager.isShizukuRunning()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    if (ShizukuKeepAliveManager.isShizukuPermissionGranted()) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    pendingShizukuResult?.success(false)
                    pendingShizukuResult = result
                    val sent = ShizukuKeepAliveManager.requestPermission(REQ_SHIZUKU_PERMISSION)
                    if (!sent) {
                        pendingShizukuResult = null
                        result.success(false)
                    }
                }

                "restoreAccessibilityWithShizuku" -> {
                    if (!ShizukuKeepAliveManager.isShizukuPermissionGranted()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    ShizukuKeepAliveManager.restoreAccessibilityAsync(applicationContext) { ok ->
                        result.success(ok)
                    }
                }

                "requestAddQuickTile" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val statusBarManager = getSystemService(StatusBarManager::class.java)
                        if (statusBarManager == null) {
                            result.success("unsupported")
                            return@setMethodCallHandler
                        }
                        statusBarManager.requestAddTileService(
                            ComponentName(this, QuickScanTileService::class.java),
                            getString(R.string.tile_label),
                            Icon.createWithResource(this, R.drawable.ic_qs_pickup),
                            mainExecutor
                        ) { status ->
                            val label = when (status) {
                                StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
                                StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "already_added"
                                StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED -> "not_added"
                                else -> "error_$status"
                            }
                            result.success(label)
                        }
                    } else {
                        result.success("unsupported")
                    }
                }

                "consumeLaunchAction" -> {
                    val action = pendingLaunchAction
                    pendingLaunchAction = null
                    result.success(action)
                }

                "startGuidedScanSession" -> {
                    val targetName = call.argument<String>("targetName") ?: "目标应用"
                    val primaryUrl = call.argument<String>("primaryUrl") ?: ""
                    val fallbackUrl = call.argument<String>("fallbackUrl") ?: ""
                    val fallbackPackage = call.argument<String>("fallbackPackage") ?: ""
                    handleStartGuidedScanSession(targetName, primaryUrl, fallbackUrl, fallbackPackage, result)
                }

                "launchExternalUrl" -> {
                    val primaryUrl = call.argument<String>("primaryUrl") ?: ""
                    val fallbackUrl = call.argument<String>("fallbackUrl") ?: ""
                    val fallbackPackage = call.argument<String>("fallbackPackage") ?: ""
                    val outcome = when {
                        tryLaunchTarget(primaryUrl) -> "primary"
                        fallbackUrl.isNotBlank() && tryLaunchTarget(fallbackUrl) -> "fallback"
                        fallbackPackage.isNotBlank() && tryLaunchPackage(fallbackPackage) -> "fallback"
                        else -> "failed"
                    }
                    result.success(outcome)
                }

                "checkSmsPermission" -> {
                    val granted = checkSelfPermission(Manifest.permission.READ_SMS) ==
                        PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }

                "requestSmsPermission" -> {
                    val granted = checkSelfPermission(Manifest.permission.READ_SMS) ==
                        PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        result.success(true)
                    } else {
                        pendingSmsResult?.success(false)
                        pendingSmsResult = result
                        requestPermissions(arrayOf(Manifest.permission.READ_SMS), REQ_READ_SMS)
                    }
                }

                "scanSmsInbox" -> {
                    val granted = checkSelfPermission(Manifest.permission.READ_SMS) ==
                        PackageManager.PERMISSION_GRANTED
                    if (!granted) {
                        result.error("NO_PERMISSION", "未授予读取短信权限", null)
                        return@setMethodCallHandler
                    }
                    val days = call.argument<Int>("days") ?: 7
                    Thread {
                        try {
                            val summary = SmsInboxScanner.scanRecentDays(applicationContext, days)
                            Handler(Looper.getMainLooper()).post {
                                result.success(
                                    mapOf(
                                        "scannedCount" to summary.scannedCount,
                                        "matchedCount" to summary.matchedCount,
                                        "insertedCount" to summary.insertedCount,
                                        "skippedCount" to summary.skippedCount,
                                        "insertedCodes" to summary.insertedCodes,
                                    )
                                )
                            }
                        } catch (t: Throwable) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("SCAN_ERROR", t.message ?: "读取短信失败", null)
                            }
                        }
                    }.start()
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_POST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationResult?.success(granted)
            pendingNotificationResult = null
        } else if (requestCode == REQ_READ_SMS) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingSmsResult?.success(granted)
            pendingSmsResult = null
        }
    }

    private fun handleStartGuidedScanSession(
        targetName: String,
        primaryUrl: String,
        fallbackUrl: String,
        fallbackPackage: String,
        result: MethodChannel.Result,
    ) {
        fun startAndLaunch() {
            if (!QuickScanAccessibilityService.startGuidedSessionIfRunning(targetName)) {
                result.success("need_accessibility")
                return
            }
            val launched = tryLaunchTarget(primaryUrl) ||
                (fallbackUrl.isNotBlank() && tryLaunchTarget(fallbackUrl)) ||
                (fallbackPackage.isNotBlank() && tryLaunchPackage(fallbackPackage))
            if (!launched) {
                QuickScanAccessibilityService.stopGuidedSessionIfRunning()
                result.success("launch_failed")
            } else {
                result.success("started")
            }
        }

        if (QuickScanAccessibilityService.isRunning()) {
            startAndLaunch()
            return
        }

        if (ShizukuKeepAliveManager.isShizukuPermissionGranted()) {
            ShizukuKeepAliveManager.restoreAccessibilityAsync(applicationContext) { restored ->
                if (restored) {
                    Handler(Looper.getMainLooper()).postDelayed({ startAndLaunch() }, 450L)
                } else {
                    result.success("need_accessibility")
                }
            }
        } else {
            result.success("need_accessibility")
        }
    }

    private fun tryLaunchTarget(url: String): Boolean {
        val trimmed = url.trim()
        if (trimmed.isEmpty()) return false
        return try {
            val intent = if (trimmed.equals("sms:", ignoreCase = true)) {
                Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_APP_MESSAGING)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
            } else {
                Intent(Intent.ACTION_VIEW, Uri.parse(trimmed)).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
            }
            startActivity(intent)
            true
        } catch (_: Throwable) {
            if (trimmed.equals("sms:", ignoreCase = true)) {
                try {
                    startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse("sms:")).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                    )
                    true
                } catch (_: Throwable) {
                    false
                }
            } else {
                false
            }
        }
    }

    private fun tryLaunchPackage(packageName: String): Boolean {
        val trimmed = packageName.trim()
        if (trimmed.isEmpty()) return false
        return try {
            val intent = packageManager.getLaunchIntentForPackage(trimmed) ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun notifyFlutterReload() {
        channel?.invokeMethod("onDatabaseChanged", null)
    }

    companion object {
        private const val CHANNEL_NAME = "com.qujianma.qujianma/quick_tile"
        private const val REQ_POST_NOTIFICATIONS = 3001
        private const val REQ_SHIZUKU_PERMISSION = 3002
        private const val REQ_READ_SMS = 3003
        const val EXTRA_LAUNCH_ACTION = "qujianma_launch_action"
        const val ACTION_OPEN_PICKUP_TAB = "open_pickup_tab"
        const val ACTION_OPEN_TILE_SETUP = "open_tile_setup"
        const val ACTION_OPEN_DEFAULT_TAB = "open_default_tab"

        @Volatile
        private var activeActivityRef: WeakReference<MainActivity>? = null

        fun notifyDatabaseChanged() {
            Handler(Looper.getMainLooper()).post {
                activeActivityRef?.get()?.notifyFlutterReload()
            }
        }
    }
}
