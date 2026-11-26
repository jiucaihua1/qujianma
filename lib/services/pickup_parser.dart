import '../models/parser_rule_bundle.dart';
import '../models/pickup_item.dart';
import '../models/station_rule.dart';

class ParsedPickupCandidate {
  const ParsedPickupCandidate({
    required this.code,
    required this.stationName,
    required this.source,
    this.trackingNumber = '',
    this.itemNote = '',
    this.rawText = '',
  });

  final String code;
  final String stationName;
  final PickupSource source;
  final String trackingNumber;
  final String itemNote;
  final String rawText;
}

class PickupParser {
  static final _keywordTrigger = RegExp(
    r'(取件码|提货码|取货码|开柜码|开箱码|自提码|核销码|取件密码|取货密码|开柜密码|取件编号|取货编号|提货编号|取件号|取货号|货架号|货架码|凭码|请用|请凭|驿站|快递柜|智能柜|自提柜|丰巢|菜鸟|兔喜|妈妈驿站|多多驿站|多多买菜|速递易|近邻宝|蜜罐|代收点|自提点|京东派|京东自提|递管家|小邮局|熊猫快收|快宝|蓝店|百世邻里|极兔邻里|人工货架|取包裹|包裹已到|包裹已存|快件已到|快递已到|已放入|已存入|已入柜|已入站|请及时取件)',
  );

  // Strong non-pickup SMS indicators (OTP, banking, telecom, travel)
  static final _nonPickupNoiseRegex = RegExp(
    r'(验证码|动态码|校验码|登录码|支付密码|银行卡|信用卡|余额|消费|还款|账单|话费|流量|航班|列车|车票|电影票|登机口)',
  );

  // Strong express/station anchor that overrides noise words if truly a pickup SMS
  static final _strongExpressAnchor = RegExp(
    r'(取件码|提货码|取货码|开柜码|开箱码|自提码|驿站|快递柜|智能柜|丰巢|菜鸟|兔喜|多多驿站|速递易|近邻宝|京东派|递管家|小邮局|熊猫快收|快宝|包裹|快件|取件)',
  );

  // Already-completed pickup notifications (should not be re-imported on SMS backfill)
  static final _alreadyPickedUpRegex = RegExp(
    r'(已签收|已取出|已取走|已完成取件|已出库|签收成功)',
  );

  // Explicit pickup code after keyword:
  // Supports: 取件码：12-3-405 / 请用02A006 / 货架号A-102 / 凭“839 204”取件 / 取件码【A2B06】 / 开箱密码123456
  static final _explicitCodeRegex = RegExp(
    r'(?:取件码|提货码|取货码|开柜码|开箱码|自提码|核销码|取件密码|取货密码|开柜密码|取件编号|取货编号|提货编号|取件号|取货号|货架号|货架码|凭码|请凭|请用|凭|输入)\s*(?:[（(][^）)\n]{1,12}[）)])?\s*[为是:：]?\s*[“"【\[]?(?<!\*)([A-Za-z]{1,2}-\d{1,5}(?:-\d{1,5})?|[A-Za-z]?\d{1,3}(?:-\d{1,5}){1,3}[A-Z]?|[A-Za-z]\d{1,2}[A-Za-z]\d{1,4}|\d{1,3}[A-Za-z]\d{2,5}|[A-Za-z]\d{3,7}|\d{3,4}[ \t]\d{3,4}|\d{4,8})[”"】\]]?',
  );

  // Reverse layout:
  // 1) Large code placed right ABOVE or LEFT OF "取件码" label in app cards ("839204\n取件码" or "A1-26-9 取件码")
  // 2) Inline reverse SMS ("02A006为您的取件码", "839204是您的开柜码")
  static final _codeBeforeKeywordRegex = RegExp(
    r'(?:(?:^|\n)\s*([A-Za-z]{1,2}-\d{1,5}(?:-\d{1,5})?|[A-Za-z]?\d{1,3}(?:-\d{1,5}){1,3}[A-Z]?|[A-Za-z]\d{1,2}[A-Za-z]\d{1,4}|\d{1,3}[A-Za-z]\d{2,5}|\d{3,4}[ \t]\d{3,4}|\d{4,8})\s*(?:\n|[ \t]+)\s*(?:取件码|提货码|取货码|开柜码|开箱码|自提码|取件密码)|(?<![A-Za-z0-9-:*])([A-Za-z]{1,2}-\d{1,5}(?:-\d{1,5})?|[A-Za-z]?\d{1,3}(?:-\d{1,5}){1,3}[A-Z]?|\d{1,3}[A-Za-z]\d{2,5}|\d{4,8})\s*(?:为您的|是您的|为|是)\s*(?:取件码|提货码|取货码|开柜码|开箱码|自提码))',
  );

  // Hyphenated shelf codes commonly seen in Cainiao / stations: 12-3-405, 3-2018, A2-1-09, A-102, 1-2-3-405
  // Exclude lowercase unit letters like 1-10g, 2-5m by only allowing uppercase trailing letters.
  static final _shelfCodeRegex = RegExp(
    r'(?<![A-Za-z0-9-:*])([A-Za-z]{1,2}-\d{1,5}(?:-\d{1,5})?|[A-Za-z]?\d{1,3}-\d{1,5}(?:-\d{1,5}){0,2}[A-Z]?)(?![A-Za-z0-9-:])',
  );

  // Explicit tracking number patterns
  static final _explicitTrackingRegex = RegExp(
    r'(?:运单号|快递单号|单号)\s*[:：]?\s*([A-Za-z]{0,4}\d{10,16})',
  );
  static final _carrierTrackingRegex = RegExp(
    r'\b((?:SF|YT|JT|ZT|YD|JDVA|JDV|JDX|JD|ST|EMS|EA|EB|DPK)[A-Za-z0-9]{9,15}|(?:43|46|75|77|78|98)\d{11,13})\b',
    caseSensitive: false,
  );

  // Station extraction patterns (allow longer raw address strings; _cleanStationName trims province/city/district prefixes)
  static final _bracketBrandRegex = RegExp(
    r'[【\[]([^【\[\]】]{2,16}(?:菜鸟|驿站|丰巢|兔喜|多多|妈妈|速递易|近邻宝|蜜罐|快递|代收|顺丰|中通|圆通|申通|韵达|极兔|京东|递管家|小邮局|熊猫快收|快宝|蓝店|百世邻里)[^【\[\]】]{0,8})[】\]]',
  );
  static final _stationLocationRegex = RegExp(
    r'(?:已到|到达|已存放在?|已存入|已放入|已放至|已抵达|已入柜|送达|存放在?|存入|到|至)\s*([^\s，。！？,.;；:：【】\[\]]{2,38}?(?:菜鸟校园驿站|菜鸟驿站|圆通妈妈驿站|妈妈驿站|兔喜生活|兔喜快递超市|兔喜驿站|多多驿站|多多买菜自提点|丰巢快递柜|丰巢智能柜|丰巢柜|丰巢|中邮速递易|速递易|近邻宝智能柜|近邻宝快递柜|近邻宝|蜜罐|京东派|京东快递柜|京东自提柜|京东自提点|校园派|校园小邮局|小邮局|熊猫快收|快宝驿站|蓝店|百世邻里|极兔邻里|顺丰服务点|顺丰驿站|公共服务站|便民服务站|快递服务中心|物流服务中心|快递超市|驿站超市|快递柜|智能柜|自提柜|快递站|快递点|服务站|服务点|驿站|代收点|自提点|收发室|收发点|门卫))',
  );
  static final _genericStationRegex = RegExp(
    r'([^\s，。！？,.;；:：【】\[\]]{0,30}(?:菜鸟校园驿站|菜鸟驿站|圆通妈妈驿站|妈妈驿站|兔喜生活|兔喜快递超市|兔喜驿站|多多驿站|多多买菜自提点|丰巢快递柜|丰巢智能柜|丰巢柜|丰巢|中邮速递易|速递易|近邻宝智能柜|近邻宝快递柜|近邻宝|蜜罐|京东派|京东快递柜|京东自提柜|京东自提点|校园派|校园小邮局|小邮局|熊猫快收|快宝驿站|蓝店|百世邻里|极兔邻里|顺丰服务点|顺丰驿站|公共服务站|便民服务站|快递服务中心|物流服务中心|快递超市|驿站超市|快递柜|智能柜|自提柜|快递站|快递点|服务站|服务点|驿站|代收点|自提点))',
  );

  // Station header line in Cainiao / Taobao / PDD list screenshots:
  // e.g. "多多买菜 长青南街18号，理工东门，沈理..." or "代收点 沈理东门驿站超市 >" or "菜鸟乡村 龙鼎御园公共服务站 >"
  static final _listStationHeaderRegex = RegExp(
    r'^(?:代收点|自提点|快递柜|驿站|多多买菜|菜鸟乡村|菜鸟驿站|菜鸟直送|兔喜生活|妈妈驿站|丰巢)\s+(.{2,48})$',
  );

  // Standalone station tag line when Android TextViews split tag and address onto two lines
  static final _listStationTagOnlyRegex = RegExp(
    r'^(?:代收点|自提点|快递柜|驿站|多多买菜|菜鸟乡村|菜鸟驿站|菜鸟直送|兔喜生活|妈妈驿站|丰巢)$',
  );

  // Item line right below a code in Cainiao/Taobao list screenshots:
  // e.g. "天猫 | 【方彤彤】的1-10mm短棉绳diy手工编织粽子绳..."
  static final _listItemLineRegex = RegExp(
    r'^(?:天猫|淘宝|拼多多|京东|抖音|快手)\s*[|｜]\s*(?:[【\[][^】\]]+[】\]]的?)?\s*(.{2,100})$',
  );

  // Optional item note from OCR/SMS
  static final _itemNoteRegex = RegExp(
    r'(?:商品|物品|包裹内容|宝贝)\s*[:：]\s*([^\n，。]{2,24})',
  );

  static final _nonPickupPrefixRegex = RegExp(
    r'(?:日期|时间|体重|建议|身高|尺码|码数|适合|适用|约重|净重|毛重|重量|规格|尺寸|鞋码|腰围|胸围|臀围|衣长|裤长|肩宽|袖长|温度|满减|优惠|折扣|区间|范围|年龄|(?:[XSML]|XL|XXL|XXXL|2XL|3XL|4XL|5XL)\s*[（(]?)$',
    caseSensitive: false,
  );
  static final _nonPickupUnitSuffixRegex = RegExp(
    r'^\s*(?:斤|公斤|kg|g|mg|cm|mm|dm|m|ml|l|码|岁|元|块|折|天|小时|时|分钟|分|秒|件|个|双|人|度|℃|%|％|万|千|百)(?![A-Za-z0-9])',
    caseSensitive: false,
  );

  static ParserRuleBundle _dynamicBundle = ParserRuleBundle.defaults();
  static RegExp? _extraTriggerRegex;
  static RegExp? _extraNoiseRegex;
  static RegExp _activeStationLocationRegex = _stationLocationRegex;
  static RegExp _activeGenericStationRegex = _genericStationRegex;
  static RegExp _activeListStationHeaderRegex = _listStationHeaderRegex;
  static RegExp _activeListStationTagOnlyRegex = _listStationTagOnlyRegex;
  static RegExp _activeStandaloneHeaderRegex = RegExp(
    r'(?:菜鸟驿站|妈妈驿站|兔喜生活|多多驿站|丰巢快递柜|丰巢智能柜|公共服务站|便民服务站|驿站超市|驿站|快递柜|代收点)$',
  );

  static ParserRuleBundle get dynamicBundle => _dynamicBundle;

  static void setDynamicBundle(ParserRuleBundle bundle) {
    final merged = bundle.mergedWithDefaults();
    _dynamicBundle = merged;

    final prefixPattern = merged.listStationPrefixes
        .map(RegExp.escape)
        .join('|');
    final suffixPattern = merged.stationSuffixes
        .map(RegExp.escape)
        .join('|');

    if (prefixPattern.isNotEmpty) {
      _activeListStationHeaderRegex = RegExp(
        '^(?:$prefixPattern)\\s+(.{2,48})\$',
      );
      _activeListStationTagOnlyRegex = RegExp('^(?:$prefixPattern)\$');
    }

    if (suffixPattern.isNotEmpty) {
      _activeStationLocationRegex = RegExp(
        '(?:已到|到达|已存放在?|已存入|已放入|已放至|已抵达|已入柜|送达|存放在?|存入|到|至)\\s*([^\\s，。！？,.;；:：【】\\[\\]]{2,38}?(?:$suffixPattern|收发室|收发点|门卫))',
      );
      _activeGenericStationRegex = RegExp(
        '([^\\s，。！？,.;；:：【】\\[\\]]{0,30}(?:$suffixPattern))',
      );
      _activeStandaloneHeaderRegex = RegExp('(?:$suffixPattern)\$');
    }

    _extraTriggerRegex = merged.extraTriggerKeywords.isEmpty
        ? null
        : RegExp('(?:${merged.extraTriggerKeywords.map(RegExp.escape).join('|')})');
    _extraNoiseRegex = merged.extraNoiseWords.isEmpty
        ? null
        : RegExp('(?:${merged.extraNoiseWords.map(RegExp.escape).join('|')})');
  }

  static bool looksLikePickupText(String text) {
    final trimmed = text.trim();
    if (trimmed.length < 6 || trimmed.length > 2000) return false;
    final hasNoise = _nonPickupNoiseRegex.hasMatch(trimmed) ||
        (_extraNoiseRegex?.hasMatch(trimmed) ?? false);
    if (hasNoise && !_strongExpressAnchor.hasMatch(trimmed)) {
      return false;
    }
    if (_alreadyPickedUpRegex.hasMatch(trimmed) &&
        !RegExp(r'(取件码|提货码|取货码|开柜码|请凭|请用|待取)').hasMatch(trimmed)) {
      return false;
    }
    final hasTrigger = _keywordTrigger.hasMatch(trimmed) ||
        (_extraTriggerRegex?.hasMatch(trimmed) ?? false);
    if (!hasTrigger) return false;
    return parseAll(trimmed).isNotEmpty;
  }

  static ParsedPickupCandidate? parseSingle(
    String text, {
    PickupSource defaultSource = PickupSource.sms,
    List<StationRule> stationRules = const [],
  }) {
    final results = parseAll(
      text,
      defaultSource: defaultSource,
      stationRules: stationRules,
    );
    return results.isEmpty ? null : results.first;
  }

  static List<ParsedPickupCandidate> parseAll(
    String rawText, {
    PickupSource defaultSource = PickupSource.sms,
    List<StationRule> stationRules = const [],
  }) {
    final text = rawText.trim();
    if (text.isEmpty) return const [];

    // 1. Try line-aware list parsing first (handles Cainiao/Taobao/PDD multi-station list screens
    //    where a station header line precedes one or more pickup code cards).
    final listParsed = _parseStationListLayout(text, defaultSource: defaultSource);
    if (listParsed.isNotEmpty) {
      return _applyStationRules(listParsed, stationRules);
    }

    // 2. Fallback to SMS / single-card block parsing
    final blocks = _splitIntoBlocks(text);
    final results = <ParsedPickupCandidate>[];
    final seenCodes = <String>{};

    for (final block in blocks) {
      final parsed = _parseBlock(block, defaultSource: defaultSource);
      for (final item in parsed) {
        final dedupKey = '${item.stationName}|${item.code}';
        if (seenCodes.add(dedupKey)) {
          results.add(item);
        }
      }
    }
    return _applyStationRules(results, stationRules);
  }

  static List<ParsedPickupCandidate> _applyStationRules(
    List<ParsedPickupCandidate> items,
    List<StationRule> stationRules,
  ) {
    final presetRules = _dynamicBundle.presetStationRules;
    if ((stationRules.isEmpty && presetRules.isEmpty) || items.isEmpty) {
      return items;
    }
    return items.map((item) {
      final userMatch = matchCustomStation(
        item.rawText,
        stationRules,
        fallbackStation: item.stationName,
      );
      final resolved = userMatch ??
          matchCustomStation(
            item.rawText,
            presetRules,
            fallbackStation: item.stationName,
          ) ??
          item.stationName;
      if (resolved == item.stationName) return item;
      return ParsedPickupCandidate(
        code: item.code,
        stationName: resolved,
        source: item.source,
        trackingNumber: item.trackingNumber,
        itemNote: item.itemNote,
        rawText: item.rawText,
      );
    }).toList();
  }

  static String _normalizeForMatch(String input) {
    return input
        .replaceAll(RegExp(r'[\s\-_·•/\\,，。.;；:：!！?？()（）【】\[\]]'), '')
        .toLowerCase();
  }

  /// Matches [rawText] and [fallbackStation] against enabled user [rules].
  /// Longest matched keyword wins; ties are broken by rule order.
  static String? matchCustomStation(
    String rawText,
    List<StationRule> rules, {
    String? fallbackStation,
  }) {
    if (rules.isEmpty) return null;
    final haystack = _normalizeForMatch(
      '${rawText.trim()}\n${fallbackStation?.trim() ?? ''}',
    );
    if (haystack.isEmpty) return null;

    final sortedRules = rules.where((r) => r.enabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    String? bestStandardName;
    var bestLen = 0;

    for (final rule in sortedRules) {
      for (final keyword in rule.allKeywords) {
        final normKw = _normalizeForMatch(keyword);
        if (normKw.isEmpty) continue;
        if (haystack.contains(normKw) && normKw.length > bestLen) {
          bestLen = normKw.length;
          bestStandardName = rule.standardName.trim();
        }
      }
    }
    return (bestStandardName != null && bestStandardName.isNotEmpty)
        ? bestStandardName
        : null;
  }

  static String resolveStationName({
    required String rawText,
    required String defaultStation,
    required List<StationRule> rules,
  }) {
    return matchCustomStation(
          rawText,
          rules,
          fallbackStation: defaultStation,
        ) ??
        matchCustomStation(
          rawText,
          _dynamicBundle.presetStationRules,
          fallbackStation: defaultStation,
        ) ??
        defaultStation;
  }

  /// Parses multi-package list screens (like Cainiao/Taobao/PDD home lists) line by line
  /// so each pickup code inherits the nearest station header above it and item note below it.
  static List<ParsedPickupCandidate> _parseStationListLayout(
    String text, {
    required PickupSource defaultSource,
  }) {
    final rawLines = text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (rawLines.length < 3) return const [];

    // Merge split 2-line station headers (e.g. "代收点\n沈理东门驿站超市" -> "代收点 沈理东门驿站超市")
    final lines = <String>[];
    for (var i = 0; i < rawLines.length; i++) {
      final cur = rawLines[i];
      if (_activeListStationTagOnlyRegex.hasMatch(cur) && i + 1 < rawLines.length) {
        final next = rawLines[i + 1];
        if (next.length >= 2 && next.length <= 48 && _extractCodes(next).isEmpty) {
          lines.add('$cur $next');
          i++;
          continue;
        }
      }
      lines.add(cur);
    }

    // Only activate list layout mode when we see at least one explicit list station header
    // (like "代收点 xxx", "多多买菜 xxx", or a standalone station header line ending with ">").
    var hasHeader = false;
    for (final line in lines) {
      if (_extractListHeaderStation(line) != null) {
        hasHeader = true;
        break;
      }
    }
    if (!hasHeader) return const [];

    final results = <ParsedPickupCandidate>[];
    final seenCodes = <String>{};
    var currentStation = '默认驿站';
    var currentHeaderLine = '';
    var currentSource = defaultSource;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Stop before "近日签收" / "已签收" section so already picked-up history isn't imported
      if (line.startsWith('近日签收') || line.startsWith('全部包裹')) {
        break;
      }

      final headerStation = _extractListHeaderStation(line);
      if (headerStation != null) {
        currentStation = headerStation;
        currentHeaderLine = line;
        currentSource = _detectSource(line, defaultSource);
        continue;
      }

      // Skip item-title lines (e.g. "天猫 | 【方彤彤】的1-10mm短棉绳diy") so specs like "1-10mm" are never codes
      if (_listItemLineRegex.hasMatch(line)) continue;

      final codes = _extractCodes(line);
      if (codes.isEmpty) continue;

      // Peek at the next 1-2 lines for item note / source / tracking number
      var note = '';
      var source = currentSource;
      var tracking = '';
      for (var j = i + 1; j <= i + 2 && j < lines.length; j++) {
        final nextLine = lines[j];
        if (_extractListHeaderStation(nextLine) != null) break;
        if (_extractCodes(nextLine).isNotEmpty) break;
        final itemMatch = _listItemLineRegex.firstMatch(nextLine);
        if (itemMatch != null && note.isEmpty) {
          final rawNote = (itemMatch.group(1) ?? '').trim();
          note = rawNote.length > 22 ? rawNote.substring(0, 22) : rawNote;
          source = _detectSource(nextLine, source);
        }
        if (tracking.isEmpty) {
          tracking = _extractTrackingNumber(nextLine);
        }
      }

      for (final code in codes) {
        if (seenCodes.add(code)) {
          results.add(
            ParsedPickupCandidate(
              code: code,
              stationName: currentStation,
              source: source,
              trackingNumber: tracking,
              itemNote: note,
              rawText: currentHeaderLine.isEmpty ? line : '$currentHeaderLine\n$line',
            ),
          );
        }
      }
    }
    return results;
  }

  static String? _extractListHeaderStation(String rawLine) {
    final line = rawLine.replaceAll(RegExp(r'[>›»]+$'), '').trim();
    if (line.length < 3 || line.length > 56) return null;
    if (_extractCodes(line).isNotEmpty) return null;

    final headerMatch = _activeListStationHeaderRegex.firstMatch(line);
    if (headerMatch != null) {
      final cleaned = _cleanStationName(headerMatch.group(1) ?? '');
      if (cleaned.length >= 2) return cleaned;
    }
    // Standalone station header line like "沈理东门驿站超市" (no sentence punctuation)
    if (!line.contains('。') &&
        !line.contains('您的') &&
        !line.contains('包裹') &&
        !line.contains('凭') &&
        _activeStandaloneHeaderRegex.hasMatch(line)) {
      final cleaned = _cleanStationName(line);
      if (cleaned.length >= 2) return cleaned;
    }
    return null;
  }

  static List<String> _splitIntoBlocks(String text) {
    // Split on double newlines first
    final byBlankLine = text
        .split(RegExp(r'\r?\n\s*\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (byBlankLine.length > 1) return byBlankLine;

    // Split ONLY on repeated SMS courier/station headers like 【菜鸟驿站】... 【丰巢】...
    // Never split on recipient/product brackets like 【方彤彤】!
    final headerMatches = RegExp(
      r'(?=[【\[][^【\[\]】]{0,12}(?:菜鸟|驿站|丰巢|兔喜|多多|妈妈|速递易|近邻宝|快递|代收|顺丰|中通|圆通|申通|韵达|极兔|京东)[^【\[\]】]{0,8}[】\]])',
    )
        .allMatches(text)
        .map((m) => m.start)
        .toList();
    if (headerMatches.length > 1) {
      final segments = <String>[];
      for (var i = 0; i < headerMatches.length; i++) {
        final start = headerMatches[i];
        final end =
            (i + 1 < headerMatches.length) ? headerMatches[i + 1] : text.length;
        final seg = text.substring(start, end).trim();
        if (seg.isNotEmpty) segments.add(seg);
      }
      if (segments.length > 1) return segments;
    }

    return [text];
  }

  static List<ParsedPickupCandidate> _parseBlock(
    String block, {
    required PickupSource defaultSource,
  }) {
    final station = _extractStation(block);
    final allowBareShelfCodes =
        _keywordTrigger.hasMatch(block) || station != '默认驿站';
    final codes = _extractCodes(block, allowBareShelfCodes: allowBareShelfCodes);
    if (codes.isEmpty) return const [];

    final source = _detectSource(block, defaultSource);
    final tracking = _extractTrackingNumber(block);
    final note = _extractItemNote(block);

    return codes
        .map(
          (code) => ParsedPickupCandidate(
            code: code,
            stationName: station,
            source: source,
            trackingNumber: tracking,
            itemNote: note,
            rawText: block,
          ),
        )
        .toList();
  }

  static List<String> _extractCodes(
    String rawText, {
    bool allowBareShelfCodes = true,
  }) {
    // Normalize OCR hyphen variants and spaces around hyphens (e.g. "12 - 3 - 405" -> "12-3-405")
    final text = rawText
        .replaceAll(RegExp(r'[—–－]'), '-')
        .replaceAll(RegExp(r'(?<=[A-Za-z0-9])\s*-\s*(?=[A-Za-z0-9])'), '-');
    final found = <String>[];

    void addCode(String raw) {
      final normalized = raw
          .replaceAll(RegExp(r'[—–－]'), '-')
          .replaceAll(RegExp(r'[ \t]+'), '')
          .trim()
          .toUpperCase();
      if (_isValidPickupCode(normalized) && !found.contains(normalized)) {
        found.add(normalized);
      }
    }

    // 1. Explicit keyword-led codes
    for (final m in _explicitCodeRegex.allMatches(text)) {
      final value = m.group(1);
      if (value != null) addCode(value);
    }

    // 1b. Code placed directly above "取件码" label or inline before "为您的取件码"
    for (final m in _codeBeforeKeywordRegex.allMatches(text)) {
      final value = m.group(1) ?? m.group(2);
      if (value != null) addCode(value);
    }

    // 2. Also capture additional comma/pause separated codes right after the first explicit match
    // e.g. 取件码12-3-405、12-3-406 or 请用02A006/02A007
    final multiCodeRegex = RegExp(
      r'(?:取件码|提货码|取货码|开柜码|自提码|货架号|请凭|请用|凭)\s*[为是:：]?\s*([A-Za-z0-9-]+(?:[、,，/]\s*[A-Za-z0-9-]+)+)',
    );
    for (final m in multiCodeRegex.allMatches(text)) {
      final group = m.group(1) ?? '';
      for (final part in group.split(RegExp(r'[、,，/\s]+'))) {
        if (part.isNotEmpty) addCode(part);
      }
    }

    // 3. Hyphenated shelf codes anywhere in text (very reliable for OCR screenshots)
    if (allowBareShelfCodes) {
      for (final m in _shelfCodeRegex.allMatches(text)) {
        final value = m.group(1);
        if (value != null && !_looksLikeDateOrPhone(value, text, m.start, m.end)) {
          addCode(value);
        }
      }
    }

    return found;
  }

  static bool _isValidPickupCode(String code) {
    if (code.length < 3 || code.length > 16) return false;
    // Reject obvious phone numbers or years
    if (RegExp(r'^1[3-9]\d{9}$').hasMatch(code)) return false;
    if (RegExp(r'^20\d{2}$').hasMatch(code)) return false;
    return RegExp(r'^[A-Z0-9-]+$').hasMatch(code);
  }

  static bool _looksLikeDateOrPhone(
    String value,
    String fullText,
    int start,
    int end,
  ) {
    // Reject YYYY-MM-DD or YYYY-MM date patterns like 2026-11-24
    if (RegExp(r'^20\d{2}-\d{1,2}(?:-\d{1,2})?$').hasMatch(value)) return true;
    // Reject 400-xxx-xxxx, 800-xxx, landline 010-xxxx, or mobile 138-1234-5678
    if (RegExp(r'^(?:400|800|0\d{2,3})-').hasMatch(value)) return true;
    if (RegExp(r'^1[3-9]\d-\d{4}-\d{4}$').hasMatch(value)) return true;

    // Reject MM-DD dates like "11-24 10:30" or "08-15"
    final mmdd = RegExp(r'^(\d{1,2})-(\d{1,2})$').firstMatch(value);
    if (mmdd != null) {
      final m = int.tryParse(mmdd.group(1)!) ?? 0;
      final d = int.tryParse(mmdd.group(2)!) ?? 0;
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        final suffixEnd = (end + 10).clamp(0, fullText.length);
        final suffix = fullText.substring(end, suffixEnd);
        if (RegExp(r'^\s+\d{1,2}:\d{2}').hasMatch(suffix)) return true;
        // Zero-padded MM-DD like 08-15 or 11-05 is almost always a date
        if (mmdd.group(1)!.startsWith('0') || mmdd.group(2)!.startsWith('0')) {
          return true;
        }
      }
    }

    // Check if immediately preceded by size/weight/date/time labels or followed by unit
    final prefixStart = (start - 16).clamp(0, fullText.length);
    final prefix = fullText.substring(prefixStart, start);
    if (_nonPickupPrefixRegex.hasMatch(prefix)) return true;

    final suffixEnd = (end + 8).clamp(0, fullText.length);
    final suffix = fullText.substring(end, suffixEnd);
    if (_nonPickupUnitSuffixRegex.hasMatch(suffix)) return true;
    return false;
  }

  static String _extractStation(String text) {
    final locMatch = _activeStationLocationRegex.firstMatch(text);
    if (locMatch != null) {
      final candidate = _cleanStationName(locMatch.group(1) ?? '');
      if (candidate.length >= 2) return candidate;
    }

    final genericMatch = _activeGenericStationRegex.firstMatch(text);
    if (genericMatch != null) {
      final candidate = _cleanStationName(genericMatch.group(1) ?? '');
      if (candidate.length >= 2) return candidate;
    }

    final bracketMatch = _bracketBrandRegex.firstMatch(text);
    if (bracketMatch != null) {
      final brand = (bracketMatch.group(1) ?? '').trim();
      if (brand.isNotEmpty) return brand;
    }

    if (text.contains('菜鸟')) return '菜鸟驿站';
    if (text.contains('丰巢')) return '丰巢快递柜';
    if (text.contains('兔喜')) return '兔喜生活';
    if (text.contains('妈妈驿站')) return '妈妈驿站';
    if (text.contains('多多')) return '多多驿站';
    return '默认驿站';
  }

  static String _cleanStationName(String raw) {
    var name = raw.trim();
    // Strip leading filler phrases
    name = name.replaceFirst(
      RegExp(r'^(?:您的包裹|包裹|快递|快件|请到|请前往|前往|位于|在|地址[:：]?|取件地址[:：]?)'),
      '',
    );
    // Strip parenthesized notes like (近东门), （24小时）, 【代收】
    name = name.replaceAll(RegExp(r'[（(【\[][^）)】\]]{1,16}[）)】\]]'), '');
    // Strip trailing punctuation / ellipsis / arrows
    name = name.replaceAll(RegExp(r'[-—_:：,，。.\s…>›»]+$'), '').trim();

    // If address contains comma-separated segments (e.g. "长青南街18号，理工东门，沈理东门驿站超市"),
    // prefer the trailing segment that contains an explicit station keyword.
    final stationKw = RegExp(
      r'(?:菜鸟驿站|妈妈驿站|兔喜生活|兔喜快递超市|多多驿站|丰巢快递柜|丰巢智能柜|丰巢柜|丰巢|速递易|近邻宝|京东派|快递服务中心|驿站超市|快递超市|快递柜|快递站|快递点|小邮局|熊猫快收|快宝驿站|驿站|代收点)',
    );
    if (name.contains('，') || name.contains(',')) {
      final parts = name
          .split(RegExp(r'[，,]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      for (var i = parts.length - 1; i >= 0; i--) {
        if (stationKw.hasMatch(parts[i]) && parts[i].length >= 3) {
          name = parts[i];
          break;
        }
      }
    }

    // If the station string repeats the station keyword twice back-to-back
    // (e.g. "沈理驿站超市沈理东门驿站超市"), keep the last complete station phrase
    // (ignoring trailing generic suffixes like "-代收点").
    final kwMatches = stationKw.allMatches(name).toList();
    if (kwMatches.length >= 2) {
      final prevEnd = kwMatches[kwMatches.length - 2].end;
      final tail = name
          .substring(prevEnd)
          .replaceFirst(RegExp(r'^[-—_:：\s]+'), '')
          .trim();
      final isGenericOnly = RegExp(
        r'^(?:代收点|门店|自提点|服务站|驿站|快递柜|驿站超市|快递超市)$',
      ).hasMatch(tail);
      if (tail.length >= 4 && !isGenericOnly && stationKw.hasMatch(tail)) {
        name = tail;
      }
    }

    // Strip verbose province / city / district / street prefixes
    name = name.replaceFirst(
      RegExp(
        r'^(?:[\u4e00-\u9fa5]{2,5}(?:省|自治区))?(?:[\u4e00-\u9fa5]{2,6}市)?(?:[\u4e00-\u9fa5]{2,6}(?:区|县|旗))?(?:[\u4e00-\u9fa5]{2,8}(?:街道|镇|乡))?',
      ),
      '',
    );
    name = name.replaceAll(RegExp(r'[-—_:：,，。.\s…>›»]+$'), '').trim();
    if (name.length > 18) {
      name = name.substring(name.length - 18);
    }
    return name.trim();
  }

  /// Normalizes station names across platforms for smarter grouping (e.g. removing
  /// punctuation/spaces/generic suffixes like "代收点" / "门店").
  static String normalizeStationKey(String stationName) {
    final cleaned = _cleanStationName(stationName)
        .replaceAll(RegExp(r'[\s\-_·•/\\]'), '')
        .replaceAll(RegExp(r'(?:代收点|门店|自提点|服务站)$'), '');
    return cleaned.isEmpty ? '默认驿站' : cleaned;
  }

  static PickupSource _detectSource(String text, PickupSource fallback) {
    if (text.contains('淘宝') || text.contains('天猫') || text.contains('菜鸟')) {
      return PickupSource.taobao;
    }
    if (text.contains('拼多多') || text.contains('多多驿站') || text.contains('多多买菜')) {
      return PickupSource.pinduoduo;
    }
    return fallback;
  }

  static String _extractTrackingNumber(String text) {
    final explicit = _explicitTrackingRegex.firstMatch(text);
    if (explicit != null) {
      return (explicit.group(1) ?? '').toUpperCase();
    }
    final carrier = _carrierTrackingRegex.firstMatch(text);
    if (carrier != null) {
      return (carrier.group(1) ?? '').toUpperCase();
    }
    return '';
  }

  static String _extractItemNote(String text) {
    final match = _itemNoteRegex.firstMatch(text);
    if (match != null) {
      return (match.group(1) ?? '').trim();
    }
    return '';
  }
}
