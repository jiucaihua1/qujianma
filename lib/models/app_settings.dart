class AppSettings {
  static const String defaultRuleUpdateUrl =
      'https://raw.githubusercontent.com/jiucaihua1/qujianma/main/rules/parser_rules.json';

  const AppSettings({
    this.defaultTabIndex = 0,
    this.autoDetectClipboard = true,
    this.autoDetectScreenshotHint = false,
    this.autoCleanDays = 7,
    this.showStationSuggestionBanner = true,
    this.ruleUpdateUrl = defaultRuleUpdateUrl,
    this.lastRuleSyncAt = '',
    this.dailyReminderEnabled = false,
    this.dailyReminderHour = 18,
    this.dailyReminderMinute = 30,
  });

  /// 0 = 首页（身份码页）, 1 = 取件一览页
  final int defaultTabIndex;
  final bool autoDetectClipboard;
  final bool autoDetectScreenshotHint;

  /// 0 表示不自动清理，7 表示清理 7 天前已取记录，30 表示 30 天
  final int autoCleanDays;

  /// 是否在取件一览页顶部展示驿站整理建议横幅
  final bool showStationSuggestionBanner;

  /// 远程识别规则 JSON 文件地址（留空则仅使用内置规则）
  final String ruleUpdateUrl;

  /// 最近一次成功同步规则的时间
  final String lastRuleSyncAt;

  /// 是否开启每日定时未取包裹提醒
  final bool dailyReminderEnabled;

  /// 每日提醒时间（小时 0-23，分钟 0-59）
  final int dailyReminderHour;
  final int dailyReminderMinute;

  AppSettings copyWith({
    int? defaultTabIndex,
    bool? autoDetectClipboard,
    bool? autoDetectScreenshotHint,
    int? autoCleanDays,
    bool? showStationSuggestionBanner,
    String? ruleUpdateUrl,
    String? lastRuleSyncAt,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
  }) {
    return AppSettings(
      defaultTabIndex: defaultTabIndex ?? this.defaultTabIndex,
      autoDetectClipboard: autoDetectClipboard ?? this.autoDetectClipboard,
      autoDetectScreenshotHint:
          autoDetectScreenshotHint ?? this.autoDetectScreenshotHint,
      autoCleanDays: autoCleanDays ?? this.autoCleanDays,
      showStationSuggestionBanner:
          showStationSuggestionBanner ?? this.showStationSuggestionBanner,
      ruleUpdateUrl: ruleUpdateUrl ?? this.ruleUpdateUrl,
      lastRuleSyncAt: lastRuleSyncAt ?? this.lastRuleSyncAt,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
    );
  }
}
