import 'dart:convert';

import 'station_rule.dart';

class ParserRuleBundle {
  const ParserRuleBundle({
    required this.version,
    this.updatedAt = '',
    required this.listStationPrefixes,
    required this.stationSuffixes,
    this.extraTriggerKeywords = const [],
    this.extraNoiseWords = const [],
    this.presetStationRules = const [],
  });

  final int version;
  final String updatedAt;
  final List<String> listStationPrefixes;
  final List<String> stationSuffixes;
  final List<String> extraTriggerKeywords;
  final List<String> extraNoiseWords;
  final List<StationRule> presetStationRules;

  static const List<String> defaultListStationPrefixes = [
    '代收点',
    '自提点',
    '快递柜',
    '驿站',
    '多多买菜',
    '菜鸟乡村',
    '菜鸟驿站',
    '菜鸟直送',
    '兔喜生活',
    '妈妈驿站',
    '丰巢',
  ];

  static const List<String> defaultStationSuffixes = [
    '菜鸟校园驿站',
    '菜鸟驿站',
    '圆通妈妈驿站',
    '妈妈驿站',
    '兔喜生活',
    '兔喜快递超市',
    '兔喜驿站',
    '多多驿站',
    '多多买菜自提点',
    '丰巢快递柜',
    '丰巢智能柜',
    '丰巢柜',
    '丰巢',
    '中邮速递易',
    '速递易',
    '近邻宝智能柜',
    '近邻宝快递柜',
    '近邻宝',
    '蜜罐',
    '京东派',
    '京东快递柜',
    '京东自提柜',
    '京东自提点',
    '校园派',
    '校园小邮局',
    '小邮局',
    '熊猫快收',
    '快宝驿站',
    '蓝店',
    '百世邻里',
    '极兔邻里',
    '顺丰服务点',
    '顺丰驿站',
    '公共服务站',
    '便民服务站',
    '快递服务中心',
    '物流服务中心',
    '快递超市',
    '驿站超市',
    '快递柜',
    '智能柜',
    '自提柜',
    '快递站',
    '快递点',
    '驿站',
    '代收点',
    '自提点',
  ];

  factory ParserRuleBundle.defaults() {
    return const ParserRuleBundle(
      version: 1,
      updatedAt: '内置默认',
      listStationPrefixes: defaultListStationPrefixes,
      stationSuffixes: defaultStationSuffixes,
    );
  }

  /// Merges remote/custom lists with built-in defaults so a partial remote JSON
  /// safely extends recognition without losing core built-in rules.
  ParserRuleBundle mergedWithDefaults() {
    List<String> mergeUnique(List<String> primary, List<String> fallback) {
      final seen = <String>{};
      final out = <String>[];
      for (final raw in [...primary, ...fallback]) {
        final s = raw.trim();
        if (s.isNotEmpty && seen.add(s)) {
          out.add(s);
        }
      }
      // Longer phrases first so regex alternation matches specific names before generic ones
      out.sort((a, b) => b.length.compareTo(a.length));
      return out;
    }

    return ParserRuleBundle(
      version: version,
      updatedAt: updatedAt,
      listStationPrefixes: mergeUnique(
        listStationPrefixes,
        defaultListStationPrefixes,
      ),
      stationSuffixes: mergeUnique(stationSuffixes, defaultStationSuffixes),
      extraTriggerKeywords: mergeUnique(extraTriggerKeywords, const []),
      extraNoiseWords: mergeUnique(extraNoiseWords, const []),
      presetStationRules: presetStationRules,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'updatedAt': updatedAt,
      'listStationPrefixes': listStationPrefixes,
      'stationSuffixes': stationSuffixes,
      'extraTriggerKeywords': extraTriggerKeywords,
      'extraNoiseWords': extraNoiseWords,
      'presetStationRules': presetStationRules.map((e) => e.toJson()).toList(),
    };
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  factory ParserRuleBundle.fromJson(Map<String, dynamic> json) {
    final rawPresets = json['presetStationRules'];
    final presets = rawPresets is List
        ? rawPresets
            .whereType<Map<String, dynamic>>()
            .map(StationRule.fromJson)
            .where((r) => r.standardName.isNotEmpty)
            .toList()
        : const <StationRule>[];

    return ParserRuleBundle(
      version: (json['version'] as int?) ?? 1,
      updatedAt: (json['updatedAt'] as String?)?.trim() ?? '',
      listStationPrefixes: _parseStringList(json['listStationPrefixes']),
      stationSuffixes: _parseStringList(json['stationSuffixes']),
      extraTriggerKeywords: _parseStringList(json['extraTriggerKeywords']),
      extraNoiseWords: _parseStringList(json['extraNoiseWords']),
      presetStationRules: presets,
    ).mergedWithDefaults();
  }

  String encode() => jsonEncode(toJson());

  static ParserRuleBundle decode(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return ParserRuleBundle.fromJson(decoded);
  }
}
