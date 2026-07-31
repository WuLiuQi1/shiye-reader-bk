import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/services/book_source_registry.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/core/database_service.dart';

class ICloudBackupInfo {
  const ICloudBackupInfo({required this.createdAt, required this.bookCount});

  final DateTime createdAt;
  final int bookCount;
}

class ICloudBackupService {
  static const _channel = MethodChannel('com.niki.xxread/icloud_backup');
  static const _progressPrefix = 'book_source_reading_progress_v1:';

  Future<bool> get isAvailable async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    return await _channel.invokeMethod<bool>('isAvailable') ?? false;
  }

  Future<ICloudBackupInfo> backup() async {
    if (!await isAvailable) {
      throw StateError('iCloud 当前不可用，请确认已在 iPhone 登录 iCloud。');
    }
    final sources = await BookSourceRegistry().load();
    final books = await BookDao().getAllBooks();
    final preferences = await SharedPreferences.getInstance();
    final progress = <String, String>{};
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(_progressPrefix)) continue;
      final value = preferences.getString(key);
      if (value != null) progress[key] = value;
    }
    final now = DateTime.now().toUtc();
    final payload = jsonEncode({
      'version': 1,
      'createdAt': now.toIso8601String(),
      'sources': sources.map((source) => source.toJson()).toList(),
      'books': books.map(_backupBook).toList(),
      'readingProgress': progress,
    });
    await _channel.invokeMethod<void>('writeBackup', {'payload': payload});
    return ICloudBackupInfo(createdAt: now, bookCount: books.length);
  }

  Future<ICloudBackupInfo?> backupInfo() async {
    if (!await isAvailable) return null;
    final payload = await _channel.invokeMethod<String>('readBackup');
    if (payload == null || payload.isEmpty) return null;
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return null;
    final createdAt = DateTime.tryParse('${decoded['createdAt']}');
    if (createdAt == null) return null;
    return ICloudBackupInfo(
      createdAt: createdAt,
      bookCount: (decoded['books'] as List?)?.length ?? 0,
    );
  }

  Future<ICloudBackupInfo> restore() async {
    if (!await isAvailable) {
      throw StateError('iCloud 当前不可用，请确认已在 iPhone 登录 iCloud。');
    }
    final payload = await _channel.invokeMethod<String>('readBackup');
    if (payload == null || payload.isEmpty) {
      throw StateError('iCloud 中还没有 Open Reading 备份。');
    }
    final decoded = jsonDecode(payload);
    if (decoded is! Map || decoded['version'] != 1) {
      throw const FormatException('备份格式无法识别。');
    }
    final sources = <RegisteredBookSource>[];
    for (final item in (decoded['sources'] as List? ?? const [])) {
      if (item is Map) {
        sources.add(
          RegisteredBookSource.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        );
      }
    }
    await BookSourceRegistry().replaceAll(sources);

    final db = await DatabaseService().database;
    final books = (decoded['books'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
    await db.transaction((transaction) async {
      await transaction.delete('books');
      for (final book in books) {
        book.remove('id');
        await transaction.insert('books', book);
      }
    });

    final preferences = await SharedPreferences.getInstance();
    for (final key in preferences.getKeys().where(
      (key) => key.startsWith(_progressPrefix),
    )) {
      await preferences.remove(key);
    }
    final progress = decoded['readingProgress'];
    if (progress is Map) {
      for (final entry in progress.entries) {
        if ('$entry.key'.startsWith(_progressPrefix) &&
            entry.value is String) {
          await preferences.setString('${entry.key}', entry.value as String);
        }
      }
    }
    final createdAt =
        DateTime.tryParse('${decoded['createdAt']}') ?? DateTime.now().toUtc();
    return ICloudBackupInfo(createdAt: createdAt, bookCount: books.length);
  }

  Map<String, dynamic> _backupBook(Book book) {
    final map = Map<String, dynamic>.from(book.toMap());
    map['cached_content'] = null;
    map['cached_pages'] = null;
    map['cover_image_path'] = null;
    return map;
  }
}
