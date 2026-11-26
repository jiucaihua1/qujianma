package com.qujianma.qujianma

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class QuickScanTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        if (!QuickScanAccessibilityService.isRunning() &&
            ShizukuKeepAliveManager.isShizukuPermissionGranted()
        ) {
            ShizukuKeepAliveManager.restoreAccessibilityAsync(applicationContext) {
                refreshTile()
            }
        }
        refreshTile()
    }

    override fun onClick() {
        super.onClick()
        val ready = QuickScanAccessibilityService.isRunning() ||
            ShizukuKeepAliveManager.isShizukuPermissionGranted()

        if (!ready) {
            val setupIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(MainActivity.EXTRA_LAUNCH_ACTION, MainActivity.ACTION_OPEN_TILE_SETUP)
            }
            launchAndCollapse(setupIntent, requestCode = 101)
            return
        }

        val collapseIntent = Intent(this, TileCollapseActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
        }
        launchAndCollapse(collapseIntent, requestCode = 102)
    }

    private fun launchAndCollapse(intent: Intent, requestCode: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = PendingIntent.getActivity(
                this,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private fun refreshTile() {
        val tile = qsTile ?: return
        val running = QuickScanAccessibilityService.isRunning()
        val shizukuReady = ShizukuKeepAliveManager.isShizukuPermissionGranted()
        tile.label = getString(R.string.tile_label)
        // Action-type tile: keep neutral (inactive/white) so it doesn't look like a permanently running toggle
        tile.state = Tile.STATE_INACTIVE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = when {
                running -> "点此识取件码"
                shizukuReady -> "Shizuku 保活就绪"
                else -> "点击去开启权限"
            }
        }
        tile.updateTile()
    }
}
