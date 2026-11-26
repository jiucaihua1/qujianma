import 'dart:convert';
import 'dart:io';

import '../models/parser_rule_bundle.dart';

class RuleSyncResult {
  const RuleSyncResult({
    required this.bundle,
    required this.syncedAt,
  });

  final ParserRuleBundle bundle;
  final String syncedAt;
}

class RuleSyncService {
  const RuleSyncService();

  Future<RuleSyncResult> fetchFromUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      throw const FormatException('请输入有效的 http:// 或 https:// 规则文件地址');
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json, text/plain');
      final response = await request.close().timeout(
            const Duration(seconds: 12),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          '服务器返回状态码 ${response.statusCode}',
          uri: uri,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('规则文件格式错误：根节点必须是 JSON 对象');
      }
      final bundle = ParserRuleBundle.fromJson(decoded);
      final now = DateTime.now();
      final syncedAt =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      return RuleSyncResult(bundle: bundle, syncedAt: syncedAt);
    } finally {
      client.close(force: true);
    }
  }
}
