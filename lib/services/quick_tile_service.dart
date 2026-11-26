import 'package:flutter/services.dart';

class QuickTileStatus {
  const QuickTileStatus({
    this.accessibilityEnabled = false,
    this.accessibilityRunning = false,
    this.notificationEnabled = false,
    this.supportsRequestAddTile = false,
    this.supportsTakeScreenshot = false,
    this.shizukuRunning = false,
    this.shizukuAuthorized = false,
  });

  final bool accessibilityEnabled;
  final bool accessibilityRunning;
  final bool notificationEnabled;
  final bool supportsRequestAddTile;
  final bool supportsTakeScreenshot;
  final bool shizukuRunning;
  final bool shizukuAuthorized;

  bool get isReady =>
      (accessibilityRunning || shizukuAuthorized) && notificationEnabled;
}

class QuickTileService {
  QuickTileService._();

  static const MethodChannel _channel =
      MethodChannel('com.qujianma.qujianma/quick_tile');

  static const String actionOpenPickupTab = 'open_pickup_tab';
  static const String actionOpenTileSetup = 'open_tile_setup';
  static const String actionOpenDefaultTab = 'open_default_tab';

  static void setCallbacks({
    VoidCallback? onDatabaseChanged,
    ValueChanged<String>? onLaunchAction,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDatabaseChanged':
          onDatabaseChanged?.call();
          break;
        case 'onLaunchAction':
          final action = call.arguments as String?;
          if (action != null && action.isNotEmpty) {
            onLaunchAction?.call(action);
          }
          break;
      }
    });
  }

  static Future<QuickTileStatus> getStatus() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getQuickTileStatus',
      );
      if (raw == null) return const QuickTileStatus();
      return QuickTileStatus(
        accessibilityEnabled: raw['accessibilityEnabled'] == true,
        accessibilityRunning: raw['accessibilityRunning'] == true,
        notificationEnabled: raw['notificationEnabled'] == true,
        supportsRequestAddTile: raw['supportsRequestAddTile'] == true,
        supportsTakeScreenshot: raw['supportsTakeScreenshot'] == true,
        shizukuRunning: raw['shizukuRunning'] == true,
        shizukuAuthorized: raw['shizukuAuthorized'] == true,
      );
    } on MissingPluginException {
      return const QuickTileStatus();
    } on PlatformException {
      return const QuickTileStatus();
    }
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return granted == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (_) {}
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod<void>('openAccessibilitySettings');
    } catch (_) {}
  }

  static Future<void> openAppDetailsSettings() async {
    try {
      await _channel.invokeMethod<void>('openAppDetailsSettings');
    } catch (_) {}
  }

  static Future<bool> requestShizukuPermission() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestShizukuPermission');
      return granted == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> restoreAccessibilityWithShizuku() async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'restoreAccessibilityWithShizuku',
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Returns 'added', 'already_added', 'not_added', or 'unsupported'.
  static Future<String> requestAddQuickTile() async {
    try {
      final res = await _channel.invokeMethod<String>('requestAddQuickTile');
      return res ?? 'unsupported';
    } catch (_) {
      return 'unsupported';
    }
  }

  static Future<String?> consumeLaunchAction() async {
    try {
      return await _channel.invokeMethod<String>('consumeLaunchAction');
    } catch (_) {
      return null;
    }
  }

  /// Starts a timed floating-capsule auto-scan session and jumps to the target app.
  /// Returns 'started', 'need_accessibility', or 'launch_failed'.
  static Future<String> startGuidedScanSession({
    required String targetName,
    required String primaryUrl,
    String fallbackUrl = '',
    String fallbackPackage = '',
  }) async {
    try {
      final res = await _channel.invokeMethod<String>(
        'startGuidedScanSession',
        {
          'targetName': targetName,
          'primaryUrl': primaryUrl,
          'fallbackUrl': fallbackUrl,
          'fallbackPackage': fallbackPackage,
        },
      );
      return res ?? 'launch_failed';
    } catch (_) {
      return 'launch_failed';
    }
  }

  static Future<String> getAppVersion() async {
    try {
      final version = await _channel.invokeMethod<String>('getAppVersion');
      if (version != null && version.trim().isNotEmpty) {
        return version.trim();
      }
    } catch (_) {}
    return '0.1.0';
  }

  static Future<void> scheduleDailyReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'scheduleDailyReminder',
        {
          'enabled': enabled,
          'hour': hour,
          'minute': minute,
        },
      );
    } catch (_) {
      // Ignore on non-Android platforms or tests.
    }
  }

  static Future<bool> shareText({
    required String text,
    String subject = '待取快递清单',
  }) async {
    try {
      return (await _channel.invokeMethod<bool>(
            'shareText',
            {'text': text, 'subject': subject},
          )) ==
          true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> shareImage({
    required Uint8List bytes,
    String title = '待取快递清单',
  }) async {
    try {
      return (await _channel.invokeMethod<bool>(
            'shareImage',
            {'bytes': bytes, 'title': title},
          )) ==
          true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> checkSmsPermission() async {
    try {
      return (await _channel.invokeMethod<bool>('checkSmsPermission')) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestSmsPermission() async {
    try {
      return (await _channel.invokeMethod<bool>('requestSmsPermission')) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<SmsBackfillResult?> scanSmsInbox({required int days}) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'scanSmsInbox',
      {'days': days},
    );
    if (raw == null) return null;
    final codesRaw = raw['insertedCodes'];
    final codes = codesRaw is List
        ? codesRaw.map((e) => e.toString()).toList()
        : const <String>[];
    return SmsBackfillResult(
      scannedCount: (raw['scannedCount'] as int?) ?? 0,
      matchedCount: (raw['matchedCount'] as int?) ?? 0,
      insertedCount: (raw['insertedCount'] as int?) ?? 0,
      skippedCount: (raw['skippedCount'] as int?) ?? 0,
      insertedCodes: codes,
    );
  }
}

class SmsBackfillResult {
  const SmsBackfillResult({
    required this.scannedCount,
    required this.matchedCount,
    required this.insertedCount,
    required this.skippedCount,
    required this.insertedCodes,
  });

  final int scannedCount;
  final int matchedCount;
  final int insertedCount;
  final int skippedCount;
  final List<String> insertedCodes;
}
