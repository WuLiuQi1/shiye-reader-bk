import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/registered_book_source.dart';
import '../protocol/book_source_protocol.dart';
import 'legado_source_importer.dart';

class LegadoSourceUrlImporter {
  LegadoSourceUrlImporter({Dio? dio}) : _dio = dio ?? Dio();

  static const maxBytes = 5 * 1024 * 1024;
  final Dio _dio;

  Future<List<RegisteredBookSource>> load(Uri uri) async {
    if (!uri.hasAuthority || !const {'http', 'https'}.contains(uri.scheme)) {
      throw const BookSourceProtocolException('请输入有效的 HTTP(S) 书源地址。');
    }
    try {
      final response = await _dio.get<List<int>>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 20),
          followRedirects: true,
          maxRedirects: 5,
          headers: const {'accept': 'application/json,text/plain;q=0.9'},
        ),
      );
      final bytes = response.data ?? const <int>[];
      if (bytes.isEmpty) {
        throw const BookSourceProtocolException('网址没有返回书源内容。');
      }
      if (bytes.length > maxBytes) {
        throw const BookSourceProtocolException('书源文件超过 5 MB，已停止导入。');
      }
      return const LegadoSourceImporter().parse(
        utf8.decode(bytes, allowMalformed: false),
      );
    } on BookSourceProtocolException {
      rethrow;
    } on FormatException {
      throw const BookSourceProtocolException('网址返回的内容不是有效的 UTF-8 JSON。');
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      throw BookSourceProtocolException(
        code == null ? '无法下载书源，请检查网络和地址。' : '下载书源失败（HTTP $code）。',
      );
    }
  }
}
