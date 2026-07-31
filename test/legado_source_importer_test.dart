import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/book_sources/services/legado_source_importer.dart';

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
}
