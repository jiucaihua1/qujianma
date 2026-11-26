import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/identity_shortcut.dart';
import '../models/parser_rule_bundle.dart';
import '../models/station_rule.dart';

class SettingsService {
  static const _keyDefaultTab = 'default_tab_index';
  static const _keyAutoClipboard = 'auto_detect_clipboard';
  static const _keyAutoScreenshotHint = 'auto_detect_screenshot_hint';
  static const _keyAutoCleanDays = 'auto_clean_days';
  static const _keyShowStationBanner = 'show_station_suggestion_banner';
  static const _keyRuleUpdateUrl = 'rule_update_url';
  static const _keyLastRuleSyncAt = 'last_rule_sync_at';
  static const _keyDailyReminderEnabled = 'daily_reminder_enabled';
  static const _keyDailyReminderHour = 'daily_reminder_hour';
  static const _keyDailyReminderMinute = 'daily_reminder_minute';
  static const _keyShortcuts = 'identity_shortcuts_v3';
  static const _keyStationRules = 'station_rules_v1';
  static const _keyDismissedSuggestions = 'dismissed_station_suggestions_v1';
  static const _keyParserRuleBundle = 'parser_rules_bundle_v1';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      defaultTabIndex: prefs.getInt(_keyDefaultTab) ?? 0,
      autoDetectClipboard: prefs.getBool(_keyAutoClipboard) ?? true,
      autoDetectScreenshotHint: prefs.getBool(_keyAutoScreenshotHint) ?? false,
      autoCleanDays: prefs.getInt(_keyAutoCleanDays) ?? 7,
      showStationSuggestionBanner:
          prefs.getBool(_keyShowStationBanner) ?? true,
      ruleUpdateUrl:
          (prefs.getString(_keyRuleUpdateUrl)?.trim().isNotEmpty ?? false)
              ? prefs.getString(_keyRuleUpdateUrl)!
              : AppSettings.defaultRuleUpdateUrl,
      lastRuleSyncAt: prefs.getString(_keyLastRuleSyncAt) ?? '',
      dailyReminderEnabled: prefs.getBool(_keyDailyReminderEnabled) ?? false,
      dailyReminderHour: prefs.getInt(_keyDailyReminderHour) ?? 18,
      dailyReminderMinute: prefs.getInt(_keyDailyReminderMinute) ?? 30,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDefaultTab, settings.defaultTabIndex);
    await prefs.setBool(_keyAutoClipboard, settings.autoDetectClipboard);
    await prefs.setBool(
      _keyAutoScreenshotHint,
      settings.autoDetectScreenshotHint,
    );
    await prefs.setInt(_keyAutoCleanDays, settings.autoCleanDays);
    await prefs.setBool(
      _keyShowStationBanner,
      settings.showStationSuggestionBanner,
    );
    await prefs.setString(_keyRuleUpdateUrl, settings.ruleUpdateUrl);
    await prefs.setString(_keyLastRuleSyncAt, settings.lastRuleSyncAt);
    await prefs.setBool(
      _keyDailyReminderEnabled,
      settings.dailyReminderEnabled,
    );
    await prefs.setInt(_keyDailyReminderHour, settings.dailyReminderHour);
    await prefs.setInt(_keyDailyReminderMinute, settings.dailyReminderMinute);
  }

  Future<ParserRuleBundle> loadParserRuleBundle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyParserRuleBundle);
    if (raw == null || raw.isEmpty) {
      return ParserRuleBundle.defaults();
    }
    try {
      return ParserRuleBundle.decode(raw);
    } catch (_) {
      return ParserRuleBundle.defaults();
    }
  }

  Future<void> saveParserRuleBundle(ParserRuleBundle bundle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyParserRuleBundle, bundle.encode());
  }

  Future<void> clearParserRuleBundle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyParserRuleBundle);
  }

  Future<List<StationRule>> loadStationRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyStationRules);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return StationRule.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveStationRules(List<StationRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = [
      for (var i = 0; i < rules.length; i++) rules[i].copyWith(order: i),
    ];
    await prefs.setString(_keyStationRules, StationRule.encodeList(normalized));
  }

  Future<Set<String>> loadDismissedSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyDismissedSuggestions);
    return list == null ? <String>{} : list.toSet();
  }

  Future<void> saveDismissedSuggestions(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyDismissedSuggestions, ids.toList());
  }

  Future<List<IdentityShortcut>> loadShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyShortcuts);
    if (raw == null || raw.isEmpty) {
      return IdentityShortcut.defaults();
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .whereType<Map<String, dynamic>>()
          .map(IdentityShortcut.fromJson)
          .map(_migrateLegacyShortcut)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return parsed.isEmpty ? IdentityShortcut.defaults() : parsed;
    } catch (_) {
      return IdentityShortcut.defaults();
    }
  }

  IdentityShortcut _migrateLegacyShortcut(IdentityShortcut item) {
    if (item.id == 'cainiao' &&
        (item.schemeUrl == 'cainiao://cainiao.com/idcode' ||
            item.schemeUrl == 'guoguo://go/quick_pick_qrcode' ||
            item.schemeUrl == 'guoguo://go/station_code')) {
      return item.copyWith(
        schemeUrl: 'guoguo://go/station_code?entrance=icon',
        fallbackSchemeUrl: 'guoguo://go/allpackage',
      );
    }
    if (item.id == 'taobao' &&
        (item.schemeUrl == 'taobao://m.taobao.com/tbopen/index.html' ||
            item.schemeUrl == 'taobao://m.taobao.com/go/mytaobao/myexpress' ||
            item.schemeUrl ==
                'taobao://taobao.trade.order/orderlist.htm?tabCode=waitConfirm' ||
            item.schemeUrl ==
                'taobao://market.m.taobao.com/app/cn-yz/multi-activity/authCode.html')) {
      return item.copyWith(
        name: '淘宝身份码',
        subtitle: '淘宝菜鸟驿站亮码',
        schemeUrl:
            'taobao://pages-fast.m.taobao.com/wow/z/uniapp/1100333/last-mile-fe/m-end-school-tab/home?x-ssr=true&ssr=true&forceThemis=true&skeleton=true',
        fallbackSchemeUrl: 'taobao://',
      );
    }
    if (item.id == 'pinduoduo' &&
        (item.schemeUrl == 'pinduoduo://com.xunmeng.pinduoduo/' ||
            item.schemeUrl.contains('psnl_goods_help.html'))) {
      return item.copyWith(
        name: '拼多多身份码',
        subtitle: '多多驿站一键亮码',
        schemeUrl:
            'pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE&entry_source=11',
        fallbackSchemeUrl:
            'pinduoduo://com.xunmeng.pinduoduo/psnl_goods_help.html?_t_module_name=assistant_search&tab_id=400&tab_type=1',
      );
    }
    return item;
  }

  Future<void> saveShortcuts(List<IdentityShortcut> shortcuts) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = [
      for (var i = 0; i < shortcuts.length; i++) shortcuts[i].copyWith(order: i),
    ];
    await prefs.setString(
      _keyShortcuts,
      jsonEncode(normalized.map((e) => e.toJson()).toList()),
    );
  }
}
