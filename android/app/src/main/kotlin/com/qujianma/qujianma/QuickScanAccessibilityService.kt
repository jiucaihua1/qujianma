package com.qujianma.qujianma

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.quicksettings.TileService
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import java.lang.ref.WeakReference
import java.util.ArrayDeque
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class QuickScanAccessibilityService : AccessibilityService() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val workerExecutor = Executors.newSingleThreadExecutor()
    private val isCapturing = AtomicBoolean(false)

    // Guided scan session state (strictly active only when user explicitly starts a session)
    @Volatile
    private var sessionActive = false
    private var sessionTargetName = ""
    private var sessionSavedCount = 0
    private var lastSessionScanMs = 0L
    private val sessionSavedCodes: MutableSet<String> = ConcurrentHashMap.newKeySet()
    private var sessionOverlay: QuickScanSessionOverlay? = null
    private val sessionTimeoutRunnable = Runnable { stopGuidedSession() }

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceRef = WeakReference(this)
        requestTileRefresh()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!sessionActive || isCapturing.get()) return
        val pkg = event?.packageName?.toString()
        if (pkg == null || pkg == packageName) return

        val now = System.currentTimeMillis()
        if (now - lastSessionScanMs < 850L) return
        lastSessionScanMs = now

        val nodeText = try {
            extractVisibleNodeText()
        } catch (_: Throwable) {
            ""
        }
        if (nodeText.isBlank()) return

        val fresh = PickupParserNative.parseAll(nodeText, defaultSource = "ocr", context = this)
            .filter { !sessionSavedCodes.contains(it.code.uppercase()) }
        if (fresh.isNotEmpty()) {
            resetSessionTimeout()
            mainHandler.post {
                if (sessionActive) {
                    sessionOverlay?.showDetectedCandidates(fresh, "控件自动识别")
                }
            }
        }
    }

    override fun onInterrupt() {
        // No-op
    }

    override fun onUnbind(intent: Intent?): Boolean {
        stopGuidedSession()
        if (serviceRef?.get() === this) {
            serviceRef = null
        }
        requestTileRefresh()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        stopGuidedSession()
        if (serviceRef?.get() === this) {
            serviceRef = null
        }
        requestTileRefresh()
        workerExecutor.shutdownNow()
        super.onDestroy()
    }

    fun startGuidedSession(targetName: String) {
        mainHandler.post {
            sessionActive = true
            sessionTargetName = targetName
            sessionSavedCount = 0
            lastSessionScanMs = 0L
            sessionSavedCodes.clear()

            if (sessionOverlay == null) {
                sessionOverlay = QuickScanSessionOverlay(
                    context = this,
                    onManualOcr = { triggerSessionManualOcr() },
                    onConfirmAndReturn = { list -> confirmSessionCandidates(list, returnToApp = true) },
                    onConfirmAndContinue = { list -> confirmSessionCandidates(list, returnToApp = false) },
                    onClose = { stopGuidedSession() },
                )
            }
            sessionOverlay?.show(targetName)
            resetSessionTimeout()
        }
    }

    fun stopGuidedSession() {
        sessionActive = false
        mainHandler.removeCallbacks(sessionTimeoutRunnable)
        mainHandler.post {
            sessionOverlay?.dismiss()
            sessionOverlay = null
        }
    }

    private fun resetSessionTimeout() {
        mainHandler.removeCallbacks(sessionTimeoutRunnable)
        mainHandler.postDelayed(sessionTimeoutRunnable, 75_000L)
    }

    private fun confirmSessionCandidates(
        candidates: List<NativeParsedPickup>,
        returnToApp: Boolean,
    ) {
        resetSessionTimeout()
        workerExecutor.execute {
            val dbHelper = PickupDatabaseHelper(applicationContext)
            val result = try {
                dbHelper.insertUnique(candidates)
            } finally {
                dbHelper.close()
            }

            for (c in candidates) {
                sessionSavedCodes.add(c.code.uppercase())
            }
            sessionSavedCount += result.inserted.size.coerceAtLeast(if (candidates.isNotEmpty()) 1 else 0)
            MainActivity.notifyDatabaseChanged()

            mainHandler.post {
                if (returnToApp) {
                    val msg = if (result.inserted.isEmpty()) {
                        "取件码已在待取列表中"
                    } else {
                        "已入库 ${result.inserted.size} 条取件码"
                    }
                    Toast.makeText(applicationContext, msg, Toast.LENGTH_SHORT).show()
                    stopGuidedSession()
                    val backIntent = Intent(applicationContext, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra(MainActivity.EXTRA_LAUNCH_ACTION, MainActivity.ACTION_OPEN_PICKUP_TAB)
                    }
                    try {
                        startActivity(backIntent)
                    } catch (_: Throwable) {
                        val preview = candidates.joinToString("、") { "${it.code}（${it.stationName}）" }
                        PickupNotificationHelper.showScanResult(
                            context = this,
                            title = "$msg（点击返回取件码）",
                            body = preview,
                            launchAction = MainActivity.ACTION_OPEN_PICKUP_TAB,
                        )
                    }
                } else {
                    val msg = if (result.inserted.isEmpty()) {
                        "已在列表中，继续滑动收下一个"
                    } else {
                        "已入库 ${result.inserted.size} 条，继续滑动收下一个"
                    }
                    Toast.makeText(applicationContext, msg, Toast.LENGTH_SHORT).show()
                    sessionOverlay?.showScanningState(sessionTargetName, sessionSavedCount)
                }
            }
        }
    }

    private fun triggerSessionManualOcr() {
        if (!sessionActive) return
        resetSessionTimeout()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            sessionOverlay?.showTransientMessage("系统版本不支持截屏 OCR", "需要 Android 11 及以上版本")
            return
        }
        if (!isCapturing.compareAndSet(false, true)) return

        sessionOverlay?.showOcrRunning()
        sessionOverlay?.setTemporarilyHidden(true)

        mainHandler.postDelayed({
            try {
                takeScreenshot(
                    Display.DEFAULT_DISPLAY,
                    mainExecutor,
                    object : TakeScreenshotCallback {
                        override fun onSuccess(screenshot: ScreenshotResult) {
                            sessionOverlay?.setTemporarilyHidden(false)
                            val softwareBitmap = try {
                                val buffer = screenshot.hardwareBuffer
                                val colorSpace = screenshot.colorSpace
                                try {
                                    val hwBitmap = Bitmap.wrapHardwareBuffer(buffer, colorSpace)
                                    try {
                                        hwBitmap?.copy(Bitmap.Config.ARGB_8888, false)
                                    } finally {
                                        hwBitmap?.recycle()
                                    }
                                } finally {
                                    buffer.close()
                                }
                            } catch (_: Throwable) {
                                null
                            }

                            if (softwareBitmap == null) {
                                isCapturing.set(false)
                                sessionOverlay?.showTransientMessage("截屏失败", "请重试或滑动页面")
                                return
                            }

                            val recognizer = try {
                                TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
                            } catch (t: Throwable) {
                                softwareBitmap.recycle()
                                isCapturing.set(false)
                                sessionOverlay?.showTransientMessage(
                                    "OCR 初始化失败",
                                    "${t.javaClass.simpleName}: ${t.message ?: "中文识别组件不可用"}"
                                )
                                return
                            }

                            val inputImage = InputImage.fromBitmap(softwareBitmap, 0)
                            recognizer.process(inputImage)
                                .addOnSuccessListener(workerExecutor) { visionText ->
                                    val ocrList = PickupParserNative.parseAll(
                                        visionText.text.trim(),
                                        defaultSource = "ocr",
                                        context = this@QuickScanAccessibilityService,
                                    ).filter { !sessionSavedCodes.contains(it.code.uppercase()) }

                                    mainHandler.post {
                                        if (!sessionActive) return@post
                                        if (ocrList.isEmpty()) {
                                            sessionOverlay?.showTransientMessage(
                                                "本次 OCR 未发现新取件码",
                                                "请确保取件码在屏幕内清晰可见，可再次点击「OCR截屏」"
                                            )
                                        } else {
                                            sessionOverlay?.showDetectedCandidates(ocrList, "OCR识别")
                                        }
                                    }
                                }
                                .addOnFailureListener {
                                    mainHandler.post {
                                        if (sessionActive) {
                                            sessionOverlay?.showTransientMessage("OCR 识别失败", "请稍后重试")
                                        }
                                    }
                                }
                                .addOnCompleteListener {
                                    if (!softwareBitmap.isRecycled) softwareBitmap.recycle()
                                    recognizer.close()
                                    isCapturing.set(false)
                                }
                        }

                        override fun onFailure(errorCode: Int) {
                            sessionOverlay?.setTemporarilyHidden(false)
                            isCapturing.set(false)
                            sessionOverlay?.showTransientMessage(
                                "未能截屏（错误码 $errorCode）",
                                "当前页面可能限制截屏，可继续滑动触发控件识别"
                            )
                        }
                    }
                )
            } catch (_: Throwable) {
                sessionOverlay?.setTemporarilyHidden(false)
                isCapturing.set(false)
            }
        }, 160L)
    }

    private fun requestTileRefresh() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                TileService.requestListeningState(
                    applicationContext,
                    ComponentName(applicationContext, QuickScanTileService::class.java)
                )
            } catch (_: Throwable) {
            }
        }
    }

    /**
     * Dual-engine capture:
     * 1. Fast & exact: inspect active window's AccessibilityNodeInfo text tree.
     * 2. Fallback: in-memory takeScreenshot() + offline ML Kit Chinese OCR (never writes to gallery).
     */
    fun captureAndRecognize() {
        if (!isCapturing.compareAndSet(false, true)) {
            return
        }

        // Engine 1: Try Accessibility Node Tree first (zero OCR errors, ~10ms)
        val nodeText = try {
            extractVisibleNodeText()
        } catch (_: Throwable) {
            ""
        }
        val nodeCandidates = if (nodeText.isNotBlank()) {
            PickupParserNative.parseAll(nodeText, defaultSource = "ocr", context = this)
        } else {
            emptyList()
        }

        val hasSolidNodeResult = nodeCandidates.isNotEmpty() &&
            nodeCandidates.any { it.stationName != "默认驿站" }

        if (hasSolidNodeResult) {
            workerExecutor.execute {
                try {
                    saveCandidatesAndNotify(nodeCandidates, engineLabel = "控件识别")
                } finally {
                    isCapturing.set(false)
                }
            }
            return
        }

        // Engine 2: In-memory screenshot + ML Kit Chinese OCR fallback
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            if (nodeCandidates.isNotEmpty()) {
                workerExecutor.execute {
                    try {
                        saveCandidatesAndNotify(nodeCandidates, engineLabel = "控件识别")
                    } finally {
                        isCapturing.set(false)
                    }
                }
            } else {
                isCapturing.set(false)
                PickupNotificationHelper.showScanResult(
                    context = this,
                    title = "未识别到取件码",
                    body = "当前页面未读取到取件码（自动截屏保底需 Android 11+）。",
                    launchAction = null,
                )
            }
            return
        }

        try {
            takeScreenshot(
                Display.DEFAULT_DISPLAY,
                mainExecutor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshot: ScreenshotResult) {
                        val softwareBitmap = try {
                            val buffer = screenshot.hardwareBuffer
                            val colorSpace = screenshot.colorSpace
                            try {
                                val hwBitmap = Bitmap.wrapHardwareBuffer(buffer, colorSpace)
                                try {
                                    hwBitmap?.copy(Bitmap.Config.ARGB_8888, false)
                                } finally {
                                    hwBitmap?.recycle()
                                }
                            } finally {
                                buffer.close()
                            }
                        } catch (_: Throwable) {
                            null
                        }

                        if (softwareBitmap == null) {
                            if (nodeCandidates.isNotEmpty()) {
                                workerExecutor.execute {
                                    try {
                                        saveCandidatesAndNotify(nodeCandidates, engineLabel = "控件识别")
                                    } finally {
                                        isCapturing.set(false)
                                    }
                                }
                            } else {
                                isCapturing.set(false)
                                PickupNotificationHelper.showScanResult(
                                    context = this@QuickScanAccessibilityService,
                                    title = "截屏失败",
                                    body = "未能获取当前画面，请稍后重试。",
                                    launchAction = null,
                                )
                            }
                            return
                        }

                        runOfflineOcr(softwareBitmap, fallbackNodeCandidates = nodeCandidates)
                    }

                    override fun onFailure(errorCode: Int) {
                        if (nodeCandidates.isNotEmpty()) {
                            workerExecutor.execute {
                                try {
                                    saveCandidatesAndNotify(nodeCandidates, engineLabel = "控件识别")
                                } finally {
                                    isCapturing.set(false)
                                }
                            }
                            return
                        }
                        isCapturing.set(false)
                        val reason = when (errorCode) {
                            ERROR_TAKE_SCREENSHOT_INTERVAL_TIME_SHORT -> "操作太频繁，请隔 1 秒再试。"
                            ERROR_TAKE_SCREENSHOT_NO_ACCESSIBILITY_ACCESS -> "无障碍权限未就绪，请重新开启。"
                            else -> "当前页面可能禁止截屏（如隐私/支付页面），错误码：$errorCode。"
                        }
                        PickupNotificationHelper.showScanResult(
                            context = this@QuickScanAccessibilityService,
                            title = "未能截取当前页面",
                            body = reason,
                            launchAction = null,
                        )
                    }
                }
            )
        } catch (t: Throwable) {
            if (nodeCandidates.isNotEmpty()) {
                workerExecutor.execute {
                    try {
                        saveCandidatesAndNotify(nodeCandidates, engineLabel = "控件识别")
                    } finally {
                        isCapturing.set(false)
                    }
                }
            } else {
                isCapturing.set(false)
                PickupNotificationHelper.showScanResult(
                    context = this,
                    title = "截屏启动失败",
                    body = t.message ?: "请检查无障碍服务是否正常开启。",
                    launchAction = MainActivity.ACTION_OPEN_TILE_SETUP,
                )
            }
        }
    }

    private fun extractVisibleNodeText(): String {
        val root = rootInActiveWindow ?: return ""
        val lines = LinkedHashSet<String>()
        // Use Pre-order DFS (not BFS!) so each station header stays immediately above
        // its own child pickup code cards and item titles in true visual top-to-bottom order.
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addFirst(root)
        var visited = 0
        val maxNodes = 450

        while (stack.isNotEmpty() && visited < maxNodes) {
            val node = stack.removeFirst()
            visited++

            val text = node.text?.toString()?.trim()
            if (!text.isNullOrEmpty() && text.length <= 240) {
                lines.add(text)
            }
            val desc = node.contentDescription?.toString()?.trim()
            if (!desc.isNullOrEmpty() && desc.length <= 240 && desc != text) {
                lines.add(desc)
            }

            val childCount = node.childCount
            for (i in (childCount - 1) downTo 0) {
                val child = node.getChild(i)
                if (child != null) {
                    stack.addFirst(child)
                }
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                @Suppress("DEPRECATION")
                node.recycle()
            }
        }
        return lines.joinToString("\n")
    }

    private fun runOfflineOcr(
        bitmap: Bitmap,
        fallbackNodeCandidates: List<NativeParsedPickup>,
    ) {
        val recognizer = try {
            TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
        } catch (t: Throwable) {
            bitmap.recycle()
            if (fallbackNodeCandidates.isNotEmpty()) {
                workerExecutor.execute {
                    try {
                        saveCandidatesAndNotify(fallbackNodeCandidates, engineLabel = "控件识别")
                    } finally {
                        isCapturing.set(false)
                    }
                }
            } else {
                isCapturing.set(false)
                PickupNotificationHelper.showScanResult(
                    context = this,
                    title = "本地 OCR 初始化失败",
                    body = t.message ?: "中文识别组件不可用。",
                    launchAction = null,
                )
            }
            return
        }

        val inputImage = InputImage.fromBitmap(bitmap, 0)
        recognizer.process(inputImage)
            .addOnSuccessListener(workerExecutor) { visionText ->
                try {
                    val rawText = visionText.text.trim()
                    val ocrCandidates = PickupParserNative.parseAll(rawText, defaultSource = "ocr", context = this)
                    val finalCandidates = mergeCandidates(fallbackNodeCandidates, ocrCandidates)

                    if (finalCandidates.isEmpty()) {
                        PickupNotificationHelper.showScanResult(
                            context = this,
                            title = "未识别到取件码",
                            body = "当前画面未检测到有效取件码，请确认取件码清晰可见后再试。",
                            launchAction = null,
                        )
                        showToast("未识别到取件码")
                        return@addOnSuccessListener
                    }

                    saveCandidatesAndNotify(finalCandidates, engineLabel = "OCR识别")
                } catch (t: Throwable) {
                    PickupNotificationHelper.showScanResult(
                        context = this,
                        title = "保存取件码失败",
                        body = t.message ?: "写入本地数据库时发生错误。",
                        launchAction = null,
                    )
                }
            }
            .addOnFailureListener { e ->
                if (fallbackNodeCandidates.isNotEmpty()) {
                    workerExecutor.execute {
                        saveCandidatesAndNotify(fallbackNodeCandidates, engineLabel = "控件识别")
                    }
                } else {
                    PickupNotificationHelper.showScanResult(
                        context = this,
                        title = "本地 OCR 识别失败",
                        body = e.message ?: "请稍后重试。",
                        launchAction = null,
                    )
                }
            }
            .addOnCompleteListener {
                // Immediately release the in-memory screenshot; zero files remain on disk.
                if (!bitmap.isRecycled) {
                    bitmap.recycle()
                }
                recognizer.close()
                isCapturing.set(false)
            }
    }

    private fun mergeCandidates(
        nodeList: List<NativeParsedPickup>,
        ocrList: List<NativeParsedPickup>,
    ): List<NativeParsedPickup> {
        if (nodeList.isEmpty()) return ocrList
        if (ocrList.isEmpty()) return nodeList

        val merged = LinkedHashMap<String, NativeParsedPickup>()
        for (item in ocrList) {
            merged[item.code.uppercase()] = item
        }
        for (item in nodeList) {
            val key = item.code.uppercase()
            val existing = merged[key]
            if (existing == null) {
                merged[key] = item
            } else {
                // Prefer non-default station name & tracking number across both engines
                val betterStation = if (existing.stationName != "默认驿站") {
                    existing.stationName
                } else {
                    item.stationName
                }
                val betterTracking = existing.trackingNumber.ifBlank { item.trackingNumber }
                val betterNote = existing.itemNote.ifBlank { item.itemNote }
                merged[key] = item.copy(
                    stationName = betterStation,
                    trackingNumber = betterTracking,
                    itemNote = betterNote,
                )
            }
        }
        return merged.values.toList()
    }

    private fun saveCandidatesAndNotify(
        candidates: List<NativeParsedPickup>,
        engineLabel: String,
    ) {
        val dbHelper = PickupDatabaseHelper(applicationContext)
        val result = try {
            dbHelper.insertUnique(candidates)
        } finally {
            dbHelper.close()
        }

        if (result.inserted.isEmpty()) {
            val codes = candidates.joinToString("、") { it.code }
            PickupNotificationHelper.showScanResult(
                context = this,
                title = "取件码已在待取列表",
                body = "$codes 已存在，未重复添加。",
                launchAction = MainActivity.ACTION_OPEN_PICKUP_TAB,
            )
            showToast("取件码已在待取列表中")
        } else {
            val preview = result.inserted.joinToString("、") {
                "${it.code}（${it.stationName}）"
            }
            val title = if (result.inserted.size == 1) {
                "已入库 1 个取件码（$engineLabel）"
            } else {
                "已入库 ${result.inserted.size} 个取件码（$engineLabel）"
            }
            PickupNotificationHelper.showScanResult(
                context = this,
                title = title,
                body = preview,
                launchAction = MainActivity.ACTION_OPEN_PICKUP_TAB,
            )
            showToast(title)
            MainActivity.notifyDatabaseChanged()
        }
    }

    private fun showToast(message: String) {
        mainHandler.post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()
        }
    }

    companion object {
        @Volatile
        private var serviceRef: WeakReference<QuickScanAccessibilityService>? = null

        fun isRunning(): Boolean = serviceRef?.get() != null

        fun startGuidedSessionIfRunning(targetName: String): Boolean {
            val service = serviceRef?.get() ?: return false
            service.startGuidedSession(targetName)
            return true
        }

        fun stopGuidedSessionIfRunning() {
            serviceRef?.get()?.stopGuidedSession()
        }

        fun isEnabledInSettings(context: Context): Boolean {
            if (isRunning()) return true
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            val expected = "${context.packageName}/${QuickScanAccessibilityService::class.java.name}"
            val shortExpected = "${context.packageName}/.QuickScanAccessibilityService"
            return enabledServices.split(':').any {
                it.equals(expected, ignoreCase = true) || it.equals(shortExpected, ignoreCase = true)
            }
        }

        fun triggerCaptureAfterDelay(context: Context, delayMs: Long = 600L) {
            val handler = Handler(Looper.getMainLooper())
            handler.postDelayed({
                val service = serviceRef?.get()
                if (service != null) {
                    service.captureAndRecognize()
                    return@postDelayed
                }

                // If Shizuku is authorized, silently restore Accessibility and retry capture!
                if (ShizukuKeepAliveManager.isShizukuPermissionGranted()) {
                    ShizukuKeepAliveManager.restoreAccessibilityAsync(context) { restored ->
                        if (restored) {
                            handler.postDelayed({
                                val revived = serviceRef?.get()
                                if (revived != null) {
                                    revived.captureAndRecognize()
                                } else {
                                    PickupNotificationHelper.showScanResult(
                                        context = context,
                                        title = "已通过 Shizuku 恢复无障碍",
                                        body = "服务刚刚重启，请再点击一次控制中心「识取件码」磁贴。",
                                        launchAction = MainActivity.ACTION_OPEN_TILE_SETUP,
                                    )
                                }
                            }, 450L)
                        } else {
                            notifyAccessibilityNeeded(context)
                        }
                    }
                } else {
                    notifyAccessibilityNeeded(context)
                }
            }, delayMs)
        }

        private fun notifyAccessibilityNeeded(context: Context) {
            PickupNotificationHelper.showScanResult(
                context = context,
                title = "请先开启无障碍识码服务",
                body = "点击通知打开设置页，开启「取件码一键截屏识别」（或配置 Shizuku 自动保活）。",
                launchAction = MainActivity.ACTION_OPEN_TILE_SETUP,
            )
        }
    }
}
