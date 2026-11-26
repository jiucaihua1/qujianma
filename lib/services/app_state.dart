import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/identity_shortcut.dart';
import '../models/parser_rule_bundle.dart';
import '../models/pickup_item.dart';
import '../models/station_rule.dart';
import 'database_service.dart';
import 'pickup_parser.dart';
import 'quick_tile_service.dart';
import 'rule_sync_service.dart';
import 'settings_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    DatabaseService? db,
    SettingsService? settingsService,
    RuleSyncService? ruleSyncService,
  })  : _db = db ?? DatabaseService.instance,
        _settingsService = settingsService ?? SettingsService(),
        _ruleSyncService = ruleSyncService ?? const RuleSyncService();

  final DatabaseService _db;
  final SettingsService _settingsService;
  final RuleSyncService _ruleSyncService;

  bool _initialized = false;
  List<PickupItem> _pendingItems = [];
  List<PickupItem> _historyItems = [];
  AppSettings _settings = const AppSettings();
  List<IdentityShortcut> _shortcuts = IdentityShortcut.defaults();
  List<StationRule> _stationRules = [];
  Set<String> _dismissedSuggestionIds = {};
  ParserRuleBundle _ruleBundle = ParserRuleBundle.defaults();

  String? _lastDismissedClipboardText;
  ParsedPickupCandidate? _clipboardSuggestion;

  bool get initialized => _initialized;
  List<PickupItem> get pendingItems => List.unmodifiable(_pendingItems);
  List<PickupItem> get historyItems => List.unmodifiable(_historyItems);
  AppSettings get settings => _settings;
  List<IdentityShortcut> get shortcuts => List.unmodifiable(_shortcuts);
  List<IdentityShortcut> get visibleShortcuts =>
      _shortcuts.where((s) => s.visible).toList();
  List<StationRule> get stationRules => List.unmodifiable(_stationRules);
  List<StationRule> get enabledStationRules =>
      _stationRules.where((r) => r.enabled).toList();
  ParserRuleBundle get ruleBundle => _ruleBundle;
  int get pendingCount => _pendingItems.length;
  ParsedPickupCandidate? get clipboardSuggestion => _clipboardSuggestion;

  /// Groups pending items by normalized station name, also merging stations where
  /// one normalized name cleanly contains another (e.g. long address + short station name).
  Map<String, List<PickupItem>> get groupedPendingByStation {
    final keyToDisplay = <String, String>{};
    final keyToItems = <String, List<PickupItem>>{};
    for (final item in _pendingItems) {
      final rawStation =
          item.stationName.trim().isEmpty ? '默认驿站' : item.stationName.trim();
      final key = PickupParser.normalizeStationKey(rawStation);

      String? matchedKey;
      if (keyToItems.containsKey(key)) {
        matchedKey = key;
      } else if (key.length >= 4 && key != '默认驿站') {
        for (final existingKey in keyToItems.keys) {
          if (existingKey.length >= 4 &&
              existingKey != '默认驿站' &&
              (existingKey.contains(key) || key.contains(existingKey))) {
            matchedKey = existingKey;
            break;
          }
        }
      }

      if (matchedKey != null) {
        keyToItems[matchedKey]!.add(item);
        // Prefer the shorter, cleaner display name for the group header
        final currentDisplay = keyToDisplay[matchedKey]!;
        if (rawStation.length < currentDisplay.length && rawStation.length >= 3) {
          keyToDisplay[matchedKey] = rawStation;
        }
      } else {
        keyToDisplay[key] = rawStation;
        keyToItems[key] = [item];
      }
    }
    final entries = keyToItems.entries
        .map((e) => MapEntry(keyToDisplay[e.key]!, e.value))
        .toList()
      ..sort((a, b) {
        final countCmp = b.value.length.compareTo(a.value.length);
        if (countCmp != 0) return countCmp;
        return b.value.first.createdAt.compareTo(a.value.first.createdAt);
      });
    return Map<String, List<PickupItem>>.fromEntries(entries);
  }

  List<String> get knownStations {
    final set = <String>{};
    for (final rule in _stationRules) {
      if (rule.enabled && rule.standardName.trim().isNotEmpty) {
        set.add(rule.standardName.trim());
      }
    }
    for (final item in _pendingItems) {
      if (item.stationName.trim().isNotEmpty) set.add(item.stationName.trim());
    }
    for (final item in _historyItems) {
      if (item.stationName.trim().isNotEmpty) set.add(item.stationName.trim());
    }
    return set.toList();
  }

  Future<void> init() async {
    _settings = await _settingsService.loadSettings();
    _shortcuts = await _settingsService.loadShortcuts();
    _stationRules = await _settingsService.loadStationRules();
    _dismissedSuggestionIds = await _settingsService.loadDismissedSuggestions();
    _ruleBundle = await _settingsService.loadParserRuleBundle();
    PickupParser.setDynamicBundle(_ruleBundle);
    if (_settings.autoCleanDays > 0) {
      await _db.cleanOldPickedUpItems(_settings.autoCleanDays);
    }
    await reloadItems();
    await QuickTileService.scheduleDailyReminder(
      enabled: _settings.dailyReminderEnabled,
      hour: _settings.dailyReminderHour,
      minute: _settings.dailyReminderMinute,
    );
    _initialized = true;
    notifyListeners();

    if (_settings.ruleUpdateUrl.trim().isNotEmpty) {
      // Quietly refresh remote rules in the background without blocking startup
      Future<void>(() async {
        try {
          await syncRuleBundle(silent: true);
        } catch (_) {}
      });
    }
  }

  Future<void> reloadItems() async {
    _pendingItems = await _db.getPendingItems();
    _historyItems = await _db.getHistoryItems();
    notifyListeners();
  }

  Future<PickupItem> addPickupItem({
    required String code,
    required String stationName,
    PickupSource source = PickupSource.manual,
    ItemCategory? itemCategory,
    String itemNote = '',
    String trackingNumber = '',
    String rawText = '',
    bool deduplicate = true,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    final rawStation =
        stationName.trim().isEmpty ? '默认驿站' : stationName.trim();
    final normalizedStation = source == PickupSource.manual
        ? rawStation
        : PickupParser.resolveStationName(
            rawText: rawText,
            defaultStation: rawStation,
            rules: _stationRules,
          );
    if (deduplicate) {
      for (final existing in _pendingItems) {
        if (existing.code.trim().toUpperCase() == normalizedCode) {
          return existing;
        }
      }
    }
    final item = PickupItem(
      code: normalizedCode,
      stationName: normalizedStation,
      source: source,
      itemCategory: itemCategory,
      itemNote: itemNote.trim(),
      trackingNumber: trackingNumber.trim(),
      rawText: rawText.trim(),
      createdAt: DateTime.now(),
    );
    final inserted = await _db.insertItem(item);
    await reloadItems();
    return inserted;
  }

  Future<void> updatePickupItem(PickupItem item) async {
    await _db.updateItem(item);
    await reloadItems();
  }

  Future<void> markPickedUp(PickupItem item) async {
    if (item.id == null) return;
    await _db.markPickedUp(item.id!, pickedUp: true);
    await reloadItems();
  }

  Future<void> restoreItem(PickupItem item) async {
    if (item.id == null) return;
    await _db.markPickedUp(item.id!, pickedUp: false);
    await reloadItems();
  }

  Future<void> deleteItem(PickupItem item) async {
    if (item.id == null) return;
    await _db.deleteItem(item.id!);
    await reloadItems();
  }

  Future<void> updateSettings(AppSettings next) async {
    final reminderChanged =
        next.dailyReminderEnabled != _settings.dailyReminderEnabled ||
            next.dailyReminderHour != _settings.dailyReminderHour ||
            next.dailyReminderMinute != _settings.dailyReminderMinute;
    _settings = next;
    notifyListeners();
    await _settingsService.saveSettings(next);
    if (reminderChanged) {
      await QuickTileService.scheduleDailyReminder(
        enabled: next.dailyReminderEnabled,
        hour: next.dailyReminderHour,
        minute: next.dailyReminderMinute,
      );
    }
    if (next.autoCleanDays > 0) {
      await _db.cleanOldPickedUpItems(next.autoCleanDays);
      await reloadItems();
    }
  }

  Future<void> updateShortcuts(List<IdentityShortcut> next) async {
    _shortcuts = [
      for (var i = 0; i < next.length; i++) next[i].copyWith(order: i),
    ];
    await _settingsService.saveShortcuts(_shortcuts);
    notifyListeners();
  }

  Future<void> resetShortcutsToDefault() async {
    await updateShortcuts(IdentityShortcut.defaults());
  }

  void inspectClipboardText(String? text) {
    if (!_settings.autoDetectClipboard) return;
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == _lastDismissedClipboardText) return;
    if (!PickupParser.looksLikePickupText(trimmed)) return;

    final candidate = PickupParser.parseSingle(
      trimmed,
      defaultSource: PickupSource.sms,
      stationRules: _stationRules,
    );
    if (candidate == null) return;

    // Avoid suggesting a code that is already pending
    final alreadyExists = _pendingItems.any(
      (item) => item.code.toUpperCase() == candidate.code.toUpperCase(),
    );
    if (alreadyExists) return;

    _clipboardSuggestion = candidate;
    notifyListeners();
  }

  void dismissClipboardSuggestion() {
    if (_clipboardSuggestion != null) {
      _lastDismissedClipboardText = _clipboardSuggestion!.rawText;
      _clipboardSuggestion = null;
      notifyListeners();
    }
  }

  Future<void> saveStationRules(List<StationRule> next) async {
    _stationRules = [
      for (var i = 0; i < next.length; i++) next[i].copyWith(order: i),
    ];
    await _settingsService.saveStationRules(_stationRules);
    notifyListeners();
  }

  Future<void> upsertStationRule(StationRule rule) async {
    final trimmedName = rule.standardName.trim();
    if (trimmedName.isEmpty) return;
    final cleanedRule = rule.copyWith(standardName: trimmedName);
    final idx = _stationRules.indexWhere((r) => r.id == cleanedRule.id);
    final next = List<StationRule>.from(_stationRules);
    if (idx >= 0) {
      next[idx] = cleanedRule;
    } else {
      next.add(cleanedRule.copyWith(order: next.length));
    }
    await saveStationRules(next);
  }

  Future<void> deleteStationRule(String id) async {
    final next = _stationRules.where((r) => r.id != id).toList();
    await saveStationRules(next);
  }

  /// Learns a mapping from [alias] (or raw keyword) to [targetStation].
  Future<void> learnStationAlias({
    required String targetStation,
    String alias = '',
  }) async {
    final target = targetStation.trim();
    final trimmedAlias = alias.trim();
    if (target.isEmpty || target == '默认驿站') return;

    final existingIdx = _stationRules.indexWhere(
      (r) => r.standardName.trim() == target,
    );
    final shouldAddAlias = trimmedAlias.isNotEmpty &&
        trimmedAlias != '默认驿站' &&
        trimmedAlias != target;

    if (existingIdx >= 0) {
      final existing = _stationRules[existingIdx];
      if (!shouldAddAlias || existing.allKeywords.contains(trimmedAlias)) {
        if (!existing.enabled) {
          await upsertStationRule(existing.copyWith(enabled: true));
        }
        return;
      }
      await upsertStationRule(
        existing.copyWith(
          enabled: true,
          aliases: [...existing.aliases, trimmedAlias],
        ),
      );
    } else {
      await upsertStationRule(
        StationRule(
          id: 'rule_${DateTime.now().microsecondsSinceEpoch}',
          standardName: target,
          aliases: shouldAddAlias ? [trimmedAlias] : const [],
          enabled: true,
          order: _stationRules.length,
        ),
      );
    }
  }

  /// Applies current station rules to all pending items and returns how many
  /// items were updated.
  Future<int> applyStationRulesToPending() async {
    if (_stationRules.isEmpty) return 0;
    var updatedCount = 0;
    for (final item in _pendingItems) {
      final resolved = PickupParser.resolveStationName(
        rawText: item.rawText,
        defaultStation: item.stationName,
        rules: _stationRules,
      );
      if (resolved != item.stationName) {
        await _db.updateItem(item.copyWith(stationName: resolved));
        updatedCount++;
      }
    }
    if (updatedCount > 0) {
      await reloadItems();
    }
    return updatedCount;
  }

  Future<int> renameStationInPending({
    required String fromStation,
    required String toStation,
  }) async {
    final from = fromStation.trim();
    final to = toStation.trim();
    if (from.isEmpty || to.isEmpty || from == to) return 0;
    var updatedCount = 0;
    for (final item in _pendingItems) {
      if (item.stationName.trim() == from) {
        await _db.updateItem(item.copyWith(stationName: to));
        updatedCount++;
      }
    }
    if (updatedCount > 0) {
      await reloadItems();
    }
    return updatedCount;
  }

  static String _stripStationGenericWords(String name) {
    return name
        .replaceAll(
          RegExp(
            r'(?:菜鸟校园驿站|菜鸟驿站|圆通妈妈驿站|妈妈驿站|兔喜生活|兔喜快递超市|兔喜驿站|多多驿站|多多买菜自提点|丰巢快递柜|丰巢智能柜|丰巢柜|丰巢|中邮速递易|速递易|近邻宝智能柜|近邻宝快递柜|近邻宝|京东派|快递服务中心|驿站超市|快递超市|快递柜|智能柜|自提柜|快递站|快递点|驿站|代收点|自提点|门店|服务站|菜鸟|兔喜|多多)',
          ),
          '',
        )
        .replaceAll(RegExp(r'[\s\-_·•/\\()（）【】\[\]]'), '');
  }

  static bool _hasMeaningfulOverlap(String a, String b) {
    final coreA = _stripStationGenericWords(a);
    final coreB = _stripStationGenericWords(b);
    if (coreA.length < 2 || coreB.length < 2) return false;
    for (var i = 0; i <= coreA.length - 2; i++) {
      final sub = coreA.substring(i, i + 2);
      if (coreB.contains(sub)) return true;
    }
    return false;
  }

  /// Computes local station organization suggestions from pending + history items:
  /// 1) Similar uncovered station names that look like the same physical place.
  /// 2) Uncovered station names appearing >= 3 times that can be promoted.
  List<StationSuggestion> get stationSuggestions {
    final counts = <String, int>{};
    for (final item in [..._pendingItems, ..._historyItems]) {
      final name = item.stationName.trim();
      if (name.isEmpty || name == '默认驿站') continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    if (counts.isEmpty) return const [];

    final uncovered = counts.keys.where((name) {
      final exactRule = _stationRules.any(
        (r) => r.enabled && r.standardName.trim() == name,
      );
      if (exactRule) return false;
      return PickupParser.matchCustomStation(name, _stationRules) == null;
    }).toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));

    final suggestions = <StationSuggestion>[];
    final usedInMerge = <String>{};

    // 1. Similar station merge suggestions
    for (var i = 0; i < uncovered.length; i++) {
      final a = uncovered[i];
      if (usedInMerge.contains(a)) continue;
      for (var j = i + 1; j < uncovered.length; j++) {
        final b = uncovered[j];
        if (usedInMerge.contains(b)) continue;
        if (!_hasMeaningfulOverlap(a, b)) continue;

        final pair = [a, b]..sort();
        final id = 'merge:${pair.join('|')}';
        if (_dismissedSuggestionIds.contains(id)) continue;

        final countA = counts[a] ?? 0;
        final countB = counts[b] ?? 0;
        final primary = (countA > countB || (countA == countB && a.length <= b.length))
            ? a
            : b;
        final secondary = primary == a ? b : a;
        usedInMerge.add(a);
        usedInMerge.add(b);
        suggestions.add(
          StationSuggestion(
            id: id,
            type: StationSuggestionType.mergeSimilar,
            primaryName: primary,
            secondaryNames: [secondary],
            occurrenceCount: countA + countB,
          ),
        );
        break;
      }
    }

    // 2. High-frequency station promotion suggestions (>= 3 occurrences)
    for (final name in uncovered) {
      if (usedInMerge.contains(name)) continue;
      final count = counts[name] ?? 0;
      if (count < 3) continue;
      final id = 'promote:$name';
      if (_dismissedSuggestionIds.contains(id)) continue;
      suggestions.add(
        StationSuggestion(
          id: id,
          type: StationSuggestionType.promoteFrequent,
          primaryName: name,
          occurrenceCount: count,
        ),
      );
    }

    return suggestions.take(5).toList();
  }

  Future<void> acceptSuggestion(
    StationSuggestion suggestion, {
    String? chosenPrimaryName,
  }) async {
    final primary = (chosenPrimaryName ?? suggestion.primaryName).trim();
    if (primary.isEmpty) return;

    if (suggestion.type == StationSuggestionType.promoteFrequent) {
      await learnStationAlias(targetStation: primary);
    } else {
      final allNames = <String>{
        suggestion.primaryName,
        ...suggestion.secondaryNames,
      };
      await learnStationAlias(targetStation: primary);
      for (final other in allNames) {
        if (other != primary) {
          await learnStationAlias(targetStation: primary, alias: other);
          await renameStationInPending(fromStation: other, toStation: primary);
        }
      }
    }
    await dismissSuggestion(suggestion.id);
  }

  Future<void> dismissSuggestion(String suggestionId) async {
    if (_dismissedSuggestionIds.add(suggestionId)) {
      await _settingsService.saveDismissedSuggestions(
        _dismissedSuggestionIds,
      );
      notifyListeners();
    }
  }

  Future<void> resetDismissedSuggestions() async {
    _dismissedSuggestionIds.clear();
    await _settingsService.saveDismissedSuggestions(_dismissedSuggestionIds);
    notifyListeners();
  }

  Future<ParserRuleBundle> syncRuleBundle({
    String? url,
    bool silent = false,
  }) async {
    final targetUrl = (url ?? _settings.ruleUpdateUrl).trim();
    final result = await _ruleSyncService.fetchFromUrl(targetUrl);
    _ruleBundle = result.bundle;
    PickupParser.setDynamicBundle(_ruleBundle);
    await _settingsService.saveParserRuleBundle(_ruleBundle);
    _settings = _settings.copyWith(
      ruleUpdateUrl: targetUrl,
      lastRuleSyncAt: result.syncedAt,
    );
    await _settingsService.saveSettings(_settings);
    if (!silent || _initialized) {
      notifyListeners();
    }
    return _ruleBundle;
  }

  Future<void> resetRuleBundleToDefault() async {
    _ruleBundle = ParserRuleBundle.defaults();
    PickupParser.setDynamicBundle(_ruleBundle);
    await _settingsService.clearParserRuleBundle();
    _settings = _settings.copyWith(lastRuleSyncAt: '');
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }
}
