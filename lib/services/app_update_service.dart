import 'dart:convert';
import 'dart:io';

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.hasUpdate,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.pageUrl,
  });

  final String latestVersion;
  final String currentVersion;
  final bool hasUpdate;
  final String releaseNotes;
  final String downloadUrl;
  final String pageUrl;
}

class AppUpdateService {
  const AppUpdateService();

  static const String latestReleaseApiUrl =
      'https://api.github.com/repos/jiucaihua1/qujianma/releases/latest';

  static List<int> _parseSemver(String raw) {
    final cleaned = raw.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final parts = cleaned.split('.');
    return List<int>.generate(
      3,
      (i) => i < parts.length
          ? (int.tryParse(parts[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          : 0,
    );
  }

  static bool isNewerVersion(String latest, String current) {
    final a = _parseSemver(latest);
    final b = _parseSemver(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return false;
  }

  Future<AppReleaseInfo> checkForUpdate({
    required String currentVersion,
  }) async {
    final uri = Uri.parse(latestReleaseApiUrl);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'qujianma-app');
      final response = await request.close().timeout(
            const Duration(seconds: 12),
          );
      if (response.statusCode == 404) {
        return AppReleaseInfo(
          latestVersion: currentVersion,
          currentVersion: currentVersion,
          hasUpdate: false,
          releaseNotes: '',
          downloadUrl: '',
          pageUrl: 'https://github.com/jiucaihua1/qujianma/releases',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('GitHub API 返回状态码 ${response.statusCode}', uri: uri);
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Release 数据格式异常');
      }

      final tag = (decoded['tag_name'] as String?)?.trim() ?? '';
      final notes = (decoded['body'] as String?)?.trim() ?? '';
      final htmlUrl = (decoded['html_url'] as String?)?.trim() ??
          'https://github.com/jiucaihua1/qujianma/releases';

      var apkUrl = '';
      final assets = decoded['assets'];
      if (assets is List) {
        for (final asset in assets.whereType<Map<String, dynamic>>()) {
          final name = (asset['name'] as String?)?.toLowerCase() ?? '';
          final url = (asset['browser_download_url'] as String?)?.trim() ?? '';
          if (name.endsWith('.apk') && url.isNotEmpty) {
            apkUrl = url;
            break;
          }
        }
      }

      final latest = tag.isEmpty ? currentVersion : tag;
      return AppReleaseInfo(
        latestVersion: latest,
        currentVersion: currentVersion,
        hasUpdate: isNewerVersion(latest, currentVersion),
        releaseNotes: notes,
        downloadUrl: apkUrl.isNotEmpty ? apkUrl : htmlUrl,
        pageUrl: htmlUrl,
      );
    } finally {
      client.close(force: true);
    }
  }
}
