import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ContentFilterRule {
  const ContentFilterRule({
    required this.id,
    required this.name,
    required this.pattern,
    this.replacement = '',
    this.isRegex = true,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String pattern;
  final String replacement;
  final bool isRegex;
  final bool enabled;

  ContentFilterRule copyWith({
    String? name,
    String? pattern,
    String? replacement,
    bool? isRegex,
    bool? enabled,
  }) => ContentFilterRule(
    id: id,
    name: name ?? this.name,
    pattern: pattern ?? this.pattern,
    replacement: replacement ?? this.replacement,
    isRegex: isRegex ?? this.isRegex,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pattern': pattern,
    'replacement': replacement,
    'isRegex': isRegex,
    'enabled': enabled,
  };

  factory ContentFilterRule.fromJson(Map<String, dynamic> json) =>
      ContentFilterRule(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        pattern: '${json['pattern'] ?? ''}',
        replacement: '${json['replacement'] ?? ''}',
        isRegex: json['isRegex'] != false,
        enabled: json['enabled'] != false,
      );
}

class ContentFilterService {
  const ContentFilterService();

  static const preferenceKey = 'readerContentFilterRulesV1';

  static const defaultRules = <ContentFilterRule>[
    ContentFilterRule(
      id: 'default-url',
      name: '网址链接',
      pattern: r'\b(?:https?://|HTTPS?://|www\.|WWW\.)[^\s，。；、）】》]+',
    ),
    ContentFilterRule(
      id: 'default-domain',
      name: '常见域名广告',
      pattern: r'\b[A-Za-z0-9][A-Za-z0-9.-]*\.(?:com|COM|net|NET|org|ORG|cn|CN|top|TOP|xyz|XYZ)\b[^\s，。；、）】》]*',
    ),
    ContentFilterRule(
      id: 'default-garbled',
      name: '乱码占位符',
      pattern: r'(?:�{2,}|(?:锟斤拷){2,}|(?:\\uFFFD){2,})',
    ),
  ];

  Future<List<ContentFilterRule>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(preferenceKey);
    if (raw == null) return defaultRules;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return defaultRules;
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                ContentFilterRule.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((rule) => rule.id.isNotEmpty && rule.pattern.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return defaultRules;
    }
  }

  Future<void> save(List<ContentFilterRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      preferenceKey,
      jsonEncode(rules.map((rule) => rule.toJson()).toList()),
    );
  }

  String apply(String text, Iterable<ContentFilterRule> rules) {
    var result = text;
    for (final rule in rules) {
      if (!rule.enabled || rule.pattern.isEmpty) continue;
      try {
        result = rule.isRegex
            ? result.replaceAll(RegExp(rule.pattern), rule.replacement)
            : result.replaceAll(rule.pattern, rule.replacement);
      } catch (_) {
        // A malformed user rule is ignored so chapter loading never fails.
      }
    }
    return result
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }
}
