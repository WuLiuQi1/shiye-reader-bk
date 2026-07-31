import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/book_sources/services/legado_source_importer.dart';
import 'package:xxread/book_sources/services/book_source_exporter.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';

void main() {
  test('imports Legado/阅读 source arrays and preserves rules', () {
    const json = '''
[
  {
    "bookSourceName": "测试书源",
    "bookSourceUrl": "https://example.org",
    "searchUrl": "/search?q={{key}}&page={{page}}",
    "ruleSearch": {
      "bookList": ".result",
      "name": ".title@text",
      "bookUrl": ".title@href"
    },
    "ruleToc": {
      "chapterList": ".chapter",
      "chapterName": "@text",
      "chapterUrl": "@href"
    }
  }
]
''';

    final sources = const LegadoSourceImporter().parse(json);

    expect(sources, hasLength(1));
    expect(sources.single.name, '测试书源');
    expect(sources.single.protocolVersion, 'legado-v3');
    expect(sources.single.capabilities, contains('search'));
    expect(
      (sources.single.legadoConfig!['ruleSearch'] as Map)['name'],
      '.title@text',
    );
  });

  test('rejects entries without usable source and search URLs', () {
    expect(
      () => const LegadoSourceImporter().parse(
        '[{"bookSourceName":"broken"}]',
      ),
      throwsA(anything),
    );
  });

  test('exported native and Legado sources can be imported again', () {
    final native = RegisteredBookSource(
      id: 'org.example.native',
      name: '原生书源',
      description: '测试',
      manifestUrl: Uri.parse('https://example.org/source.json'),
      apiBaseUrl: Uri.parse('https://example.org/api/'),
      protocolVersion: '1.0',
      languages: const ['zh'],
      capabilities: const {'search'},
      enabled: false,
      addedAt: DateTime.utc(2026, 7, 31),
    );
    final legado = RegisteredBookSource(
      id: 'legado-test',
      name: '阅读书源',
      description: '测试',
      manifestUrl: Uri.parse('https://books.example.com'),
      apiBaseUrl: Uri.parse('https://books.example.com'),
      protocolVersion: 'legado-v3',
      languages: const ['zh'],
      capabilities: const {'search'},
      enabled: false,
      addedAt: DateTime.utc(2026, 7, 31),
      legadoConfig: const {
        'bookSourceName': '阅读书源',
        'bookSourceUrl': 'https://books.example.com',
        'searchUrl': '/search?q={{key}}',
        'enabled': true,
      },
    );

    final json = const BookSourceExporter().encode([native, legado]);
    final restored = const LegadoSourceImporter().parse(json);

    expect(restored, hasLength(2));
    expect(restored.first.id, native.id);
    expect(restored.first.enabled, isFalse);
    expect(restored.last.legadoConfig?['enabled'], isFalse);
  });
}
