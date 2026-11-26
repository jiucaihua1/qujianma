import 'package:flutter_test/flutter_test.dart';
import 'package:qujianma/models/pickup_item.dart';
import 'package:qujianma/services/pickup_parser.dart';

void main() {
  group('PickupParser', () {
    test('parses Cainiao station SMS with hyphenated code', () {
      const sms =
          '【菜鸟驿站】您的包裹已到阳光花园菜鸟驿站，凭取件码12-3-405领取，运单号YT1234567890123';
      final result = PickupParser.parseSingle(sms);
      expect(result, isNotNull);
      expect(result!.code, '12-3-405');
      expect(result.stationName, '阳光花园菜鸟驿站');
      expect(result.source, PickupSource.taobao);
      expect(result.trackingNumber, 'YT1234567890123');
    });

    test('parses HiveBox (丰巢) numeric pickup code', () {
      const sms = '【丰巢】您的顺丰包裹已存入东门丰巢快递柜，凭取件码839204开柜取件。';
      final result = PickupParser.parseSingle(sms);
      expect(result, isNotNull);
      expect(result!.code, '839204');
      expect(result.stationName, '东门丰巢快递柜');
      expect(result.source, PickupSource.sms);
    });

    test('parses Pinduoduo / 多多驿站 message', () {
      const sms = '【多多驿站】您的拼多多包裹已到南门多多驿站，请凭A1-2-304尽快取件';
      final result = PickupParser.parseSingle(sms);
      expect(result, isNotNull);
      expect(result!.code, 'A1-2-304');
      expect(result.stationName, '南门多多驿站');
      expect(result.source, PickupSource.pinduoduo);
    });

    test('parses multiple SMS blocks at once', () {
      const multiSms = '''
【菜鸟驿站】您的包裹已到北门菜鸟驿站，凭取件码3-1-208领取
【丰巢】凭取件码458291到东门丰巢快递柜取件
''';
      final results = PickupParser.parseAll(multiSms);
      expect(results.length, 2);
      expect(results[0].code, '3-1-208');
      expect(results[0].stationName, '北门菜鸟驿站');
      expect(results[1].code, '458291');
      expect(results[1].stationName, '东门丰巢快递柜');
    });

    test('does not misidentify dates or normal chat as pickup text', () {
      expect(PickupParser.looksLikePickupText('明天 2026-11-25 一起吃饭吗'), isFalse);
      expect(
        PickupParser.looksLikePickupText('【菜鸟驿站】凭取件码6-2-104取件'),
        isTrue,
      );
    });

    test('parses 2-segment 4-digit shelf code and 4-segment code from OCR', () {
      const ocrText = '''
菜鸟驿站
3-2018
1-2-3-405
''';
      final results = PickupParser.parseAll(ocrText, defaultSource: PickupSource.ocr);
      expect(results.map((e) => e.code), ['3-2018', '1-2-3-405']);
    });

    test('handles OCR spaces, full-width hyphens, and newline after keyword', () {
      const ocrText = '''
阳光花园菜鸟驿站
取件码
12 - 3 - 405
另一件：12－4－506
''';
      final results = PickupParser.parseAll(ocrText, defaultSource: PickupSource.ocr);
      expect(results.map((e) => e.code), ['12-3-405', '12-4-506']);
    });

    test('ignores logistics timestamps, business hours, and phone numbers', () {
      const ocrText = '''
淘宝物流
11-24 10:30 包裹已到阳光花园菜鸟驿站
营业时间 09:00-21:00
联系电话 138-1234-5678
08-15 历史记录
取件码：839204
''';
      final results = PickupParser.parseAll(ocrText, defaultSource: PickupSource.ocr);
      expect(results.length, 1);
      expect(results.first.code, '839204');
      expect(results.first.stationName, '阳光花园菜鸟驿站');
    });

    test('parses spaced numeric code, parenthesized keyword, and code above label', () {
      const card1 = '东门丰巢快递柜\n取件码（已到柜）\n839 204';
      const card2 = '阳光花园菜鸟驿站\n654321\n取件码';

      final r1 = PickupParser.parseSingle(card1, defaultSource: PickupSource.ocr);
      final r2 = PickupParser.parseSingle(card2, defaultSource: PickupSource.ocr);
      expect(r1?.code, '839204');
      expect(r2?.code, '654321');
    });

    test('strips verbose province/city/district and notes from station name', () {
      const sms =
          '【菜鸟驿站】您的包裹已到北京市朝阳区望京街道阳光花园3栋菜鸟驿站（近东门），凭取件码5-2-108领取';
      final result = PickupParser.parseSingle(sms);
      expect(result, isNotNull);
      expect(result!.code, '5-2-108');
      expect(result.stationName, '阳光花园3栋菜鸟驿站');
      expect(
        PickupParser.normalizeStationKey('阳光花园3栋菜鸟驿站-代收点'),
        PickupParser.normalizeStationKey('北京市朝阳区阳光花园3栋菜鸟驿站（近东门）'),
      );
    });

    test('parses real Cainiao multi-station list without misusing recipient brackets', () {
      const cainiaoScreen = '''
到站包裹 · 3件
多多买菜 长青南街18号，理工东门，沈理... >
220-10-6988
天猫 | 【方彤彤】的1-10mm短棉绳diy
极兔速递 | 已入站1天
代收点 沈理东门驿站超市 >
210-10-6203
淘宝 | 【方彤彤】的窗帘挂钩吊环浴帘
邮政快递 | 已入站3天
216-2-8230
淘宝 | 【方彤彤】的秋冬新款珍珠袖套
邮政快递 | 今日入站
近日签收 · 2件
已签收 11-23 12:01签收
''';
      final results =
          PickupParser.parseAll(cainiaoScreen, defaultSource: PickupSource.ocr);
      expect(results.length, 3);
      expect(results[0].code, '220-10-6988');
      expect(results[0].stationName, contains('长青南街18号'));
      expect(results[0].stationName, isNot('方彤彤'));
      expect(results[0].itemNote, '1-10mm短棉绳diy');

      expect(results[1].code, '210-10-6203');
      expect(results[1].stationName, '沈理东门驿站超市');
      expect(results[1].itemNote, '窗帘挂钩吊环浴帘');

      expect(results[2].code, '216-2-8230');
      expect(results[2].stationName, '沈理东门驿站超市');
      expect(results[2].itemNote, '秋冬新款珍珠袖套');
    });

    test('handles split 2-line station headers and long product titles from DFS nodes', () {
      const dfsNodes = '''
到站包裹
3件
多多买菜
长青南街18号，理工东门，沈理驿站超市沈理东门驿站超市
220-10-6988
天猫 | 【方彤彤】的1-10mm短棉绳diy手工编织粽子绳挂毯编织线绳棉绳绳子
极兔速递 | 已入站1天
代收点
沈理东门驿站超市
210-10-6203
淘宝 | 【方彤彤】的窗帘挂钩吊环浴帘挂钩C型环床帘活口浴室伸缩杆开口环圈钩子配件
邮政快递 | 已入站3天
近日签收
2件
''';
      final results =
          PickupParser.parseAll(dfsNodes, defaultSource: PickupSource.ocr);
      expect(results.length, 2);
      expect(results[0].code, '220-10-6988');
      expect(results[0].stationName, '沈理东门驿站超市');
      expect(results[0].itemNote, startsWith('1-10mm短棉绳diy'));
      expect(results[1].code, '210-10-6203');
      expect(results[1].stationName, '沈理东门驿站超市');
      expect(results[1].itemNote, startsWith('窗帘挂钩吊环浴帘'));
    });

    test('parses 递管家 / 京东派 SMS with alphanumeric code and ignores masked tracking', () {
      const sms =
          '【递管家】您的快递:*43432已到沈阳理工大学京东派，请用02A006到人工货架取包裹，咨询驿站工作人员';
      expect(PickupParser.looksLikePickupText(sms), isTrue);
      final results = PickupParser.parseAll(sms, defaultSource: PickupSource.sms);
      expect(results.length, 1);
      expect(results.first.code, '02A006');
      expect(results.first.stationName, '沈阳理工大学京东派');
    });

    test('parses letter-prefix hyphen codes and bracketed codes without matching unit specs', () {
      const sms = '【兔喜生活】包裹已到南门快递站，凭“A-102”或取件码【B-2034】领取，商品1-10g小样';
      final results = PickupParser.parseAll(sms, defaultSource: PickupSource.sms);
      expect(results.map((e) => e.code), ['A-102', 'B-2034']);
      expect(results.first.stationName, '南门快递站');
    });

    test('parses diverse Chinese courier stations (近邻宝/速递易/熊猫快收/小邮局/蓝店/京东自提柜)', () {
      const samples = <({String sms, String code, String station})>[
        (
          sms: '【近邻宝】您的快件已存入东区近邻宝智能柜，请凭开箱码748291取件',
          code: '748291',
          station: '东区近邻宝智能柜',
        ),
        (
          sms: '【中邮速递易】包裹已到北门中邮速递易，839204为您的取件码',
          code: '839204',
          station: '北门中邮速递易',
        ),
        (
          sms: '【熊猫快收】快件已到学院路熊猫快收，货架号A2B06，请及时取件',
          code: 'A2B06',
          station: '学院路熊猫快收',
        ),
        (
          sms: '【小邮局】您的包裹已到教学楼校园小邮局，请用3C-108/3C-109领取',
          code: '3C-108',
          station: '教学楼校园小邮局',
        ),
        (
          sms: '【京东快递】您的京东包裹(JDVA1234567890)已存入南门京东自提柜，自提码：665544',
          code: '665544',
          station: '南门京东自提柜',
        ),
      ];

      for (final s in samples) {
        expect(PickupParser.looksLikePickupText(s.sms), isTrue, reason: s.sms);
        final parsed = PickupParser.parseAll(s.sms, defaultSource: PickupSource.sms);
        expect(parsed, isNotEmpty, reason: s.sms);
        expect(parsed.first.code, s.code, reason: s.sms);
        expect(parsed.first.stationName, s.station, reason: s.sms);
      }
    });

    test('rejects banking OTPs, telecom bills, and already-signed-off SMS', () {
      const noiseSamples = [
        '【招商银行】您尾号1234信用卡消费88.50元，验证码654321请勿泄露',
        '【中国移动】您的11月话费账单已出，当前余额35.20元，输入10086查询',
        '【铁路12306】您购买的G1234次列车车票已出票，检票口A12',
        '【菜鸟驿站】您的包裹已签收，感谢使用菜鸟驿站！',
        '【丰巢】您的包裹已从东门丰巢快递柜取出，欢迎下次使用。',
      ];
      for (final msg in noiseSamples) {
        expect(PickupParser.looksLikePickupText(msg), isFalse, reason: msg);
      }
    });

    test('ignores clothing sizes, weight ranges, and in-transit e-commerce order lists', () {
      const douyinOrderPage = '''
cotton旗舰店 已发货
深麻灰/3XL(85-95KG) x1
已发货 预计11月27日(周五)送达
叙格品质男装 运输中
春秋新款弯刀牛仔裤美式...
浅蓝色/4XL(（建议体重180-195）... x1
运输中 包裹已离开杭州市，预计后天送达
''';
      expect(
        PickupParser.parseAll(douyinOrderPage, defaultSource: PickupSource.ocr),
        isEmpty,
      );

      const mixedWithStation = '''
阳光花园菜鸟驿站
浅蓝色/4XL(（建议体重180-195）
身高170-180cm 尺码38-39码
取件码：12-3-405
''';
      final mixedResults =
          PickupParser.parseAll(mixedWithStation, defaultSource: PickupSource.ocr);
      expect(mixedResults.map((e) => e.code), ['12-3-405']);
    });

    test('parses JD order list (screen 1) and JD logistics detail (screen 2) OCR text', () {
      const jdOrderListOcr = '''
自营 京东大药房 请上门自提
待取件 | 取件码25A031
¥27.87 共3件 2件已取消
国药准字Z23021546 黑药广审(视) 第250427-01881号
''';
      final r1 = PickupParser.parseAll(jdOrderListOcr, defaultSource: PickupSource.ocr);
      expect(r1.length, 1);
      expect(r1.first.code, '25A031');

      const jdLogisticsDetailOcr = '''
等待自提
自提码：25A031
取件码：25A031
沈阳理工大学京东派
沈阳市浑南区沈阳理工大学综合楼B区京东派
沈阳理工大学校园服务站
JD0271158721549
待取件
您的订单在京东【沈阳理工大学校园服务站】上架完成，请上门自提
2026-11-25 09:04:03
''';
      final r2 = PickupParser.parseAll(jdLogisticsDetailOcr, defaultSource: PickupSource.ocr);
      expect(r2.length, 1);
      expect(r2.first.code, '25A031');
      expect(r2.first.stationName, '沈阳理工大学京东派');
      expect(r2.first.trackingNumber, 'JD0271158721549');
    });
  });
}
