import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/pickup_item.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'qujianma.db';
  static const _dbVersion = 2;
  static const _table = 'pickup_items';

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;

    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);
    _db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
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
        ''');
        await db.execute(
          'CREATE INDEX idx_pickup_status ON $_table (is_picked_up, created_at DESC)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final columns = await db.rawQuery('PRAGMA table_info($_table)');
          final hasCategory = columns.any((c) => c['name'] == 'item_category');
          if (!hasCategory) {
            await db.execute(
              "ALTER TABLE $_table ADD COLUMN item_category TEXT NOT NULL DEFAULT ''",
            );
          }
        }
      },
    );
    return _db!;
  }

  Future<List<PickupItem>> getPendingItems() async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'is_picked_up = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return rows.map(PickupItem.fromMap).toList();
  }

  Future<List<PickupItem>> getHistoryItems() async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'is_picked_up = ?',
      whereArgs: [1],
      orderBy: 'picked_up_at DESC, created_at DESC',
    );
    return rows.map(PickupItem.fromMap).toList();
  }

  Future<PickupItem> insertItem(PickupItem item) async {
    final db = await database;
    final id = await db.insert(_table, item.toMap());
    return item.copyWith(id: id);
  }

  Future<void> updateItem(PickupItem item) async {
    if (item.id == null) return;
    final db = await database;
    await db.update(
      _table,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> markPickedUp(int id, {required bool pickedUp}) async {
    final db = await database;
    await db.update(
      _table,
      {
        'is_picked_up': pickedUp ? 1 : 0,
        'picked_up_at':
            pickedUp ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItem(int id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> cleanOldPickedUpItems(int days) async {
    if (days <= 0) return 0;
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    return db.delete(
      _table,
      where: 'is_picked_up = 1 AND picked_up_at IS NOT NULL AND picked_up_at < ?',
      whereArgs: [cutoff],
    );
  }
}
