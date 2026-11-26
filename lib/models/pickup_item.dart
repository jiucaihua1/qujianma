import 'package:flutter/material.dart';

enum PickupSource {
  taobao('taobao', '淘宝/菜鸟', Color(0xFFFF6A00)),
  pinduoduo('pinduoduo', '拼多多', Color(0xFFE02E24)),
  sms('sms', '短信', Color(0xFF2B8A3E)),
  ocr('ocr', '截图识别', Color(0xFF3B82F6)),
  manual('manual', '手动录入', Color(0xFF6B7280));

  const PickupSource(this.key, this.label, this.color);

  final String key;
  final String label;
  final Color color;

  static PickupSource fromKey(String? key) {
    return PickupSource.values.firstWhere(
      (e) => e.key == key,
      orElse: () => PickupSource.manual,
    );
  }
}

enum ItemCategory {
  clothing('clothing', '服饰', Icons.checkroom_rounded, Color(0xFFEC4899)),
  snacks('snacks', '零食', Icons.cookie_rounded, Color(0xFFF59E0B)),
  daily('daily', '日用', Icons.cleaning_services_rounded, Color(0xFF0EA5E9)),
  electronics('electronics', '数码', Icons.devices_rounded, Color(0xFF6366F1)),
  beauty('beauty', '美妆', Icons.face_retouching_natural_rounded, Color(0xFFF43F5E)),
  fresh('fresh', '生鲜', Icons.eco_rounded, Color(0xFF10B981)),
  books('books', '图书', Icons.menu_book_rounded, Color(0xFF8B5CF6)),
  other('other', '其他', Icons.inventory_2_rounded, Color(0xFF64748B));

  const ItemCategory(this.key, this.label, this.icon, this.color);

  final String key;
  final String label;
  final IconData icon;
  final Color color;

  static ItemCategory? fromKey(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    for (final c in ItemCategory.values) {
      if (c.key == key) return c;
    }
    return null;
  }
}

class PickupItem {
  const PickupItem({
    this.id,
    required this.code,
    required this.stationName,
    this.source = PickupSource.manual,
    this.itemCategory,
    this.itemNote = '',
    this.trackingNumber = '',
    this.rawText = '',
    required this.createdAt,
    this.isPickedUp = false,
    this.pickedUpAt,
  });

  final int? id;
  final String code;
  final String stationName;
  final PickupSource source;
  final ItemCategory? itemCategory;
  final String itemNote;
  final String trackingNumber;
  final String rawText;
  final DateTime createdAt;
  final bool isPickedUp;
  final DateTime? pickedUpAt;

  PickupItem copyWith({
    int? id,
    String? code,
    String? stationName,
    PickupSource? source,
    ItemCategory? itemCategory,
    bool clearItemCategory = false,
    String? itemNote,
    String? trackingNumber,
    String? rawText,
    DateTime? createdAt,
    bool? isPickedUp,
    DateTime? pickedUpAt,
    bool clearPickedUpAt = false,
  }) {
    return PickupItem(
      id: id ?? this.id,
      code: code ?? this.code,
      stationName: stationName ?? this.stationName,
      source: source ?? this.source,
      itemCategory:
          clearItemCategory ? null : (itemCategory ?? this.itemCategory),
      itemNote: itemNote ?? this.itemNote,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      rawText: rawText ?? this.rawText,
      createdAt: createdAt ?? this.createdAt,
      isPickedUp: isPickedUp ?? this.isPickedUp,
      pickedUpAt: clearPickedUpAt ? null : (pickedUpAt ?? this.pickedUpAt),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'station_name': stationName,
      'source': source.key,
      'item_category': itemCategory?.key ?? '',
      'item_note': itemNote,
      'tracking_number': trackingNumber,
      'raw_text': rawText,
      'created_at': createdAt.millisecondsSinceEpoch,
      'is_picked_up': isPickedUp ? 1 : 0,
      'picked_up_at': pickedUpAt?.millisecondsSinceEpoch,
    };
  }

  factory PickupItem.fromMap(Map<String, Object?> map) {
    final pickedUpMs = map['picked_up_at'] as int?;
    return PickupItem(
      id: map['id'] as int?,
      code: (map['code'] as String?) ?? '',
      stationName: (map['station_name'] as String?) ?? '默认驿站',
      source: PickupSource.fromKey(map['source'] as String?),
      itemCategory: ItemCategory.fromKey(map['item_category'] as String?),
      itemNote: (map['item_note'] as String?) ?? '',
      trackingNumber: (map['tracking_number'] as String?) ?? '',
      rawText: (map['raw_text'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      isPickedUp: ((map['is_picked_up'] as int?) ?? 0) == 1,
      pickedUpAt: pickedUpMs != null
          ? DateTime.fromMillisecondsSinceEpoch(pickedUpMs)
          : null,
    );
  }
}
