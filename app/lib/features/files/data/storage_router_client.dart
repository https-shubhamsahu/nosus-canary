import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/storage_router_config.dart';
import '../../../config/supabase_credentials.dart';

class StorageRouterUploadResult {
  final String fileId;
  final String provider;
  final String bucket;
  final String objectKey;
  final int sizeBytes;

  const StorageRouterUploadResult({
    required this.fileId,
    required this.provider,
    required this.bucket,
    required this.objectKey,
    required this.sizeBytes,
  });

  factory StorageRouterUploadResult.fromJson(Map<String, dynamic> json) {
    return StorageRouterUploadResult(
      fileId: json['file_id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      bucket: json['bucket']?.toString() ?? '',
      objectKey: json['object_key']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class StorageRouterClient {
  StorageRouterClient._();
  static final StorageRouterClient instance = StorageRouterClient._();

  String get _baseUrl =>
      '${SupabaseCredentials.url}/functions/v1/${StorageRouterConfig.edgeFunctionName}';

  Future<StorageRouterUploadResult> upload({
    required String fileId,
    required String groupId,
    required String name,
    required String type,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uri = Uri.parse('$_baseUrl/upload').replace(
      queryParameters: {
        'fileId': fileId,
        'groupId': groupId,
        'name': name,
        'type': type,
        'contentType': contentType,
      },
    );

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${_accessToken()}',
        'Content-Type': contentType,
      },
      body: bytes,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Storage router upload failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return StorageRouterUploadResult.fromJson(data);
  }

  Future<Uint8List> download(String fileId) async {
    final uri = Uri.parse('$_baseUrl/download').replace(
      queryParameters: {'fileId': fileId},
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${_accessToken()}'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Storage router download failed (${res.statusCode}): ${res.body}');
    }
    return res.bodyBytes;
  }

  Future<void> delete(String fileId) async {
    final uri = Uri.parse('$_baseUrl/delete').replace(
      queryParameters: {'fileId': fileId},
    );
    final res = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer ${_accessToken()}'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Storage router delete failed (${res.statusCode}): ${res.body}');
    }
  }

  String _accessToken() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Storage router requires an authenticated session.');
    }
    return token;
  }
}
