package com.qujianma.qujianma

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object DailyReminderScheduler {
    private const val REQUEST_CODE = 30301
    private const val EXTRA_HOUR = "extra_hour"
    private const val EXTRA_MINUTE = "extra_minute"

    fun scheduleNext(context: Context, enabled: Boolean, hour: Int, minute: Int) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val intent = Intent(context, DailyReminderReceiver::class.java).apply {
            putExtra(EXTRA_HOUR, hour)
            putExtra(EXTRA_MINUTE, minute)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (!enabled) {
            alarmManager.cancel(pendingIntent)
            return
        }

        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour.coerceIn(0, 23))
            set(Calendar.MINUTE, minute.coerceIn(0, 59))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis() + 5_000L) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                cal.timeInMillis,
                pendingIntent
            )
        } else {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                cal.timeInMillis,
                pendingIntent
            )
        }
    }
}

class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean("flutter.daily_reminder_enabled", false)
        if (!enabled) return

        val hour = prefs.getLong("flutter.daily_reminder_hour", 18L).toInt()
        val minute = prefs.getLong("flutter.daily_reminder_minute", 30L).toInt()

        // Re-schedule tomorrow's reminder
        DailyReminderScheduler.scheduleNext(context, true, hour, minute)

        val (pendingCount, stationCount) = try {
            PickupDatabaseHelper(context).getPendingSummary()
        } catch (_: Throwable) {
            0 to 0
        }

        if (pendingCount <= 0) return

        val title = "取件提醒：还有 $pendingCount 个包裹未取"
        val body = "今天有 $pendingCount 个包裹还没取，分布在 $stationCount 个驿站，别忘了去拿~"
        PickupNotificationHelper.showDailyReminder(context, title, body)
    }
}
