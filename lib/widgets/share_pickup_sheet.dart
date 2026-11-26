import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models/pickup_item.dart';
import '../services/app_state.dart';
import '../services/quick_tile_service.dart';
import '../theme/app_theme.dart';

enum ShareFormat { text, image }

Future<void> showSharePickupSheet(
  BuildContext context, {
  required AppState appState,
}) async {
  final grouped = appState.groupedPendingByStation;
  if (grouped.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('当前没有待取包裹可分享')),
    );
    return;
  }

  final allStations = grouped.keys.toList();
  final selectedStations = Set<String>.from(allStations);
  var format = ShareFormat.text;
  var sharing = false;
  final cardKey = GlobalKey();

  String buildShareText(Map<String, List<PickupItem>> selectedMap) {
    final total = selectedMap.values.fold<int>(0, (s, list) => s + list.length);
    final buf = StringBuffer('【待取快递清单 · 共 $total 件】\n');
    for (final entry in selectedMap.entries) {
      buf.writeln('\n📍 ${entry.key}（${entry.value.length}件）');
      for (final item in entry.value) {
        final note = item.itemNote.trim();
        buf.writeln(note.isEmpty ? '• ${item.code}' : '• ${item.code}（$note）');
      }
    }
    return buf.toString().trim();
  }

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
          final filteredMap = <String, List<PickupItem>>{
            for (final station in allStations)
              if (selectedStations.contains(station)) station: grouped[station]!,
          };
          final totalSelected = filteredMap.values.fold<int>(
            0,
            (sum, list) => sum + list.length,
          );
          final shareText = buildShareText(filteredMap);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: SingleChildScrollView(
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
                    const SizedBox(height: 14),
                    const Text(
                      '分享待取快递清单',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '可勾选需要代取的驿站，自由选择文字或图片形式发送',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (allStations.length > 1) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: allStations.map((station) {
                          final selected = selectedStations.contains(station);
                          final count = grouped[station]!.length;
                          return FilterChip(
                            label: Text('$station ($count)'),
                            selected: selected,
                            onSelected: (v) {
                              setModalState(() {
                                if (v) {
                                  selectedStations.add(station);
                                } else if (selectedStations.length > 1) {
                                  selectedStations.remove(station);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ShareFormat>(
                        segments: const [
                          ButtonSegment<ShareFormat>(
                            value: ShareFormat.text,
                            label: Text('文字清单'),
                            icon: Icon(Icons.notes_rounded, size: 18),
                          ),
                          ButtonSegment<ShareFormat>(
                            value: ShareFormat.image,
                            label: Text('图片卡片'),
                            icon: Icon(Icons.image_outlined, size: 18),
                          ),
                        ],
                        selected: {format},
                        onSelectionChanged: (sel) {
                          setModalState(() => format = sel.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (format == ShareFormat.text)
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 220),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.canvas,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            shareText,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.55,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: SingleChildScrollView(
                          child: RepaintBoundary(
                            key: cardKey,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primarySoft,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          '待取快递清单',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '共 $totalSelected 件',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  ...filteredMap.entries.map(
                                    (entry) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.canvas,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${entry.key}（${entry.value.length}件）',
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...entry.value.map(
                                              (item) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      item.code,
                                                      style: const TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            AppTheme.primary,
                                                        letterSpacing: 0.4,
                                                      ),
                                                    ),
                                                    if (item.itemNote
                                                        .trim()
                                                        .isNotEmpty) ...[
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          item.itemNote.trim(),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12.5,
                                                            color: AppTheme
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
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
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (format == ShareFormat.text)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: shareText),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已复制待取清单到剪贴板'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('复制文字'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () async {
                                await QuickTileService.shareText(
                                  text: shareText,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.share_rounded, size: 18),
                              label: const Text('系统分享'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: sharing
                              ? null
                              : () async {
                                  setModalState(() => sharing = true);
                                  try {
                                    final boundary = cardKey.currentContext
                                        ?.findRenderObject()
                                        as RenderRepaintBoundary?;
                                    if (boundary == null) {
                                      throw StateError('图片生成失败');
                                    }
                                    final image = await boundary.toImage(
                                      pixelRatio: 3.0,
                                    );
                                    final byteData = await image.toByteData(
                                      format: ui.ImageByteFormat.png,
                                    );
                                    if (byteData == null) {
                                      throw StateError('图片编码失败');
                                    }
                                    final ok = await QuickTileService.shareImage(
                                      bytes: byteData.buffer.asUint8List(),
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (!ok && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('调起系统分享失败'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => sharing = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text('生成图片失败：$e')),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: Text(sharing ? '正在生成图片...' : '分享清单图片'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
