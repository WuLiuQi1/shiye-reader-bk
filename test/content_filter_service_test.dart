import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/services/reading/content_filter_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('default rules remove urls and common garbled text', () {
    const service = ContentFilterService();
    final result = service.apply(
      '正文 https://spam.example/a\n锟斤拷锟斤拷\n下一段',
      ContentFilterService.defaultRules,
    );
    expect(result, contains('正文'));
    expect(result, contains('下一段'));
    expect(result, isNot(contains('https://')));
    expect(result, isNot(contains('锟斤拷')));
  });

  test('supports literal replacement and ignores invalid regex rules', () {
    const service = ContentFilterService();
    final result = service.apply('广告 正文', const [
      ContentFilterRule(
        id: 'literal',
        name: '替换',
        pattern: '广告',
        replacement: '[已过滤]',
        isRegex: false,
      ),
      ContentFilterRule(id: 'broken', name: '损坏规则', pattern: '['),
    ]);
    expect(result, '[已过滤] 正文');
  });

  test('persists custom rules and enabled state', () async {
    const service = ContentFilterService();
    const rules = [
      ContentFilterRule(
        id: 'custom',
        name: '自定义',
        pattern: '测试',
        enabled: false,
      ),
    ];
    await service.save(rules);
    final restored = await service.load();
    expect(restored.single.id, 'custom');
    expect(restored.single.enabled, isFalse);
  });
}
