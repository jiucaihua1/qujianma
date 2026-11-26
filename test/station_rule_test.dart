import 'package:flutter_test/flutter_test.dart';
import 'package:qujianma/models/parser_rule_bundle.dart';
import 'package:qujianma/models/pickup_item.dart';
import 'package:qujianma/models/station_rule.dart';
import 'package:qujianma/services/pickup_parser.dart';

void main() {
  group('StationRule matching in PickupParser', () {
    test('custom station rule overrides regex station extraction', () {
      const rules = [
        StationRule(
          id: '1',
          standardName: '东门菜鸟',
          aliases: ['长青南街18号', '沈理东门驿站超市'],
        ),
      ];

      const sms = '【菜鸟驿站】您的包裹已到长青南街18号代收点，凭取件码12-3-405取件。';
      final result = PickupParser.parseSingle(sms, stationRules: rules);
      expect(result, isNotNull);
      expect(result!.code, '12-3-405');
      expect(result.stationName, '东门菜鸟');
    });

    test('longest matched keyword wins over shorter generic keyword', () {
      const rules = [
        StationRule(
          id: '1',
          standardName: '普通丰巢',
          aliases: ['丰巢'],
          order: 0,
        ),
        StationRule(
          id: '2',
          standardName: '东门2号丰巢',
          aliases: ['东门2号丰巢柜'],
          order: 1,
        ),
      ];

      const sms = '【丰巢】凭取件码839204至东门2号丰巢柜取件。';
      final result = PickupParser.parseSingle(sms, stationRules: rules);
      expect(result, isNotNull);
      expect(result!.stationName, '东门2号丰巢');
    });

    test('disabled rules are ignored and fallback regex is used', () {
      const rules = [
        StationRule(
          id: '1',
          standardName: '自定义驿站',
          aliases: ['阳光花园3栋'],
          enabled: false,
        ),
      ];

      const sms = '【菜鸟驿站】包裹已到阳光花园3栋菜鸟驿站，取件码6-2-104。';
      final result = PickupParser.parseSingle(sms, stationRules: rules);
      expect(result, isNotNull);
      expect(result!.stationName, isNot('自定义驿站'));
    });

    test('StationRule JSON encode and decode round-trip', () {
      const rules = [
        StationRule(
          id: 'r1',
          standardName: '南门兔喜',
          aliases: ['南门超市', '兔喜生活南门店'],
          enabled: true,
          order: 0,
        ),
      ];

      final encoded = StationRule.encodeList(rules);
      final decoded = StationRule.decodeList(encoded);
      expect(decoded.length, 1);
      expect(decoded.first.standardName, '南门兔喜');
      expect(decoded.first.aliases, ['南门超市', '兔喜生活南门店']);
      expect(decoded.first.enabled, isTrue);
    });

    test('parses 菜鸟乡村 公共服务站 list header without falling back to 默认驿站', () {
      const cainiaoList = '''
到站包裹 · 4件
菜鸟乡村 龙鼎御园公共服务站 >
A1-26-9
【方彤彤】的包裹
申通快递 | 今日入站
多多买菜 长青南街18号，理工东门，沈理... >
220-10-6988
天猫 | 【方彤彤】的1-10mm短棉绳diy
''';
      final results = PickupParser.parseAll(cainiaoList);
      expect(results.length, 2);
      expect(results[0].code, 'A1-26-9');
      expect(results[0].stationName, '龙鼎御园公共服务站');
      expect(results[1].code, '220-10-6988');
    });

    test('parses detail card with code left of 取件码 and 菜鸟乡村 station', () {
      const detailText = '''
当前在代收点
申通快递 770361543867962
待取件
菜鸟乡村
龙鼎御园公共服务站 >
A1-26-9 取件码
''';
      final results = PickupParser.parseAll(detailText, defaultSource: PickupSource.ocr);
      expect(results.length, 1);
      expect(results.first.code, 'A1-26-9');
      expect(results.first.stationName, '龙鼎御园公共服务站');
    });

    test('dynamic ParserRuleBundle extends prefixes, suffixes, and presets', () {
      const jsonMap = {
        'version': 2,
        'updatedAt': '2026-11-26',
        'listStationPrefixes': ['极兔网点'],
        'stationSuffixes': ['社区便民点'],
        'presetStationRules': [
          {
            'id': 'preset_1',
            'standardName': '北门便民点',
            'aliases': ['阳光北门社区便民点'],
            'enabled': true,
            'order': 0,
          },
        ],
      };

      final bundle = ParserRuleBundle.fromJson(jsonMap);
      PickupParser.setDynamicBundle(bundle);
      try {
        const listText = '''
到站包裹 · 1件
极兔网点 阳光北门社区便民点 >
88-1-203
''';
        final results = PickupParser.parseAll(listText);
        expect(results.length, 1);
        expect(results.first.code, '88-1-203');
        expect(results.first.stationName, '北门便民点');
      } finally {
        PickupParser.setDynamicBundle(ParserRuleBundle.defaults());
      }
    });
  });
}
