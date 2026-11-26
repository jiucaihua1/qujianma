import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pickup_item.dart';
import '../models/station_rule.dart';
import '../services/app_state.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pickup_sheets.dart';
import 'station_manage_page.dart';

class PickupListPage extends StatelessWidget {
  const PickupListPage({
    super.key,
    required this.appState,
    required this.ocrService,
  });

  final AppState appState;
  final OcrService ocrService;

  Future<void> _handleComplete(BuildContext context, PickupItem item) async {
    await appState.markPickedUp(item);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text('已核销取件码 ${item.code}'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => appState.restoreItem(item),
        ),
      ),
    );
    // Force-dismiss after 3s even when Android AccessibilityService is active
    // (Flutter disables SnackBar auto-dismissal for action SnackBars under accessibility).
    Future<void>.delayed(const Duration(seconds: 3), () {
      try {
        controller.close();
      } catch (_) {}
    });
  }

  Future<void> _openAddMenu(BuildContext context) async {
    final method = await showAddMethodSheet(context);
    if (method == null || !context.mounted) return;
    switch (method) {
      case AddMethod.guidedScan:
        await showGuidedScanTargetSheet(context);
      case AddMethod.smsBackfill:
        await showSmsBackfillSheet(context, appState: appState);
      case AddMethod.ocr:
        await runOcrImportFlow(
          context,
          appState: appState,
          ocrService: ocrService,
        );
      case AddMethod.text:
        await showTextParseSheet(context, appState: appState);
      case AddMethod.manual:
        await showManualAddOrEditSheet(context, appState: appState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = appState.groupedPendingByStation;
    final totalCount = appState.pendingCount;
    final clipboardSuggestion = appState.clipboardSuggestion;
    final stationSuggestions = appState.settings.showStationSuggestionBanner
        ? appState.stationSuggestions
        : const <StationSuggestion>[];
    final topStationSuggestion =
        stationSuggestions.isNotEmpty ? stationSuggestions.first : null;
    final showScreenshotHint = appState.settings.autoDetectScreenshotHint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '取件一览',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          totalCount > 0
                              ? '共 $totalCount 件 · 分布在 ${grouped.length} 个驿站/快递柜'
                              : '按驿站自动分组，到了一个点一次拿完',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: '倒查系统短信',
                      onPressed: () =>
                          showSmsBackfillSheet(context, appState: appState),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0D9488),
                      ),
                      icon: const Icon(Icons.sms_rounded, size: 20),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: '跳转 App 自动收码',
                      onPressed: () => showGuidedScanTargetSheet(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7C3AED),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: '截图识别',
                      onPressed: () => runOcrImportFlow(
                        context,
                        appState: appState,
                        ocrService: ocrService,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                      ),
                      icon: const Icon(Icons.photo_camera_back_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            if (clipboardSuggestion != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.content_paste_search_rounded,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '检测到剪贴板取件码',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${clipboardSuggestion.code} · ${clipboardSuggestion.stationName}',
                                style: const TextStyle(
                                  fontSize: 15,
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
                              trackingNumber:
                                  clipboardSuggestion.trackingNumber,
                              rawText: clipboardSuggestion.rawText,
                            );
                            appState.dismissClipboardSuggestion();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('入库'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (topStationSuggestion != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topStationSuggestion.type ==
                                        StationSuggestionType.mergeSimilar
                                    ? '发现相似驿站，建议合并'
                                    : '发现高频驿站，建议设为常用',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                topStationSuggestion.type ==
                                        StationSuggestionType.mergeSimilar
                                    ? '「${topStationSuggestion.primaryName}」与「${topStationSuggestion.secondaryNames.join('、')}」'
                                    : '「${topStationSuggestion.primaryName}」已出现 ${topStationSuggestion.occurrenceCount} 次',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    StationManagePage(appState: appState),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('去整理'),
                        ),
                        IconButton(
                          tooltip: '关闭建议推送',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () async {
                            await appState.updateSettings(
                              appState.settings.copyWith(
                                showStationSuggestionBanner: false,
                              ),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                duration: Duration(seconds: 4),
                                content: Text(
                                  '已关闭取件页整理建议，以后不再推送；如需开启可前往「设置 → 常用驿站与识别规则」',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (showScreenshotHint)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: InkWell(
                    onTap: () => runOcrImportFlow(
                      context,
                      appState: appState,
                      ocrService: ocrService,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '刚截了淘宝/拼多多物流图？点此本地 OCR 一键导入',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (grouped.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: const Icon(
                          Icons.inbox_rounded,
                          size: 36,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '目前没有待取包裹',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '点击右下角「+」，通过截图识别、粘贴短信或手动录入添加取件码',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () => showGuidedScanTargetSheet(context),
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: const Text('跳转自动收码'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => showTextParseSheet(
                              context,
                              appState: appState,
                            ),
                            icon: const Icon(Icons.content_paste_rounded,
                                size: 18),
                            label: const Text('粘贴短信'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => runOcrImportFlow(
                              context,
                              appState: appState,
                              ocrService: ocrService,
                            ),
                            icon: const Icon(Icons.photo_library_rounded,
                                size: 18),
                            label: const Text('截图识别'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
                sliver: SliverList.separated(
                  itemCount: grouped.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final entry = grouped.entries.elementAt(index);
                    return _StationGroupCard(
                      stationName: entry.key,
                      items: entry.value,
                      onComplete: (item) => _handleComplete(context, item),
                      onEdit: (item) => showManualAddOrEditSheet(
                        context,
                        appState: appState,
                        editingItem: item,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddMenu(context),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          '录码',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _StationGroupCard extends StatelessWidget {
  const _StationGroupCard({
    required this.stationName,
    required this.items,
    required this.onComplete,
    required this.onEdit,
  });

  final String stationName;
  final List<PickupItem> items;
  final ValueChanged<PickupItem> onComplete;
  final ValueChanged<PickupItem> onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    size: 17,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stationName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.canvas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} 件',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.cardBorder),
          ...List.generate(items.length, (i) {
            final item = items[i];
            return Column(
              children: [
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppTheme.cardBorder,
                  ),
                _SwipeablePickupRow(
                  key: ValueKey('pickup_${item.id ?? '${item.code}_$i'}'),
                  isLast: i == items.length - 1,
                  onEdit: () => onEdit(item),
                  onComplete: () => onComplete(item),
                  child: InkWell(
                    onTap: () => onEdit(item),
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: item.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已复制取件码 ${item.code}')),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                      child: Row(
                        children: [
                          if (item.itemCategory != null) ...[
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: item.itemCategory!.color
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.itemCategory!.icon,
                                    size: 20,
                                    color: item.itemCategory!.color,
                                  ),
                                  Text(
                                    item.itemCategory!.label,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: item.itemCategory!.color,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    item.code,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: 0.4,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: item.source.color
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.source.label,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: item.source.color,
                                        ),
                                      ),
                                    ),
                                    if (item.itemNote.isNotEmpty ||
                                        item.trackingNumber.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          [
                                            if (item.itemNote.isNotEmpty)
                                              item.itemNote,
                                            if (item.trackingNumber.isNotEmpty)
                                              '单号 ${item.trackingNumber}',
                                          ].join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '编辑信息',
                            onPressed: () => onEdit(item),
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          IconButton(
                            tooltip: '标记已取件',
                            onPressed: () => onComplete(item),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 26,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// QQ / Cainiao-style horizontal swipe row:
/// Swipe left to reveal [编辑] and [已取件] buttons; swipe far left to complete directly.
class _SwipeablePickupRow extends StatefulWidget {
  const _SwipeablePickupRow({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onComplete,
    this.isLast = false,
  });

  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final bool isLast;

  @override
  State<_SwipeablePickupRow> createState() => _SwipeablePickupRowState();
}

class _SwipeablePickupRowState extends State<_SwipeablePickupRow>
    with SingleTickerProviderStateMixin {
  static const double _editBtnWidth = 70;
  static const double _doneBtnWidth = 84;
  static const double _actionWidth = _editBtnWidth + _doneBtnWidth;

  late final AnimationController _controller;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    if (_activeTick != null) {
      _controller.removeListener(_activeTick!);
      _activeTick = null;
    }
    _controller.dispose();
    super.dispose();
  }

  VoidCallback? _activeTick;

  void _animateTo(double target) {
    _controller.stop();
    if (_activeTick != null) {
      _controller.removeListener(_activeTick!);
      _activeTick = null;
    }
    final start = _dragOffset;
    _controller.reset();
    final tween = Tween<double>(begin: start, end: target);
    void tick() {
      if (!mounted) return;
      setState(() {
        _dragOffset =
            tween.transform(Curves.easeOutCubic.transform(_controller.value));
      });
    }

    _activeTick = tick;
    _controller.addListener(tick);
    _controller.forward().whenComplete(() {
      if (_activeTick == tick) {
        _controller.removeListener(tick);
        _activeTick = null;
      }
      if (mounted) {
        setState(() => _dragOffset = target);
      }
    });
  }

  void _close() => _animateTo(0);

  void _handleDragUpdate(DragUpdateDetails details) {
    _controller.stop();
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(-_actionWidth, 0.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    // Safe QQ-style swipe: only reveal [编辑] and [已取件] buttons, never auto-delete on flick.
    if (_dragOffset <= -_actionWidth * 0.55 || velocity < -600) {
      _animateTo(-_actionWidth);
    } else {
      _animateTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.isLast
        ? const BorderRadius.vertical(bottom: Radius.circular(20))
        : BorderRadius.zero;

    return ClipRRect(
      borderRadius: radius,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: _editBtnWidth,
                    height: double.infinity,
                    child: Material(
                      color: const Color(0xFF3B82F6),
                      child: InkWell(
                        onTap: () {
                          _close();
                          widget.onEdit();
                        },
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                            SizedBox(height: 3),
                            Text(
                              '编辑',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _doneBtnWidth,
                    height: double.infinity,
                    child: Material(
                      color: AppTheme.success,
                      child: InkWell(
                        onTap: () {
                          _close();
                          widget.onComplete();
                        },
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 22),
                            SizedBox(height: 3),
                            Text(
                              '已取件',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Material(
                color: Colors.white,
                child: _dragOffset < -4
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _close,
                        child: AbsorbPointer(child: widget.child),
                      )
                    : widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
