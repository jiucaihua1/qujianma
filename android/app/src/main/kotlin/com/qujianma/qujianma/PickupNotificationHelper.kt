package com.qujianma.qujianma

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

object PickupNotificationHelper {
    private const val CHANNEL_ID = "pickup_quick_scan"
    private const val CHANNEL_NAME = "快捷截屏识码结果"
    private const val NOTIFICATION_ID = 20261
    private const val REMINDER_CHANNEL_ID = "pickup_daily_reminder"
    private const val REMINDER_CHANNEL_NAME = "每日未取包裹提醒"
    private const val REMINDER_NOTIFICATION_ID = 20262

    fun areNotificationsEnabled(context: Context): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            if (!granted) return false
        }
        return true
    }

    fun showScanResult(
        context: Context,
        title: String,
        body: String,
        launchAction: String? = MainActivity.ACTION_OPEN_PICKUP_TAB,
    ) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "控制中心一键识码后的结果通知"
                enableVibration(true)
            }
            manager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (!launchAction.isNullOrBlank()) {
                putExtra(MainActivity.EXTRA_LAUNCH_ACTION, launchAction)
            }
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_qs_pickup)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted yet; ignore gracefully.
        }
    }

    fun showDailyReminder(
        context: Context,
        title: String,
        body: String,
    ) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                REMINDER_CHANNEL_ID,
                REMINDER_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "每日定时提醒尚未取走的快递包裹"
                enableVibration(true)
            }
            manager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_LAUNCH_ACTION, MainActivity.ACTION_OPEN_PICKUP_TAB)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            1,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, REMINDER_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_qs_pickup)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            manager.notify(REMINDER_NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
        }
    }
}
