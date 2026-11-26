package com.qujianma.qujianma

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

data class InsertResult(
    val inserted: List<NativeParsedPickup>,
    val skippedCount: Int,
)

class PickupDatabaseHelper(context: Context) :
    SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.enableWriteAheadLogging()
        db.rawQuery("PRAGMA busy_timeout = 3000", null).close()
    }

    override fun onCreate(db: SQLiteDatabase) {
        ensureSchema(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        ensureSchema(db)
        if (oldVersion < 2) {
            ensureItemCategoryColumn(db)
        }
    }

    private fun ensureSchema(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TABLE_NAME (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT NOT NULL,
                station_name TEXT NOT NULL,
                source TEXT NOT NULL,
                item_category TEXT NOT NULL DEFAULT '',
                item_note TEXT NOT NULL DEFAULT '',
                tracking_number TEXT NOT NULL DEFAULT '',
                raw_text TEXT NOT NULL DEFAULT '',
                created_at INTEGER NOT NULL,
                is_picked_up INTEGER NOT NULL DEFAULT 0,
                picked_up_at INTEGER
            )
            """.trimIndent()
        )
        db.execSQL(
            "CREATE INDEX IF NOT EXISTS idx_pickup_status ON $TABLE_NAME (is_picked_up, created_at DESC)"
        )
        ensureItemCategoryColumn(db)
    }

    private fun ensureItemCategoryColumn(db: SQLiteDatabase) {
        var hasColumn = false
        db.rawQuery("PRAGMA table_info($TABLE_NAME)", null).use { cursor ->
            val nameIdx = cursor.getColumnIndex("name")
            while (cursor.moveToNext()) {
                if (nameIdx >= 0 && cursor.getString(nameIdx) == "item_category") {
                    hasColumn = true
                    break
                }
            }
        }
        if (!hasColumn) {
            db.execSQL("ALTER TABLE $TABLE_NAME ADD COLUMN item_category TEXT NOT NULL DEFAULT ''")
        }
    }

    fun insertUnique(
        candidates: List<NativeParsedPickup>,
        dedupHistoryDays: Int = 0,
    ): InsertResult {
        val db = writableDatabase
        ensureSchema(db)

        val inserted = mutableListOf<NativeParsedPickup>()
        var skipped = 0
        val now = System.currentTimeMillis()
        val historyCutoff = if (dedupHistoryDays > 0) {
            now - dedupHistoryDays.toLong() * 24L * 60L * 60L * 1000L
        } else {
            0L
        }

        db.beginTransaction()
        try {
            for ((index, candidate) in candidates.withIndex()) {
                val code = candidate.code.trim().uppercase()
                if (code.isEmpty()) continue

                val exists = if (dedupHistoryDays > 0) {
                    db.rawQuery(
                        "SELECT 1 FROM $TABLE_NAME WHERE UPPER(code) = ? AND (is_picked_up = 0 OR created_at >= ?) LIMIT 1",
                        arrayOf(code, historyCutoff.toString())
                    ).use { cursor -> cursor.moveToFirst() }
                } else {
                    db.rawQuery(
                        "SELECT 1 FROM $TABLE_NAME WHERE is_picked_up = 0 AND UPPER(code) = ? LIMIT 1",
                        arrayOf(code)
                    ).use { cursor -> cursor.moveToFirst() }
                }

                if (exists) {
                    skipped++
                    continue
                }

                val values = ContentValues().apply {
                    put("code", code)
                    put("station_name", candidate.stationName.ifBlank { "默认驿站" })
                    put("source", candidate.source.ifBlank { "ocr" })
                    put("item_category", "")
                    put("item_note", candidate.itemNote)
                    put("tracking_number", candidate.trackingNumber)
                    put("raw_text", candidate.rawText)
                    put("created_at", now + index)
                    put("is_picked_up", 0)
                    putNull("picked_up_at")
                }
                val rowId = db.insert(TABLE_NAME, null, values)
                if (rowId != -1L) {
                    inserted.add(candidate.copy(code = code))
                }
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }

        return InsertResult(inserted = inserted, skippedCount = skipped)
    }

    fun getPendingSummary(): Pair<Int, Int> {
        val db = readableDatabase
        var itemCount = 0
        val stations = mutableSetOf<String>()
        db.rawQuery(
            "SELECT station_name FROM $TABLE_NAME WHERE is_picked_up = 0",
            null
        ).use { cursor ->
            while (cursor.moveToNext()) {
                itemCount++
                val raw = cursor.getString(0)?.trim().orEmpty()
                stations.add(if (raw.isEmpty()) "默认驿站" else raw)
            }
        }
        return itemCount to stations.size
    }

    companion object {
        private const val DB_NAME = "qujianma.db"
        private const val DB_VERSION = 2
        private const val TABLE_NAME = "pickup_items"
    }
}
