package com.qujianma.qujianma

import android.content.Context
import android.provider.Telephony

data class SmsScanSummary(
    val scannedCount: Int,
    val matchedCount: Int,
    val insertedCount: Int,
    val skippedCount: Int,
    val insertedCodes: List<String>,
)

object SmsInboxScanner {
    fun scanRecentDays(context: Context, days: Int): SmsScanSummary {
        val safeDays = days.coerceIn(1, 30)
        val cutoffMs = System.currentTimeMillis() - safeDays * 86_400_000L

        var scanned = 0
        val collected = LinkedHashMap<String, NativeParsedPickup>()

        val projection = arrayOf(Telephony.Sms.BODY, Telephony.Sms.DATE)
        val selection = "${Telephony.Sms.DATE} >= ?"
        val selectionArgs = arrayOf(cutoffMs.toString())
        val sortOrder = "${Telephony.Sms.DATE} DESC"

        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            sortOrder
        )?.use { cursor ->
            val bodyIdx = cursor.getColumnIndex(Telephony.Sms.BODY)
            while (cursor.moveToNext() && scanned < 500) {
                scanned++
                if (bodyIdx < 0) continue
                val body = cursor.getString(bodyIdx)?.trim() ?: continue
                if (!PickupParserNative.looksLikePickupSms(body)) continue

                val parsed = PickupParserNative.parseAll(body, defaultSource = "sms", context = context)
                for (item in parsed) {
                    val key = item.code.uppercase()
                    if (!collected.containsKey(key)) {
                        collected[key] = item
                    }
                }
            }
        }

        if (collected.isEmpty()) {
            return SmsScanSummary(
                scannedCount = scanned,
                matchedCount = 0,
                insertedCount = 0,
                skippedCount = 0,
                insertedCodes = emptyList(),
            )
        }

        val dbHelper = PickupDatabaseHelper(context.applicationContext)
        val insertRes = try {
            dbHelper.insertUnique(collected.values.toList(), dedupHistoryDays = days)
        } finally {
            dbHelper.close()
        }

        return SmsScanSummary(
            scannedCount = scanned,
            matchedCount = collected.size,
            insertedCount = insertRes.inserted.size,
            skippedCount = insertRes.skippedCount,
            insertedCodes = insertRes.inserted.map { "${it.code}（${it.stationName}）" },
        )
    }
}
