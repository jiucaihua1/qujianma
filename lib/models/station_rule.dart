import 'dart:convert';

class StationRule {
  const StationRule({
    required this.id,
    required this.standardName,
    this.aliases = const [],
    this.enabled = true,
    this.order = 0,
  });

  final String id;
  final String standardName;
  final List<String> aliases;
  final bool enabled;
  final int order;

  /// All matchable keywords for this rule (standardName + aliases),
  /// deduplicated and trimmed.
  List<String> get allKeywords {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in [standardName, ...aliases]) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed)) {
        result.add(trimmed);
      }
    }
    return result;
  }

  StationRule copyWith({
    String? id,
    String? standardName,
    List<String>? aliases,
    bool? enabled,
    int? order,
  }) {
    return StationRule(
      id: id ?? this.id,
      standardName: standardName ?? this.standardName,
      aliases: aliases ?? this.aliases,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'standardName': standardName,
      'aliases': aliases,
      'enabled': enabled,
      'order': order,
    };
  }

  factory StationRule.fromJson(Map<String, dynamic> json) {
    final rawAliases = json['aliases'];
    final aliases = rawAliases is List
        ? rawAliases
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
    return StationRule(
      id: (json['id'] as String?) ??
          'rule_${DateTime.now().microsecondsSinceEpoch}',
      standardName: (json['standardName'] as String?)?.trim() ?? '',
      aliases: aliases,
      enabled: (json['enabled'] as bool?) ?? true,
      order: (json['order'] as int?) ?? 0,
    );
  }

  static String encodeList(List<StationRule> rules) =>
      jsonEncode(rules.map((e) => e.toJson()).toList());

  static List<StationRule> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    final list = decoded
        .whereType<Map<String, dynamic>>()
        .map(StationRule.fromJson)
        .where((r) => r.standardName.isNotEmpty)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }
}

enum StationSuggestionType {
  promoteFrequent,
  mergeSimilar,
}

class StationSuggestion {
  const StationSuggestion({
    required this.id,
    required this.type,
    required this.primaryName,
    this.secondaryNames = const [],
    this.occurrenceCount = 0,
  });

  final String id;
  final StationSuggestionType type;
  final String primaryName;
  final List<String> secondaryNames;
  final int occurrenceCount;
}
