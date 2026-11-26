import 'package:flutter/material.dart';

import '../models/station_rule.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class StationManagePage extends StatelessWidget {
  const StationManagePage({super.key, required this.appState});

  final AppState appState;

  Future<void> _openRuleEditor(
    BuildContext context, {
    StationRule? editing,
  }) async {
    final nameController = TextEditingController(
      text: editing?.standardName ?? '',
    );
    final aliasController = TextEditingController();
    final aliases = List<String>.from(editing?.aliases ?? const <String>[]);
    final formKey = GlobalKey<FormState>();

    // Uncovered historical stations that can be tapped to add as aliases quickly
    final quickCandidates = appState.knownStations
        .where(
          (s) =>
              s != '默认驿站' &&
              s != nameController.text.trim() &&
              !aliases.contains(s),
        )
        .take(8)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void addAlias(String raw) {
              final val = raw.trim();
              if (val.isEmpty ||
                  val == nameController.text.trim() ||
                  aliases.contains(val)) {
                aliasController.clear();
                return;
              }
              setModalState(() {
                aliases.add(val);
                aliasController.clear();
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
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
                        Row(
                          children: [
                            Text(
                              editing != null ? '编辑常用驿站' : '新增常用驿站',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (editing != null)
                              TextButton.icon(
                                onPressed: () async {
                                  await appState.deleteStationRule(editing.id);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text('删除'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: '标准驿站名称 *',
                            hintText: '例如：东门菜鸟驿站、南门丰巢柜',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return '请输入标准驿站名称';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '别名 / 触发关键词（短信或截图包含任意关键词时自动归入此驿站）',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: aliasController,
                                decoration: const InputDecoration(
                                  hintText: '输入门牌号、简称或原识别名',
                                ),
                                onSubmitted: addAlias,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: () => addAlias(aliasController.text),
                              child: const Text('添加'),
                            ),
                          ],
                        ),
                        if (aliases.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: aliases
                                .map(
                                  (alias) => InputChip(
                                    label: Text(
                                      alias,
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                    onDeleted: () {
                                      setModalState(() {
                                        aliases.remove(alias);
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (quickCandidates.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            '从历史驿站快速添加别名：',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: quickCandidates
                                .where((c) => !aliases.contains(c))
                                .map(
                                  (c) => ActionChip(
                                    label: Text(
                                      '+ $c',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: AppTheme.canvas,
                                    side: const BorderSide(
                                      color: AppTheme.cardBorder,
                                    ),
                                    onPressed: () => addAlias(c),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final pendingAlias = aliasController.text.trim();
                              if (pendingAlias.isNotEmpty &&
                                  pendingAlias != nameController.text.trim() &&
                                  !aliases.contains(pendingAlias)) {
                                aliases.add(pendingAlias);
                              }
                              final rule = StationRule(
                                id: editing?.id ??
                                    'rule_${DateTime.now().microsecondsSinceEpoch}',
                                standardName: nameController.text.trim(),
                                aliases: aliases,
                                enabled: editing?.enabled ?? true,
                                order: editing?.order ??
                                    appState.stationRules.length,
                              );
                              await appState.upsertStationRule(rule);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('保存规则'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showMergeDialog(
    BuildContext context,
    StationSuggestion suggestion,
  ) async {
    final candidates = [
      suggestion.primaryName,
      ...suggestion.secondaryNames,
    ];
    var selected = suggestion.primaryName;
    final customController = TextEditingController(text: selected);

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('合并相似驿站'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择或输入合并后的标准名称，其余名称将自动保存为别名：',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: candidates
                    .map(
                      (name) => ChoiceChip(
                        label: Text(name),
                        selected: selected == name,
                        onSelected: (_) {
                          setDialogState(() {
                            selected = name;
                            customController.text = name;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customController,
                decoration: const InputDecoration(
                  labelText: '标准驿站名称',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final val = customController.text.trim();
                if (val.isNotEmpty) {
                  Navigator.pop(ctx, val);
                }
              },
              child: const Text('确认合并'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != null && confirmed.isNotEmpty) {
      await appState.acceptSuggestion(suggestion, chosenPrimaryName: confirmed);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已合并为「$confirmed」，后续将自动归类')),
        );
      }
    }
  }

  Future<void> _showRuleSyncDialog(BuildContext context) async {
    final urlController = TextEditingController(
      text: appState.settings.ruleUpdateUrl,
    );
    var syncing = false;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('云端识别规则更新'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '输入托管的 parser_rules.json 链接（如 GitHub/Gitee/自建静态地址），拉取后本地与悬浮窗识别都会立即生效。',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '规则文件 URL',
                  hintText: 'https://example.com/parser_rules.json',
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMsg!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (appState.settings.lastRuleSyncAt.isNotEmpty)
              TextButton(
                onPressed: syncing
                    ? null
                    : () async {
                        await appState.resetRuleBundleToDefault();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: const Text('恢复内置'),
              ),
            TextButton(
              onPressed: syncing ? null : () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: syncing
                  ? null
                  : () async {
                      setDialogState(() {
                        syncing = true;
                        errorMsg = null;
                      });
                      try {
                        final bundle = await appState.syncRuleBundle(
                          url: urlController.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '规则已更新至 v${bundle.version}（${bundle.listStationPrefixes.length} 个前缀 · ${bundle.stationSuffixes.length} 个后缀）',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          syncing = false;
                          errorMsg = '更新失败：$e';
                        });
                      }
                    },
              child: Text(syncing ? '更新中...' : '保存并更新'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final rules = appState.stationRules;
        final suggestions = appState.stationSuggestions;
        final showBanner = appState.settings.showStationSuggestionBanner;

        return Scaffold(
          backgroundColor: AppTheme.canvas,
          appBar: AppBar(
            title: const Text('常用驿站与识别规则'),
            actions: [
              if (rules.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final updated = await appState.applyStationRulesToPending();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          updated > 0
                              ? '已按最新规则更新 $updated 条待取件驿站'
                              : '当前待取件均已符合最新规则',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: const Text('整理待取件'),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openRuleEditor(context),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新增常用驿站'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: showBanner,
                      title: const Text(
                        '在「取件一览」页推送整理建议',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        '检测到高频或相似驿站时，在取件页顶部轻提示',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      onChanged: (v) async {
                        await appState.updateSettings(
                          appState.settings.copyWith(
                            showStationSuggestionBanner: v,
                          ),
                        );
                        if (v) {
                          await appState.resetDismissedSuggestions();
                        }
                      },
                    ),
                    const Divider(height: 1, color: AppTheme.cardBorder),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.cloud_download_outlined,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        '云端识别规则热更新',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        appState.settings.lastRuleSyncAt.isNotEmpty
                            ? '当前 v${appState.ruleBundle.version} · 同步于 ${appState.settings.lastRuleSyncAt}'
                            : appState.settings.ruleUpdateUrl.isNotEmpty
                                ? '已配置地址 · 当前 v${appState.ruleBundle.version}'
                                : '未配置地址 · 当前使用内置规则 v${appState.ruleBundle.version}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showRuleSyncDialog(context),
                    ),
                  ],
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '智能整理建议',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                ...suggestions.map(
                  (s) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.type == StationSuggestionType.mergeSimilar
                                    ? '发现相似驿站，建议合并'
                                    : '高频驿站，建议设为常用',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  appState.dismissSuggestion(s.id),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppTheme.textSecondary,
                              ),
                              child: const Text('忽略'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.type == StationSuggestionType.mergeSimilar
                              ? '「${s.primaryName}」与「${s.secondaryNames.join('、')}」看起来是同一地点（共 ${s.occurrenceCount} 次记录）'
                              : '「${s.primaryName}」已出现 ${s.occurrenceCount} 次，设为常用后识别更准确',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () {
                              if (s.type == StationSuggestionType.mergeSimilar) {
                                _showMergeDialog(context, s);
                              } else {
                                appState.acceptSuggestion(s);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              s.type == StationSuggestionType.mergeSimilar
                                  ? '选择主名称并合并'
                                  : '加入常用驿站',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '我的常用驿站（${rules.length}）',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              if (rules.isEmpty)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.store_mall_directory_outlined,
                        size: 36,
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(height: 10),
                      Text(
                        '还没有配置常用驿站',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '添加常用驿站和别名后，抓取取件码会优先按您的习惯归类；平时在列表里修改驿站名时也可以一键记住。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...rules.map(
                  (rule) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openRuleEditor(context, editing: rule),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    rule.standardName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: rule.enabled
                                          ? AppTheme.textPrimary
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: rule.enabled,
                                  onChanged: (v) => appState.upsertStationRule(
                                    rule.copyWith(enabled: v),
                                  ),
                                ),
                              ],
                            ),
                            if (rule.aliases.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: rule.aliases
                                    .map(
                                      (alias) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.canvas,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: AppTheme.cardBorder,
                                          ),
                                        ),
                                        child: Text(
                                          alias,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  '点击可添加别名或门牌关键词',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
