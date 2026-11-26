package com.qujianma.qujianma

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Lightweight floating capsule rendered via TYPE_ACCESSIBILITY_OVERLAY
 * (requires no extra SYSTEM_ALERT_WINDOW permission).
 * Shows real-time detected pickup codes while the user browses Taobao/PDD/Cainiao/SMS,
 * and lets them confirm & return to Qujianma with one tap.
 */
class QuickScanSessionOverlay(
    private val context: Context,
    private val onManualOcr: () -> Unit,
    private val onConfirmAndReturn: (List<NativeParsedPickup>) -> Unit,
    private val onConfirmAndContinue: (List<NativeParsedPickup>) -> Unit,
    private val onClose: () -> Unit,
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var rootView: LinearLayout? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    private lateinit var titleText: TextView
    private lateinit var detailText: TextView
    private lateinit var actionRow: LinearLayout
    private lateinit var ocrButton: TextView
    private lateinit var confirmReturnButton: TextView
    private lateinit var confirmContinueButton: TextView

    private var currentCandidates: List<NativeParsedPickup> = emptyList()

    fun show(targetName: String) {
        if (rootView != null) {
            showScanningState(targetName, savedCount = 0)
            return
        }

        val density = context.resources.displayMetrics.density
        fun dp(v: Int): Int = (v * density).toInt()

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(10), dp(14), dp(10))
            elevation = dp(8).toFloat()
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F5FFFFFF"))
                cornerRadius = dp(18).toFloat()
                setStroke(dp(1), Color.parseColor("#E5E7EB"))
            }
        }

        // Top header row (draggable handle + title + close button)
        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val badge = TextView(context).apply {
            text = "收码"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setTypeface(null, Typeface.BOLD)
            setPadding(dp(7), dp(2), dp(7), dp(2))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#2563EB"))
                cornerRadius = dp(8).toFloat()
            }
        }

        titleText = TextView(context).apply {
            text = "正在自动寻找 $targetName 取件码…"
            setTextColor(Color.parseColor("#111827"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f)
            setTypeface(null, Typeface.BOLD)
            setPadding(dp(8), 0, dp(8), 0)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val closeBtn = TextView(context).apply {
            text = "✕"
            setTextColor(Color.parseColor("#6B7280"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setPadding(dp(8), dp(2), dp(4), dp(2))
            setOnClickListener { onClose() }
        }

        header.addView(badge)
        header.addView(titleText)
        header.addView(closeBtn)

        detailText = TextView(context).apply {
            text = "滑到取件码页面会自动识别；若未触发可点「OCR截屏」"
            setTextColor(Color.parseColor("#4B5563"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding(0, dp(5), 0, dp(8))
        }

        actionRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }

        ocrButton = makePillButton(
            label = "OCR截屏",
            bgColor = "#EFF6FF",
            textColor = "#2563EB",
            dp = ::dp,
        ).apply {
            setOnClickListener { onManualOcr() }
        }

        confirmContinueButton = makePillButton(
            label = "入库继续",
            bgColor = "#ECFDF5",
            textColor = "#15803D",
            dp = ::dp,
        ).apply {
            visibility = View.GONE
            setOnClickListener {
                if (currentCandidates.isNotEmpty()) {
                    onConfirmAndContinue(currentCandidates)
                }
            }
        }

        confirmReturnButton = makePillButton(
            label = "入库并返回",
            bgColor = "#2563EB",
            textColor = "#FFFFFF",
            dp = ::dp,
        ).apply {
            visibility = View.GONE
            setOnClickListener {
                if (currentCandidates.isNotEmpty()) {
                    onConfirmAndReturn(currentCandidates)
                }
            }
        }

        actionRow.addView(ocrButton)
        actionRow.addView(confirmContinueButton)
        actionRow.addView(confirmReturnButton)

        card.addView(header)
        card.addView(detailText)
        card.addView(actionRow)

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val screenWidth = context.resources.displayMetrics.widthPixels
        val params = WindowManager.LayoutParams(
            (screenWidth - dp(28)).coerceAtLeast(dp(280)),
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(48)
        }

        // Allow dragging vertically so the capsule never blocks content
        var initialY = 0
        var initialTouchY = 0f
        header.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialY = params.y
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = (event.rawY - initialTouchY).toInt()
                    params.y = (initialY + dy).coerceIn(dp(24), context.resources.displayMetrics.heightPixels - dp(160))
                    try {
                        windowManager.updateViewLayout(card, params)
                    } catch (_: Throwable) {
                    }
                    true
                }
                else -> false
            }
        }

        try {
            windowManager.addView(card, params)
            rootView = card
            layoutParams = params
        } catch (_: Throwable) {
            rootView = null
            layoutParams = null
        }
    }

    private fun makePillButton(
        label: String,
        bgColor: String,
        textColor: String,
        dp: (Int) -> Int,
    ): TextView {
        return TextView(context).apply {
            text = label
            setTextColor(Color.parseColor(textColor))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            setTypeface(null, Typeface.BOLD)
            setPadding(dp(12), dp(6), dp(12), dp(6))
            background = GradientDrawable().apply {
                setColor(Color.parseColor(bgColor))
                cornerRadius = dp(10).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                marginStart = dp(8)
            }
        }
    }

    fun setTemporarilyHidden(hidden: Boolean) {
        rootView?.visibility = if (hidden) View.INVISIBLE else View.VISIBLE
    }

    fun showScanningState(targetName: String, savedCount: Int) {
        currentCandidates = emptyList()
        if (rootView == null) return
        titleText.text = if (savedCount > 0) {
            "已收 $savedCount 条 · 继续寻找下一条…"
        } else {
            "正在自动寻找 $targetName 取件码…"
        }
        detailText.text = "滑到取件码页面会自动识别；图片/小程序可点「OCR截屏」"
        confirmContinueButton.visibility = View.GONE
        confirmReturnButton.visibility = View.GONE
        ocrButton.text = "OCR截屏"
        ocrButton.isEnabled = true
    }

    fun showOcrRunning() {
        if (rootView == null) return
        titleText.text = "正在本地 OCR 识别当前页面…"
        ocrButton.isEnabled = false
    }

    fun showDetectedCandidates(candidates: List<NativeParsedPickup>, sourceHint: String) {
        currentCandidates = candidates
        if (rootView == null) return
        val preview = candidates.take(3).joinToString("、") {
            "${it.code}（${it.stationName}）"
        } + if (candidates.size > 3) " 等${candidates.size}条" else ""

        titleText.text = "识别到 ${candidates.size} 条取件码（$sourceHint）"
        detailText.text = preview
        ocrButton.text = "重扫OCR"
        ocrButton.isEnabled = true
        confirmContinueButton.visibility = View.VISIBLE
        confirmReturnButton.visibility = View.VISIBLE
    }

    fun showTransientMessage(title: String, detail: String) {
        if (rootView == null) return
        titleText.text = title
        detailText.text = detail
        ocrButton.isEnabled = true
    }

    fun dismiss() {
        val view = rootView ?: return
        rootView = null
        layoutParams = null
        currentCandidates = emptyList()
        try {
            windowManager.removeViewImmediate(view)
        } catch (_: Throwable) {
            try {
                windowManager.removeView(view)
            } catch (_: Throwable) {
            }
        }
    }
}
