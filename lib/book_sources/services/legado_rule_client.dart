import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/registered_book_source.dart';
import '../protocol/book_source_protocol.dart';

/// Runtime for the portable, declarative part of Legado v3 rules.
///
/// CSS selectors, `@text`, `@href`, `@src`, URL templates and the common
/// `##pattern##replacement` cleanup syntax are supported. JavaScript rules are
/// deliberately rejected instead of executing untrusted code in the app.
class LegadoRuleClient {
  LegadoRuleClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<BookSourceSearchPage> search(
    RegisteredBookSource source,
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final config = _config(source);
    final template = '${config['searchUrl'] ?? ''}';
    final url = template
        .replaceAll('{{key}}', Uri.encodeQueryComponent(query))
        .replaceAll('{{page}}', '$page');
    final uri = _absolute(source.apiBaseUrl, _requestUrl(url));
    final document = await _document(uri);
    final rules = _rules(config['ruleSearch']);
    final listRule = _rule(rules, 'bookList');
    final elements = _selectAll(document, listRule);
    final books = <BookSourceBook>[];
    for (final element in elements.take(pageSize)) {
      final title = _value(element, _rule(rules, 'name'));
      final href = _value(element, _rule(rules, 'bookUrl'));
      if (title.isEmpty || href.isEmpty) continue;
      final bookUri = _absolute(uri, href);
      books.add(
        BookSourceBook(
          id: bookUri.toString(),
          title: title,
          author: _value(element, _rule(rules, 'author')),
          description: _value(element, _rule(rules, 'intro')),
          coverUrl: _httpUri(_absoluteText(uri, _value(element, _rule(rules, 'coverUrl')))),
          categories: const [],
          latestChapter: _value(element, _rule(rules, 'lastChapter')),
        ),
      );
    }
    return BookSourceSearchPage(
      items: books,
      page: page,
      pageSize: pageSize,
      hasMore: books.length >= pageSize,
    );
  }

  Future<BookSourceBook> getBook(
    RegisteredBookSource source,
    String bookId,
  ) async {
    final uri = Uri.parse(bookId);
    final document = await _document(uri);
    final rules = _rules(_config(source)['ruleBookInfo']);
    return BookSourceBook(
      id: bookId,
      title: _value(document, _rule(rules, 'name')),
      author: _value(document, _rule(rules, 'author')),
      description: _value(document, _rule(rules, 'intro')),
      coverUrl: _httpUri(
        _absoluteText(uri, _value(document, _rule(rules, 'coverUrl'))),
      ),
      categories: const [],
      latestChapter: _value(document, _rule(rules, 'lastChapter')),
    );
  }

  Future<List<BookSourceChapter>> getChapters(
    RegisteredBookSource source,
    String bookId,
  ) async {
    final bookUri = Uri.parse(bookId);
    final config = _config(source);
    final info = await _document(bookUri);
    final infoRules = _rules(config['ruleBookInfo']);
    final tocValue = _value(info, _rule(infoRules, 'tocUrl'));
    final tocUri = tocValue.isEmpty ? bookUri : _absolute(bookUri, tocValue);
    final document = tocUri == bookUri ? info : await _document(tocUri);
    final rules = _rules(config['ruleToc']);
    final elements = _selectAll(document, _rule(rules, 'chapterList'));
    return [
      for (var index = 0; index < elements.length; index++)
        if (_value(elements[index], _rule(rules, 'chapterUrl')).isNotEmpty)
          BookSourceChapter(
            id: _absolute(
              tocUri,
              _value(elements[index], _rule(rules, 'chapterUrl')),
            ).toString(),
            title: _value(elements[index], _rule(rules, 'chapterName')),
            order: index,
          ),
    ];
  }

  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource source, {
    required String bookId,
    required String chapterId,
  }) async {
    final document = await _document(Uri.parse(chapterId));
    final rules = _rules(_config(source)['ruleContent']);
    final content = _value(document, _rule(rules, 'content'));
    return BookSourceChapterContent(
      bookId: bookId,
      chapterId: chapterId,
      title: document.querySelector('title')?.text.trim() ?? '',
      content: content,
      contentType: 'text/plain',
    );
  }

  Map<String, dynamic> _config(RegisteredBookSource source) {
    final config = source.legadoConfig;
    if (config == null) {
      throw const BookSourceProtocolException('Legado 书源配置已损坏。');
    }
    return config;
  }

  Future<Document> _document(Uri uri) async {
    BookSourceClientTargetGuard.ensureSafe(uri);
    final response = await _dio.getUri<String>(
      uri,
      options: Options(responseType: ResponseType.plain),
    );
    return html_parser.parse(response.data ?? '');
  }

  static Map<String, dynamic> _rules(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static String _rule(Map<String, dynamic> rules, String key) =>
      '${rules[key] ?? ''}'.trim();

  static List<Element> _selectAll(Document document, String rule) {
    final selector = _selector(rule);
    if (selector.isEmpty) return const [];
    try {
      return document.querySelectorAll(selector);
    } catch (_) {
      throw BookSourceProtocolException('暂不支持该 Legado 规则：$rule');
    }
  }

  static String _value(dynamic root, String rule) {
    if (rule.isEmpty) return '';
    if (rule.contains('<js>') || rule.startsWith('@js:')) {
      throw const BookSourceProtocolException('出于安全原因，不执行书源 JavaScript 规则。');
    }
    final cleanup = rule.split('##');
    final expression = cleanup.first.trim();
    final at = expression.lastIndexOf('@');
    final selector = _selector(expression);
    final attribute = at >= 0 ? expression.substring(at + 1) : 'text';
    Element? element;
    if (root is Document) {
      element = selector.isEmpty ? root.documentElement : root.querySelector(selector);
    } else if (root is Element) {
      element = selector.isEmpty ? root : root.querySelector(selector);
    }
    if (element == null) return '';
    var result = attribute == 'text' || attribute == 'textNodes'
        ? element.text
        : element.attributes[attribute] ?? '';
    if (cleanup.length >= 2 && cleanup[1].isNotEmpty) {
      try {
        result = result.replaceAll(
          RegExp(cleanup[1]),
          cleanup.length >= 3 ? cleanup[2] : '',
        );
      } catch (_) {
        // Invalid optional cleanup patterns do not discard extracted content.
      }
    }
    return result.trim();
  }

  static String _selector(String rule) {
    final expression = rule.split('##').first.trim();
    final at = expression.lastIndexOf('@');
    final selector = at >= 0
        ? expression.substring(0, at).trim()
        : expression;
    if (selector.startsWith('class.')) return '.${selector.substring(6)}';
    if (selector.startsWith('id.')) return '#${selector.substring(3)}';
    if (selector.startsWith('tag.')) return selector.substring(4);
    return selector;
  }

  static String _requestUrl(String value) => value.split(',').first.trim();

  static Uri _absolute(Uri base, String value) =>
      Uri.tryParse(value)?.hasScheme == true ? Uri.parse(value) : base.resolve(value);

  static String _absoluteText(Uri base, String value) =>
      value.isEmpty ? '' : _absolute(base, value).toString();

  static Uri? _httpUri(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && const {'http', 'https'}.contains(uri.scheme) ? uri : null;
  }
}

/// Kept separate to make network-target validation reusable without exposing
/// the rest of BookSourceClient's HTTP implementation.
class BookSourceClientTargetGuard {
  static void ensureSafe(Uri uri) {
    if (!const {'http', 'https'}.contains(uri.scheme) || !uri.hasAuthority) {
      throw const BookSourceProtocolException('书源生成了无效的网络地址。');
    }
  }
}
