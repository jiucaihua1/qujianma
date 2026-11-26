import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/identity_shortcut.dart';
import '../services/app_state.dart';
import '../services/scheme_launcher.dart';
import '../theme/app_theme.dart';

class IdentityCodePage extends StatelessWidget {
  const IdentityCodePage({
    super.key,
    required this.appState,
    required this.onGoToPickupTab,
    required this.onGoToSettingsTab,
  });

  final AppState appState;
  final VoidCallback onGoToPickupTab;
  final VoidCallback onGoToSettingsTab;

  Future<void> _handleLaunch(
    BuildContext context,
    IdentityShortcut shortcut,
  ) async {
    final status = await SchemeLauncher.launchShortcut(shortcut);
    if (!context.mounted) return;

    if (status == SchemeLaunchStatus.failed) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '未能打开「${shortcut.name}」',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '请确认手机已安装对应应用，或前往设置修改跳转链接。',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: shortcut.schemeUrl),
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制跳转链接')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('复制链接'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onGoToSettingsTab();
                          },
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('去设置'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = appState.visibleShortcuts;
    final pendingCount = appState.pendingCount;
    final clipboardSuggestion = appState.clipboardSuggestion;

    final heroItems = shortcuts.take(2).toList();
    final secondaryItems = shortcuts.skip(2).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          // Clean minimal top header
          Row(
            children: [
              const Text(
                '身份码',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onGoToPickupTab,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: pendingCount > 0
                        ? AppTheme.primarySoft
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: pendingCount > 0
                          ? AppTheme.primary.withValues(alpha: 0.25)
                          : AppTheme.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pendingCount > 0 ? '待取 $pendingCount 件' : '取件一览',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: pendingCount > 0
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: pendingCount > 0
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (clipboardSuggestion != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.content_paste_search_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '剪贴板发现取件码',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          '${clipboardSuggestion.code} · ${clipboardSuggestion.stationName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: appState.dismissClipboardSuggestion,
                    child: const Text('忽略'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      await appState.addPickupItem(
                        code: clipboardSuggestion.code,
                        stationName: clipboardSuggestion.stationName,
                        source: clipboardSuggestion.source,
                        itemNote: clipboardSuggestion.itemNote,
                        trackingNumber: clipboardSuggestion.trackingNumber,
                        rawText: clipboardSuggestion.rawText,
                      );
                      appState.dismissClipboardSuggestion();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 2),
                            content: Text('已入库 ${clipboardSuggestion.code}'),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('入库'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (shortcuts.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: [
                  const Text(
                    '暂无快捷入口',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onGoToSettingsTab,
                    child: const Text('前往设置开启'),
                  ),
                ],
              ),
            )
          else ...[
            // Primary large identity code buttons (one-tap reach)
            ...heroItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HeroShortcutButton(
                  shortcut: item,
                  onTap: () => _handleLaunch(context, item),
                ),
              ),
            ),

            if (secondaryItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 10),
                child: Text(
                  '快捷直达',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              _CompactShortcutGrid(
                shortcuts: secondaryItems,
                onTap: (item) => _handleLaunch(context, item),
              ),
            ],
          ],

          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: onGoToSettingsTab,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
              ),
              child: const Text(
                '自定义入口顺序与链接',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroShortcutButton extends StatelessWidget {
  const _HeroShortcutButton({
    required this.shortcut,
    required this.onTap,
  });

  final IdentityShortcut shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: shortcut.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  shortcut.icon,
                  color: shortcut.color,
                  size: 25,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortcut.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shortcut.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactShortcutGrid extends StatelessWidget {
  const _CompactShortcutGrid({
    required this.shortcuts,
    required this.onTap,
  });

  final List<IdentityShortcut> shortcuts;
  final ValueChanged<IdentityShortcut> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < shortcuts.length; i += 2) {
      final first = shortcuts[i];
      final second = (i + 1 < shortcuts.length) ? shortcuts[i + 1] : null;
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(
        Row(
          children: [
            Expanded(
              child: _CompactShortcutTile(
                shortcut: first,
                onTap: () => onTap(first),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: second != null
                  ? _CompactShortcutTile(
                      shortcut: second,
                      onTap: () => onTap(second),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _CompactShortcutTile extends StatelessWidget {
  const _CompactShortcutTile({
    required this.shortcut,
    required this.onTap,
  });

  final IdentityShortcut shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: shortcut.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  shortcut.icon,
                  color: shortcut.color,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortcut.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      shortcut.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
