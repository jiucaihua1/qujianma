import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pickup_item.dart';
import '../services/app_state.dart';
import '../services/ocr_service.dart';
import '../services/pickup_parser.dart';
import '../services/quick_tile_service.dart';
import '../theme/app_theme.dart';

enum AddMethod { guidedScan, smsBackfill, ocr, text, manual }

Future<AddMethod?> showAddMethodSheet(BuildContext context) {
  return showModalBottomSheet<AddMethod>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
              const Text(
                '添加待取包裹',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '所有识别均在手机本地离线完成，不上传任何数据',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              _MethodTile(
                icon: Icons.open_in_new_rounded,
                color: const Color(0xFF7C3AED),
                title: '跳转 App 自动收码（推荐）',
                subtitle: '跳去菜鸟/淘宝/拼多多/抖音自动识别，确认后一键返回',
                onTap: () => Navigator.pop(ctx, AddMethod.guidedScan),
              ),
              const SizedBox(height: 10),
              _MethodTile(
                icon: Icons.sms_rounded,
                color: const Color(0xFF0D9488),
                title: '倒查系统短信（1/3/7/15天）',
                subtitle: '纯本地扫描最近几天收件箱，自动提取取件码并去重入库',
                onTap: () => Navigator.pop(ctx, AddMethod.smsBackfill),
              ),
              const SizedBox(height: 10),
              _MethodTile(
                icon: Icons.photo_library_rounded,
                color: const Color(0xFF2563EB),
                title: '截图识别（本地 OCR）',
                subtitle: '选取淘宝、拼多多物流或取件码截图自动提取',
                onTap: () => Navigator.pop(ctx, AddMethod.ocr),
              ),
              const SizedBox(height: 10),
              _MethodTile(
                icon: Icons.content_paste_go_rounded,
                color: const Color(0xFF16A34A),
                title: '粘贴文本识别',
                subtitle: '自动解析取件短信或微信通知，支持多条一次导入',
                onTap: () => Navigator.pop(ctx, AddMethod.text),
              ),
              const SizedBox(height: 10),
              _MethodTile(
                icon: Icons.edit_note_rounded,
                color: const Color(0xFFEA580C),
                title: '手动录入',
                subtitle: '直接填写取件码、驿站名称与物品备注',
                onTap: () => Navigator.pop(ctx, AddMethod.manual),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.canvas,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidedTarget {
  const _GuidedTarget({
    required this.name,
    required this.subtitle,
    required this.primaryUrl,
    this.fallbackUrl = '',
    this.fallbackPackage = '',
    required this.icon,
    required this.color,
  });

  final String name;
  final String subtitle;
  final String primaryUrl;
  final String fallbackUrl;
  final String fallbackPackage;
  final IconData icon;
  final Color color;
}

const _guidedTargets = <_GuidedTarget>[
  _GuidedTarget(
    name: '菜鸟',
    subtitle: '直达待取件页',
    primaryUrl: 'guoguo://go/pickup_page_native',
    fallbackUrl: 'guoguo://go/allpackage',
    fallbackPackage: 'com.cainiao.wireless',
    icon: Icons.local_shipping_rounded,
    color: Color(0xFF1677FF),
  ),
  _GuidedTarget(
    name: '淘宝',
    subtitle: '直达待取件页',
    primaryUrl:
        'taobao://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F1100333%2Flast-mile-fe%2Fm-end-school-tab%2Fhome',
    fallbackUrl:
        'tbopen://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F1100333%2Flast-mile-fe%2Fm-end-school-tab%2Fhome',
    fallbackPackage: 'com.taobao.taobao',
    icon: Icons.shopping_bag_rounded,
    color: Color(0xFFFF6A00),
  ),
  _GuidedTarget(
    name: '拼多多',
    subtitle: '直达待取件页',
    primaryUrl: 'pinduoduo://com.xunmeng.pinduoduo/mdkd/package',
    fallbackUrl:
        'pinduoduo://com.xunmeng.pinduoduo/psnl_goods_help.html?_t_module_name=assistant_search&refer_scene=express_box',
    fallbackPackage: 'com.xunmeng.pinduoduo',
    icon: Icons.storefront_rounded,
    color: Color(0xFFE02E24),
  ),
  _GuidedTarget(
    name: '京东',
    subtitle: '直达订单物流',
    primaryUrl:
        'openjd://virtual?params=%7B%22category%22%3A%22jump%22%2C%22des%22%3A%22orderlist%22%7D',
    fallbackUrl:
        'weixin://dl/business/?appid=wx91d27dbf599dff74&path=pages/index/index',
    fallbackPackage: 'com.jingdong.app.mall',
    icon: Icons.local_mall_rounded,
    color: Color(0xFFE1251B),
  ),
  _GuidedTarget(
    name: '抖音',
    subtitle: '直达商城订单',
    primaryUrl: 'snssdk1128://ecom_order_list',
    fallbackUrl: 'snssdk2329://ecom_order_list',
    fallbackPackage: 'com.ss.android.ugc.aweme',
    icon: Icons.music_note_rounded,
    color: Color(0xFF111827),
  ),
  _GuidedTarget(
    name: '快手',
    subtitle: '直达小店订单',
    primaryUrl:
        'kwai://webview?url=https%3A%2F%2Fapp.kwaixiaodian.com%2Fpage%2Fkwaishop-trade-order-list-app%3FlayoutType%3D4%26hyId%3DkwaishopOrder',
    fallbackUrl:
        'ksnebula://webview?url=https%3A%2F%2Fapp.kwaixiaodian.com%2Fpage%2Fkwaishop-trade-order-list-app%3FlayoutType%3D4%26hyId%3DkwaishopOrder',
    fallbackPackage: 'com.smile.gifmaker',
    icon: Icons.ondemand_video_rounded,
    color: Color(0xFFFF5000),
  ),
  _GuidedTarget(
    name: '得物',
    subtitle: '直达买家订单',
    primaryUrl: 'dewuapp://m.dewu.com/router/order/buyer/orderList?tabId=0',
    fallbackPackage: 'com.shizhuang.duapp',
    icon: Icons.checkroom_rounded,
    color: Color(0xFF06B6D4),
  ),
  _GuidedTarget(
    name: '系统短信',
    subtitle: '取件短信收件箱',
    primaryUrl: 'sms:',
    icon: Icons.sms_rounded,
    color: Color(0xFF16A34A),
  ),
];

/// Lets the user pick an app to jump to with a floating auto-recognition capsule.
Future<void> showGuidedScanTargetSheet(BuildContext context) async {
  final selected = await showModalBottomSheet<_GuidedTarget>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
              const Text(
                '选择要去收码的应用',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '跳转后顶部会出现悬浮胶囊，滑到取件码页自动识别，点「入库并返回」立刻回来',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                itemCount: _guidedTargets.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 96,
                ),
                itemBuilder: (ctx, index) {
                  final target = _guidedTargets[index];
                  return Material(
                    color: AppTheme.canvas,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, target),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: target.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                target.icon,
                                color: target.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              target.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              target.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );

  if (selected == null || !context.mounted) return;

  final res = await QuickTileService.startGuidedScanSession(
    targetName: selected.name,
    primaryUrl: selected.primaryUrl,
    fallbackUrl: selected.fallbackUrl,
    fallbackPackage: selected.fallbackPackage,
  );
  if (!context.mounted) return;

  if (res == 'need_accessibility') {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('请先开启「取件码一键截屏识别」无障碍（或配置 Shizuku 保活）'),
        action: SnackBarAction(
          label: '去开启',
          onPressed: QuickTileService.openAccessibilitySettings,
        ),
      ),
    );
  } else if (res == 'launch_failed') {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('未能打开「${selected.name}」，请确认手机已安装该应用')),
    );
  }
}

/// Scans local Android SMS inbox for pickup codes from the past N days.
Future<void> showSmsBackfillSheet(
  BuildContext context, {
  required AppState appState,
}) async {
  var selectedDays = 7;
  var scanning = false;
  SmsBackfillResult? result;
  String? errorMessage;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> runScan() async {
            setModalState(() {
              scanning = true;
              errorMessage = null;
              result = null;
            });

            var granted = await QuickTileService.checkSmsPermission();
            if (!granted) {
              granted = await QuickTileService.requestSmsPermission();
            }
            if (!granted) {
              setModalState(() {
                scanning = false;
                errorMessage =
                    '未获得读取短信权限；小米/澎湃 OS 请在「应用信息 → 权限管理」中允许读取短信与通知类短信。';
              });
              return;
            }

            try {
              final res =
                  await QuickTileService.scanSmsInbox(days: selectedDays);
              await appState.reloadItems();
              setModalState(() {
                scanning = false;
                result = res;
              });
            } catch (e) {
              setModalState(() {
                scanning = false;
                errorMessage = '倒查短信失败：$e';
              });
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  const Text(
                    '倒查系统短信',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '纯本地扫描收件箱中的快递通知短信，自动提取取件码并去重入库',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '选择倒查天数',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: const [1, 3, 7, 15].map((days) {
                      return ChoiceChip(
                        label: Text('最近 $days 天'),
                        selected: selectedDays == days,
                        onSelected: scanning
                            ? null
                            : (_) => setModalState(() => selectedDays = days),
                      );
                    }).toList(),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: QuickTileService.openAppDetailsSettings,
                            child: const Text('打开应用信息设置权限'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (result != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.canvas,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '已扫描 ${result!.scannedCount} 条短信：新增 ${result!.insertedCount} 条，跳过重复 ${result!.skippedCount} 条',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (result!.insertedCodes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              result!.insertedCodes.join('、'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.success,
                              ),
                            ),
                          ] else if (result!.scannedCount == 0) ...[
                            const SizedBox(height: 4),
                            const Text(
                              '未读取到短信，若为小米/澎湃 OS 请检查是否允许读取「通知类短信」。',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: scanning ? null : runScan,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: scanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.manage_search_rounded, size: 20),
                      label: Text(
                        scanning ? '正在本地扫描短信…' : '开始倒查最近 $selectedDays 天短信',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Manual add / edit pickup item bottom sheet.
Future<void> showManualAddOrEditSheet(
  BuildContext context, {
  required AppState appState,
  PickupItem? editingItem,
  ParsedPickupCandidate? prefill,
}) async {
  final codeController = TextEditingController(
    text: editingItem?.code ?? prefill?.code ?? '',
  );
  final stationController = TextEditingController(
    text: editingItem?.stationName ?? prefill?.stationName ?? '',
  );
  final noteController = TextEditingController(
    text: editingItem?.itemNote ?? prefill?.itemNote ?? '',
  );
  final trackingController = TextEditingController(
    text: editingItem?.trackingNumber ?? prefill?.trackingNumber ?? '',
  );
  var selectedSource =
      editingItem?.source ?? prefill?.source ?? PickupSource.manual;
  var selectedCategory = editingItem?.itemCategory;

  final knownStations = appState.knownStations;
  final presetStations = <String>[
    ...knownStations,
    for (final s in const ['菜鸟驿站', '丰巢快递柜', '多多驿站', '兔喜生活'])
      if (!knownStations.contains(s)) s,
  ].take(6).toList();

  final formKey = GlobalKey<FormState>();

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
                            editingItem != null ? '编辑取件信息' : '录入取件码',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (editingItem != null)
                            TextButton.icon(
                              onPressed: () async {
                                await appState.deleteItem(editingItem);
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
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                        decoration: const InputDecoration(
                          labelText: '取件码 *',
                          hintText: '例如 12-3-405 或 839204',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return '请输入取件码';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: stationController,
                        decoration: const InputDecoration(
                          labelText: '驿站 / 快递柜名称 *',
                          hintText: '例如 菜鸟驿站、东门丰巢',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return '请输入驿站或快递柜名称';
                          }
                          return null;
                        },
                      ),
                      if (presetStations.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: presetStations
                              .map(
                                (station) => ActionChip(
                                  label: Text(
                                    station,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: AppTheme.canvas,
                                  side: const BorderSide(
                                      color: AppTheme.cardBorder),
                                  onPressed: () {
                                    stationController.text = station;
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Text(
                        '来源标签',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PickupSource.values.map((source) {
                          final selected = selectedSource == source;
                          return ChoiceChip(
                            label: Text(source.label),
                            selected: selected,
                            selectedColor:
                                source.color.withValues(alpha: 0.16),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? source.color
                                  : AppTheme.textSecondary,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? source.color
                                  : AppTheme.cardBorder,
                            ),
                            onSelected: (_) {
                              setModalState(() => selectedSource = source);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '物品种类（可选，大图标标识）',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.22,
                        children: ItemCategory.values.map((category) {
                          final selected = selectedCategory == category;
                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedCategory = selected ? null : category;
                              });
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              decoration: BoxDecoration(
                                color: selected
                                    ? category.color.withValues(alpha: 0.14)
                                    : AppTheme.canvas,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? category.color
                                      : AppTheme.cardBorder,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    category.icon,
                                    size: 24,
                                    color: selected
                                        ? category.color
                                        : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    category.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? category.color
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: '物品备注（可选）',
                          hintText: '例如 抽纸、猫粮、手机壳',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: trackingController,
                        decoration: const InputDecoration(
                          labelText: '快递单号（可选）',
                          hintText: '例如 SF1234567890',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final originalStation =
                                (editingItem?.stationName ??
                                        prefill?.stationName ??
                                        '')
                                    .trim();
                            final newStation = stationController.text.trim();
                            if (editingItem != null) {
                              await appState.updatePickupItem(
                                editingItem.copyWith(
                                  code: codeController.text.trim().toUpperCase(),
                                  stationName: newStation,
                                  source: selectedSource,
                                  itemCategory: selectedCategory,
                                  clearItemCategory: selectedCategory == null,
                                  itemNote: noteController.text.trim(),
                                  trackingNumber:
                                      trackingController.text.trim(),
                                ),
                              );
                            } else {
                              await appState.addPickupItem(
                                code: codeController.text.trim(),
                                stationName: newStation,
                                source: selectedSource,
                                itemCategory: selectedCategory,
                                itemNote: noteController.text.trim(),
                                trackingNumber: trackingController.text.trim(),
                                rawText: prefill?.rawText ?? '',
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            final changedStation = newStation.isNotEmpty &&
                                newStation != '默认驿站' &&
                                newStation != originalStation;
                            if (changedStation && context.mounted) {
                              final hasValidOriginal =
                                  originalStation.isNotEmpty &&
                                      originalStation != '默认驿站';
                              final messenger = ScaffoldMessenger.of(context);
                              messenger.clearSnackBars();
                              messenger.showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 5),
                                  content: Text(
                                    hasValidOriginal
                                        ? '已改为「$newStation」，下次遇到「$originalStation」也自动归类吗？'
                                        : '已改为「$newStation」，是否加入常用驿站方便下次识别？',
                                  ),
                                  action: SnackBarAction(
                                    label: '记住规则',
                                    onPressed: () {
                                      appState.learnStationAlias(
                                        targetStation: newStation,
                                        alias: hasValidOriginal
                                            ? originalStation
                                            : '',
                                      );
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            editingItem != null ? '保存修改' : '保存到待取件',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

/// Paste SMS / WeChat text and parse locally with regex.
Future<void> showTextParseSheet(
  BuildContext context, {
  required AppState appState,
}) async {
  final textController = TextEditingController();
  var parsed = <ParsedPickupCandidate>[];

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
          void reparse(String val) {
            setModalState(() {
              parsed = PickupParser.parseAll(
                val,
                defaultSource: PickupSource.sms,
                stationRules: appState.stationRules,
              );
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
                        const Text(
                          '粘贴短信 / 通知识别',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            final data =
                                await Clipboard.getData(Clipboard.kTextPlain);
                            final clip = data?.text ?? '';
                            if (clip.isNotEmpty) {
                              textController.text = clip;
                              reparse(clip);
                            }
                          },
                          icon: const Icon(Icons.content_paste_rounded, size: 16),
                          label: const Text('粘贴剪贴板'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textController,
                      maxLines: 4,
                      onChanged: reparse,
                      decoration: const InputDecoration(
                        hintText:
                            '粘贴取件短信，例如：\n【菜鸟驿站】您的包裹已到阳光花园菜鸟驿站，凭取件码12-3-405领取',
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (parsed.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.canvas,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          textController.text.trim().isEmpty
                              ? '粘贴后将自动在本地提取取件码、驿站名称与单号'
                              : '暂未识别到标准取件码，可尝试手动录入或补充“取件码：”字样',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      )
                    else ...[
                      Text(
                        '已识别到 ${parsed.length} 条取件信息',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...parsed.map(
                        (item) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.canvas,
                            borderRadius: BorderRadius.circular(14),
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
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.stationName} · ${item.source.label}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (parsed.length == 1)
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    showManualAddOrEditSheet(
                                      context,
                                      appState: appState,
                                      prefill: item,
                                    );
                                  },
                                  child: const Text('微调'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: parsed.isEmpty
                            ? null
                            : () async {
                                for (final item in parsed) {
                                  await appState.addPickupItem(
                                    code: item.code,
                                    stationName: item.stationName,
                                    source: item.source,
                                    itemNote: item.itemNote,
                                    trackingNumber: item.trackingNumber,
                                    rawText: item.rawText,
                                  );
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('已入库 ${parsed.length} 条取件码'),
                                    ),
                                  );
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          parsed.length > 1
                              ? '一键入库全部 ${parsed.length} 条'
                              : '确认入库',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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

/// Runs local Google ML Kit OCR on a picked screenshot and displays a review sheet.
Future<void> runOcrImportFlow(
  BuildContext context, {
  required AppState appState,
  required OcrService ocrService,
}) async {
  OcrResult? result;
  try {
    result = await ocrService.pickAndRecognizeScreenshot(
      stationRules: appState.stationRules,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('本地 OCR 识别失败：$e')),
    );
    return;
  }

  if (result == null || !context.mounted) return;

  if (result.candidates.isEmpty) {
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
                const Text(
                  '未自动提取到取件码',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '以下为本地 OCR 识别到的原始文字，你可以手动补录：',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 160),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.canvas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      result!.rawText.isEmpty ? '（图片中未检测到清晰文字）' : result.rawText,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      showManualAddOrEditSheet(
                        context,
                        appState: appState,
                        prefill: ParsedPickupCandidate(
                          code: '',
                          stationName: '菜鸟驿站',
                          source: PickupSource.ocr,
                          rawText: result!.rawText,
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
                    child: const Text('去手动补录'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return;
  }

  if (result.candidates.length == 1) {
    await showManualAddOrEditSheet(
      context,
      appState: appState,
      prefill: result.candidates.first,
    );
    return;
  }

  // Multiple codes detected in one screenshot
  final candidates = result.candidates;
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
              Text(
                '本地 OCR 识别到 ${candidates.length} 条取件码',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...candidates.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.canvas,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(
                        item.code,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.stationName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    for (final item in candidates) {
                      await appState.addPickupItem(
                        code: item.code,
                        stationName: item.stationName,
                        source: item.source,
                        itemNote: item.itemNote,
                        trackingNumber: item.trackingNumber,
                        rawText: item.rawText,
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已入库 ${candidates.length} 条取件码'),
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text('一键入库全部 ${candidates.length} 条'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
