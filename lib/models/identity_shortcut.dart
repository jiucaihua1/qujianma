import 'package:flutter/material.dart';

class IdentityShortcut {
  const IdentityShortcut({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.schemeUrl,
    this.fallbackSchemeUrl = '',
    required this.iconKey,
    required this.colorValue,
    this.visible = true,
    required this.order,
    this.isBuiltIn = true,
  });

  final String id;
  final String name;
  final String subtitle;
  final String schemeUrl;
  final String fallbackSchemeUrl;
  final String iconKey;
  final int colorValue;
  final bool visible;
  final int order;
  final bool isBuiltIn;

  Color get color => Color(colorValue);

  IconData get icon {
    switch (iconKey) {
      case 'taobao':
        return Icons.shopping_bag_rounded;
      case 'cainiao':
        return Icons.qr_code_2_rounded;
      case 'pinduoduo':
        return Icons.local_mall_rounded;
      case 'fcbox':
        return Icons.inventory_2_rounded;
      case 'sf':
        return Icons.local_shipping_rounded;
      case 'wechat':
        return Icons.qr_code_scanner_rounded;
      case 'jd':
        return Icons.storefront_rounded;
      case 'douyin':
        return Icons.music_note_rounded;
      case 'kuaishou':
        return Icons.ondemand_video_rounded;
      case 'dewu':
        return Icons.checkroom_rounded;
      default:
        return Icons.open_in_new_rounded;
    }
  }

  IdentityShortcut copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? schemeUrl,
    String? fallbackSchemeUrl,
    String? iconKey,
    int? colorValue,
    bool? visible,
    int? order,
    bool? isBuiltIn,
  }) {
    return IdentityShortcut(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      schemeUrl: schemeUrl ?? this.schemeUrl,
      fallbackSchemeUrl: fallbackSchemeUrl ?? this.fallbackSchemeUrl,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      visible: visible ?? this.visible,
      order: order ?? this.order,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'schemeUrl': schemeUrl,
      'fallbackSchemeUrl': fallbackSchemeUrl,
      'iconKey': iconKey,
      'colorValue': colorValue,
      'visible': visible,
      'order': order,
      'isBuiltIn': isBuiltIn,
    };
  }

  factory IdentityShortcut.fromJson(Map<String, dynamic> json) {
    return IdentityShortcut(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      schemeUrl: json['schemeUrl'] as String? ?? '',
      fallbackSchemeUrl: json['fallbackSchemeUrl'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? 'default',
      colorValue: json['colorValue'] as int? ?? 0xFF3B82F6,
      visible: json['visible'] as bool? ?? true,
      order: json['order'] as int? ?? 0,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  static List<IdentityShortcut> defaults() {
    return const [
      IdentityShortcut(
        id: 'taobao',
        name: '淘宝 / 菜鸟身份码',
        subtitle: '驿站扫码出库',
        schemeUrl:
            'taobao://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code%3Fx-ssr%3Dtrue',
        fallbackSchemeUrl:
            'tbopen://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code%3Fx-ssr%3Dtrue',
        iconKey: 'taobao',
        colorValue: 0xFFFF6A00,
        order: 0,
      ),
      IdentityShortcut(
        id: 'pinduoduo',
        name: '拼多多身份码',
        subtitle: '多多驿站一键亮码',
        schemeUrl:
            'pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE&entry_source=11&refer_page_name=login&refer_page_sn=10169',
        fallbackSchemeUrl:
            'pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE&entry_source=11',
        iconKey: 'pinduoduo',
        colorValue: 0xFFE02E24,
        order: 1,
      ),
      IdentityShortcut(
        id: 'taobao_pickup',
        name: '淘宝待取件',
        subtitle: '查看淘宝裹裹包裹',
        schemeUrl:
            'taobao://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F1100333%2Flast-mile-fe%2Fm-end-school-tab%2Fhome',
        fallbackSchemeUrl:
            'tbopen://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F1100333%2Flast-mile-fe%2Fm-end-school-tab%2Fhome',
        iconKey: 'taobao',
        colorValue: 0xFFEA580C,
        order: 2,
      ),
      IdentityShortcut(
        id: 'pdd_pickup',
        name: '拼多多待取件',
        subtitle: '查看多多驿站包裹',
        schemeUrl: 'pinduoduo://com.xunmeng.pinduoduo/mdkd/package',
        fallbackSchemeUrl:
            'pinduoduo://com.xunmeng.pinduoduo/psnl_goods_help.html?_t_module_name=assistant_search&refer_scene=express_box',
        iconKey: 'pinduoduo',
        colorValue: 0xFFDC2626,
        order: 3,
      ),
      IdentityShortcut(
        id: 'cainiao',
        name: '菜鸟待取件',
        subtitle: '打开菜鸟取件列表',
        schemeUrl: 'guoguo://go/pickup_page_native',
        fallbackSchemeUrl: 'guoguo://go/allpackage',
        iconKey: 'cainiao',
        colorValue: 0xFF1677FF,
        order: 4,
      ),
      IdentityShortcut(
        id: 'jd',
        name: '京东待收货',
        subtitle: '京东订单与物流',
        schemeUrl:
            'openjd://virtual?params=%7B%22category%22%3A%22jump%22%2C%22des%22%3A%22orderlist%22%7D',
        fallbackSchemeUrl:
            'weixin://dl/business/?appid=wx91d27dbf599dff74&path=pages/index/index',
        iconKey: 'jd',
        colorValue: 0xFFE1251B,
        order: 5,
      ),
      IdentityShortcut(
        id: 'douyin',
        name: '抖音订单',
        subtitle: '抖音商城查物流',
        schemeUrl: 'snssdk1128://ecom_order_list',
        fallbackSchemeUrl: 'snssdk2329://ecom_order_list',
        iconKey: 'douyin',
        colorValue: 0xFF111827,
        order: 6,
      ),
      IdentityShortcut(
        id: 'kuaishou',
        name: '快手订单',
        subtitle: '快手小店查物流',
        schemeUrl:
            'kwai://webview?url=https%3A%2F%2Fapp.kwaixiaodian.com%2Fpage%2Fkwaishop-trade-order-list-app%3FlayoutType%3D4%26hyId%3DkwaishopOrder',
        fallbackSchemeUrl:
            'ksnebula://webview?url=https%3A%2F%2Fapp.kwaixiaodian.com%2Fpage%2Fkwaishop-trade-order-list-app%3FlayoutType%3D4%26hyId%3DkwaishopOrder',
        iconKey: 'kuaishou',
        colorValue: 0xFFFF5000,
        order: 7,
      ),
      IdentityShortcut(
        id: 'dewu',
        name: '得物订单',
        subtitle: '得物包裹与物流',
        schemeUrl: 'dewuapp://m.dewu.com/router/order/buyer/orderList?tabId=0',
        fallbackSchemeUrl: 'dewuapp://',
        iconKey: 'dewu',
        colorValue: 0xFF06B6D4,
        order: 8,
        visible: false,
      ),
    ];
  }
}
