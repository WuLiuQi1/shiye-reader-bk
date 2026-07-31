import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/registered_book_source.dart';
import '../protocol/book_source_protocol.dart';

/// Imports the JSON format used by Legado/阅读.
///
/// The original rule object is retained verbatim so newer compatible rule
/// fields are not lost when the registry is saved and loaded again.
class LegadoSourceImporter {
  const LegadoSourceImporter();

  List<RegisteredBookSource> parse(String input) {
    Object? decoded;
    try {
      decoded = jsonDecode(input);
    } on FormatException {
      throw const BookSourceProtocolException('书源文件不是有效的 JSON。');
    }
    final rawItems = decoded is List
        ? decoded
        : decoded is Map && decoded['bookSourceUrl'] != null
        ? [decoded]
        : decoded is Map && decoded['sources'] is List
        ? decoded['sources'] as List
        : const [];
    if (rawItems.isEmpty) {
      throw const BookSourceProtocolException('没有找到 Legado/阅读书源。');
    }

    final sources = <RegisteredBookSource>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final json = Map<String, dynamic>.from(raw);
      final base = Uri.tryParse('${json['bookSourceUrl'] ?? ''}'.trim());
      final searchUrl = '${json['searchUrl'] ?? ''}'.trim();
      if (base == null ||
          !base.hasAuthority ||
          !const {'http', 'https'}.contains(base.scheme) ||
          searchUrl.isEmpty) {
        continue;
      }
      final name = '${json['bookSourceName'] ?? base.host}'.trim();
      final digest = sha256.convert(utf8.encode(base.toString())).toString();
      sources.add(
        RegisteredBookSource(
          id: 'legado-${digest.substring(0, 24)}',
          name: name.isEmpty ? base.host : name,
          description: '${json['bookSourceGroup'] ?? 'Legado/阅读书源'}',
          manifestUrl: base,
          apiBaseUrl: base,
          protocolVersion: 'legado-v3',
          languages: const ['zh'],
          capabilities: const {'search'},
          enabled: json['enabled'] != false,
          addedAt: DateTime.now(),
          legadoConfig: json,
        ),
      );
    }
    if (sources.isEmpty) {
      throw const BookSourceProtocolException(
        '书源缺少有效的 bookSourceUrl 或 searchUrl。',
      );
    }
    return sources;
  }
}
