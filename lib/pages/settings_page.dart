import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/identity_shortcut.dart';
import '../services/app_state.dart';
import '../services/app_update_service.dart';
import '../services/quick_tile_service.dart';
import '../theme/app_theme.dart';
import 'station_manage_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final settings = appState.settings;
    final historyCount = appState.historyItems.length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          const Text(
            '设置',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '个性化启动偏好、跳转链接维护与本地隐私说明',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),

          // Section 0: Quick Settings Tile one-tap screenshot OCR
          const _SectionLabel('控制中心一键截屏识码'),
          const SizedBox(height: 8),
          const _QuickTileGuideCard(),

          const SizedBox(height: 20),

          // Section 1: Launch & Smart Recognition
          const _SectionLabel('启动与智能识别'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '默认启动页',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '选择打开 App 时优先显示的页面',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment<int>(
                            value: 0,
                            label: Text('身份码页'),
                            icon: Icon(Icons.qr_code_2_rounded, size: 18),
                          ),
                          ButtonSegment<int>(
                            value: 1,
                            label: Text('取件一览'),
                            icon: Icon(Icons.inventory_2_outlined, size: 18),
                          ),
                        ],
                        selected: {settings.defaultTabIndex},
                        onSelectionChanged: (selection) {
                          appState.updateSettings(
                            settings.copyWith(defaultTabIndex: selection.first),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.cardBorder),
              SwitchListTile.adaptive(
                value: settings.autoDetectClipboard,
                title: const Text(
                  '打开 App 自动检测剪贴板',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  '切回应用时若剪贴板包含取件短信，弹出快捷入库卡片',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                onChanged: (v) {
                  appState.updateSettings(
                    settings.copyWith(autoDetectClipboard: v),
                  );
                },
              ),
              const Divider(height: 1, color: AppTheme.cardBorder),
              SwitchListTile.adaptive(
                value: settings.autoDetectScreenshotHint,
                title: const Text(
                  '待取件页显示截图识别快捷入口',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  '主动选图触发本地 OCR，不申请后台监听或无障碍权限',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                onChanged: (v) {
                  appState.updateSettings(
                    settings.copyWith(autoDetectScreenshotHint: v),
                  );
                },
              ),
              const Divider(height: 1, color: AppTheme.cardBorder),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.store_mall_directory_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  '常用驿站与识别规则',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  appState.stationSuggestions.isNotEmpty
                      ? '已配置 ${appState.enabledStationRules.length} 个常用驿站 · 有 ${appState.stationSuggestions.length} 条整理建议'
                      : '已配置 ${appState.enabledStationRules.length} 个常用驿站，支持别名优先归类',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StationManagePage(appState: appState),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Section 2: Identity code button management
          const _SectionLabel('身份码按钮管理'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  '排序、显隐与跳转链接配置',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '当前已开启 ${appState.visibleShortcuts.length}/${appState.shortcuts.length} 个快捷入口，可自定义 URL Scheme',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ShortcutManagePage(appState: appState),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Section 3: Data & Privacy
          const _SectionLabel('数据与隐私'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppTheme.success,
                    size: 20,
                  ),
                ),
                title: const Text(
                  '已取件历史记录',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '共 $historyCount 条归档记录，支持恢复或删除',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HistoryPage(appState: appState),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: AppTheme.cardBorder),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: const Text(
                  '自动清理已取记录',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  '定期清理过期归档，保持清单清爽',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: DropdownButton<int>(
                  value: settings.autoCleanDays,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(12),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 天前')),
                    DropdownMenuItem(value: 30, child: Text('30 天前')),
                    DropdownMenuItem(value: 0, child: Text('不自动清理')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      appState.updateSettings(
                        settings.copyWith(autoCleanDays: v),
                      );
                    }
                  },
                ),
              ),
              const Divider(height: 1, color: AppTheme.cardBorder),
              const _CheckUpdateTile(),
              const Divider(height: 1, color: AppTheme.cardBorder),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: AppTheme.success,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '本地离线隐私声明',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 个人数据纯本地处理：所有短信解析、OCR 识别与取件码数据均在手机本地处理与存储，绝不上传任何个人隐私数据。\n'
                      '• 为什么使用网络权限（可选）：仅用于在您配置规则地址后拉取公开的识别规则 JSON 文件（如新增驿站前缀/后缀词库），不会上传任何短信、截图或取件码。\n'
                      '• 为什么使用无障碍权限（可选）：\n'
                      '  1. 控件识别零误差：优先读取页面控件文本，比纯截图 OCR 更快更准，避免 0/O、1/I 等误识；\n'
                      '  2. 免弹窗内存截屏：遇到小程序等自绘页面时，无需反复弹出系统「允许录屏」确认框，也不在相册留存截图；\n'
                      '  3. 按需触发：仅在您点击控制中心磁贴或主动开启「引导收码胶囊」时读取当前画面，平时不会在后台监听其他应用。\n'
                      '• 不开无障碍也能用：若您不希望开启无障碍权限，仍可正常使用本地短信识别、剪贴板识别、相册选图 OCR 及身份码一键直达。\n'
                      '• 其他权限说明：通知权限仅用于反馈磁贴识码结果；读取短信权限（可选）仅在您点击导入时于本地筛选取件短信；Shizuku（可选）仅用于防止系统杀掉无障碍服务；身份码仅通过 URL Scheme 拉起对应 App，不采集账号或 Cookie。',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckUpdateTile extends StatefulWidget {
  const _CheckUpdateTile();

  @override
  State<_CheckUpdateTile> createState() => _CheckUpdateTileState();
}

class _CheckUpdateTileState extends State<_CheckUpdateTile> {
  String _currentVersion = '0.1.0';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    QuickTileService.getAppVersion().then((v) {
      if (mounted) {
        setState(() => _currentVersion = v);
      }
    });
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final info = await const AppUpdateService().checkForUpdate(
        currentVersion: _currentVersion,
      );
      if (!mounted) return;
      if (!info.hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('当前已是最新版本（v$_currentVersion）')),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本 ${info.latestVersion}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前版本：v${info.currentVersion}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  info.releaseNotes.isEmpty
                      ? '包含功能优化与问题修复，建议更新体验。'
                      : info.releaseNotes,
                  style: const TextStyle(fontSize: 13.5, height: 1.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('暂不更新'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.tryParse(info.downloadUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('去下载更新'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.system_update_rounded,
          color: AppTheme.primary,
          size: 20,
        ),
      ),
      title: const Text(
        '检查应用更新',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '当前版本 v$_currentVersion · 从 GitHub Releases 获取最新版',
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      trailing: _checking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: _checkUpdate,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _QuickTileGuideCard extends StatefulWidget {
  const _QuickTileGuideCard();

  @override
  State<_QuickTileGuideCard> createState() => _QuickTileGuideCardState();
}

class _QuickTileGuideCardState extends State<_QuickTileGuideCard>
    with WidgetsBindingObserver {
  QuickTileStatus _status = const QuickTileStatus();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final status = await QuickTileService.getStatus();
    if (mounted) {
      setState(() => _status = status);
    }
  }

  Future<void> _handleNotificationAction() async {
    final granted = await QuickTileService.requestNotificationPermission();
    await _refreshStatus();
    if (!granted && mounted) {
      await QuickTileService.openNotificationSettings();
    }
  }

  Future<void> _handleShizukuAction() async {
    if (!_status.shizukuRunning) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未检测到正在运行的 Shizuku，请先打开 Shizuku 应用启动服务'),
        ),
      );
      return;
    }

    if (!_status.shizukuAuthorized) {
      final granted = await QuickTileService.requestShizukuPermission();
      await _refreshStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted ? '已授权 Shizuku，将自动保活并恢复无障碍服务' : '未获得 Shizuku 授权',
          ),
        ),
      );
      return;
    }

    final ok = await QuickTileService.restoreAccessibilityWithShizuku();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await _refreshStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '已通过 Shizuku 恢复并保活无障碍服务' : '恢复失败，请检查 Shizuku 状态'),
      ),
    );
  }

  Future<void> _handleAddTile() async {
    final res = await QuickTileService.requestAddQuickTile();
    if (!mounted) return;
    final msg = switch (res) {
      'added' => '已将「识取件码」添加到控制中心',
      'already_added' => '「识取件码」已在控制中心中',
      'not_added' => '已取消添加，你也可下拉控制中心手动编辑添加',
      _ => '请下拉系统控制中心，点击编辑并拖入「识取件码」磁贴',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final ready = _status.isReady;
    return _SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ready
                      ? const Color(0xFFECFDF5)
                      : AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.document_scanner_rounded,
                  color: ready ? AppTheme.success : AppTheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '下拉点击磁贴，自动截屏识码并入库',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '无障碍控件优先 + 内存 OCR 保底，不留相册截图',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ready
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  ready ? '已就绪' : '待配置',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ready ? AppTheme.success : const Color(0xFFEA580C),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.cardBorder),
        ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: const Text(
            '1. 开启通知权限',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            '识别入库后通过系统通知立即反馈取件码',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          trailing: _status.notificationEnabled
              ? const Text(
                  '已开启',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                )
              : FilledButton.tonal(
                  onPressed: _handleNotificationAction,
                  child: const Text('去开启'),
                ),
        ),
        const Divider(height: 1, color: AppTheme.cardBorder),
        ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: const Text(
            '2. 开启「取件码一键截屏识别」无障碍',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            '仅点击磁贴或开启收码胶囊时识别当前页（控件优先+内存OCR），平时不监听；若提示受限，先在应用信息允许受限设置',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          trailing: _status.accessibilityRunning
              ? const Text(
                  '已运行',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                )
              : FilledButton.tonal(
                  onPressed: QuickTileService.openAccessibilitySettings,
                  child: const Text('去开启'),
                ),
        ),
        const Divider(height: 1, color: AppTheme.cardBorder),
        ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: const Text(
            'Shizuku 无障碍自动保活（推荐）',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            !_status.shizukuRunning
                ? '未检测到运行中的 Shizuku；开启后可自动拉起被系统杀掉的无障碍服务'
                : _status.shizukuAuthorized
                    ? '已授权：点击磁贴或打开应用时自动保护并恢复无障碍权限'
                    : '已检测到 Shizuku，授权后无需每次手动重开无障碍',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          trailing: _status.shizukuAuthorized
              ? TextButton(
                  onPressed: _handleShizukuAction,
                  child: Text(
                    _status.accessibilityRunning ? '已保护' : '立即恢复',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _status.accessibilityRunning
                          ? AppTheme.success
                          : AppTheme.primary,
                    ),
                  ),
                )
              : FilledButton.tonal(
                  onPressed: _handleShizukuAction,
                  child: Text(_status.shizukuRunning ? '授权保活' : '未启动'),
                ),
        ),
        const Divider(height: 1, color: AppTheme.cardBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _handleAddTile,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_to_home_screen_rounded, size: 18),
                  label: Text(
                    _status.supportsRequestAddTile
                        ? '3. 一键添加到控制中心'
                        : '3. 添加到控制中心说明',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (!_status.accessibilityRunning) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: QuickTileService.openAppDetailsSettings,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('应用信息'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ShortcutManagePage extends StatefulWidget {
  const ShortcutManagePage({super.key, required this.appState});

  final AppState appState;

  @override
  State<ShortcutManagePage> createState() => _ShortcutManagePageState();
}

class _ShortcutManagePageState extends State<ShortcutManagePage> {
  late List<IdentityShortcut> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.appState.shortcuts);
  }

  Future<void> _save() async {
    await widget.appState.updateShortcuts(_items);
  }

  Future<void> _editShortcut(int index) async {
    final current = _items[index];
    final nameCtrl = TextEditingController(text: current.name);
    final subCtrl = TextEditingController(text: current.subtitle);
    final schemeCtrl = TextEditingController(text: current.schemeUrl);
    final fallbackCtrl =
        TextEditingController(text: current.fallbackSchemeUrl);

    final updated = await showModalBottomSheet<IdentityShortcut>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '配置「${current.name}」',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: '按钮名称'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subCtrl,
                    decoration: const InputDecoration(labelText: '副标题说明'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: schemeCtrl,
                    decoration: const InputDecoration(
                      labelText: '主跳转链接（URL Scheme）',
                      hintText: '例如 cainiao://cainiao.com/idcode',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fallbackCtrl,
                    decoration: const InputDecoration(
                      labelText: '兜底跳转链接（可选）',
                      hintText: '例如 cainiao://',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(
                          ctx,
                          current.copyWith(
                            name: nameCtrl.text.trim().isEmpty
                                ? current.name
                                : nameCtrl.text.trim(),
                            subtitle: subCtrl.text.trim(),
                            schemeUrl: schemeCtrl.text.trim(),
                            fallbackSchemeUrl: fallbackCtrl.text.trim(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('保存配置'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (updated != null) {
      setState(() => _items[index] = updated);
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('身份码按钮管理'),
        actions: [
          TextButton(
            onPressed: () async {
              await widget.appState.resetShortcutsToDefault();
              setState(() => _items = List.of(widget.appState.shortcuts));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复默认身份码配置')),
                );
              }
            },
            child: const Text('恢复默认'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length,
        onReorderItem: (oldIndex, newIndex) async {
          setState(() {
            final moved = _items.removeAt(oldIndex);
            _items.insert(newIndex, moved);
          });
          await _save();
        },
        itemBuilder: (context, index) {
          final item = _items[index];
          return Container(
            key: ValueKey(item.id),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: ListTile(
              onTap: () => _editShortcut(index),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                item.schemeUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch.adaptive(
                    value: item.visible,
                    onChanged: (v) async {
                      setState(() {
                        _items[index] = item.copyWith(visible: v);
                      });
                      await _save();
                    },
                  ),
                  const Icon(
                    Icons.drag_handle_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('已取件历史记录')),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final history = appState.historyItems;
          if (history.isEmpty) {
            return const Center(
              child: Text(
                '暂无已取件历史记录',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = history[index];
              final timeText = formatter.format(item.pickedUpAt ?? item.createdAt);
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.code,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.stationName} · 已取于 $timeText',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (item.itemNote.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.itemNote,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => appState.restoreItem(item),
                      child: const Text('恢复待取'),
                    ),
                    IconButton(
                      tooltip: '删除',
                      onPressed: () => appState.deleteItem(item),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
