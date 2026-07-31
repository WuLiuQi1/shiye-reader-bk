import 'dart:convert';

import '../models/registered_book_source.dart';

/// Serializes saved sources to a JSON file that can be imported again.
///
/// Legado sources retain their original rule objects so the exported file also
/// remains compatible with Legado/阅读. Native ORSP sources use the app's
/// lossless registered-source representation.
class BookSourceExporter {
  const BookSourceExporter();

  String encode(Iterable<RegisteredBookSource> sources) {
    final records = sources.map((source) {
      final legado = source.legadoConfig;
      if (legado == null) return source.toJson();
      return <String, dynamic>{...legado, 'enabled': source.enabled};
    }).toList(growable: false);
    return const JsonEncoder.withIndent('  ').convert(records);
  }
}
