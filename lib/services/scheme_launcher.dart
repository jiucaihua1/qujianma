import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/identity_shortcut.dart';

enum SchemeLaunchStatus {
  launchedPrimary,
  launchedFallback,
  failed,
}

class SchemeLauncher {
  static const MethodChannel _channel =
      MethodChannel('com.qujianma.qujianma/quick_tile');

  static const Map<String, String> _knownPackages = {
    'cainiao': 'com.cainiao.wireless',
    'taobao': 'com.taobao.taobao',
    'taobao_pickup': 'com.taobao.taobao',
    'pinduoduo': 'com.xunmeng.pinduoduo',
    'pdd_pickup': 'com.xunmeng.pinduoduo',
    'jd': 'com.jingdong.app.mall',
    'douyin': 'com.ss.android.ugc.aweme',
    'kuaishou': 'com.smile.gifmaker',
    'dewu': 'com.shizhuang.duapp',
    'wechat_scan': 'com.tencent.mm',
    'fcbox': 'com.fcbox.hivebox',
    'sf': 'com.sf.activity',
  };

  static Future<SchemeLaunchStatus> launchShortcut(
    IdentityShortcut shortcut,
  ) async {
    // Prefer native Android Intent(ACTION_VIEW) + package fallback so routes with
    // CATEGORY_DEFAULT (like Cainiao's guoguo://go/quick_pick_qrcode) work cleanly.
    try {
      final res = await _channel.invokeMethod<String>(
        'launchExternalUrl',
        {
          'primaryUrl': shortcut.schemeUrl.trim(),
          'fallbackUrl': shortcut.fallbackSchemeUrl.trim(),
          'fallbackPackage': _knownPackages[shortcut.id] ?? '',
        },
      );
      if (res == 'primary') return SchemeLaunchStatus.launchedPrimary;
      if (res == 'fallback') return SchemeLaunchStatus.launchedFallback;
      if (res == 'failed') return SchemeLaunchStatus.failed;
    } on MissingPluginException {
      // Fall through to url_launcher on non-Android platforms or tests.
    } on PlatformException {
      // Fall through to url_launcher.
    }

    if (await _tryLaunch(shortcut.schemeUrl)) {
      return SchemeLaunchStatus.launchedPrimary;
    }
    if (shortcut.fallbackSchemeUrl.isNotEmpty &&
        await _tryLaunch(shortcut.fallbackSchemeUrl)) {
      return SchemeLaunchStatus.launchedFallback;
    }
    return SchemeLaunchStatus.failed;
  }

  static Future<bool> _tryLaunch(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
