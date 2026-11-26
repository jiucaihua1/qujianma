package com.qujianma.qujianma

import android.app.Activity
import android.os.Build
import android.os.Bundle

/**
 * Transparent zero-animation activity started via TileService.startActivityAndCollapse()
 * solely to reliably collapse the Quick Settings panel on Android 12–17 before scanning.
 */
class TileCollapseActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            overrideActivityTransition(OVERRIDE_TRANSITION_OPEN, 0, 0)
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }

        val appContext = applicationContext
        finish()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }

        QuickScanAccessibilityService.triggerCaptureAfterDelay(appContext, delayMs = 600L)
    }
}
