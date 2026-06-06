import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pixez/sync/sync_config.dart';

class SyncAuthService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<Map<String, dynamic>> register(
    SyncConfig config,
    String username,
    String password,
  ) async {
    final url = '${config.serverUrl}/api/auth/register';
    final response = await _dio.post(url, data: {
      'username': username,
      'password': password,
    });
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> login(
    SyncConfig config,
    String username,
    String password,
  ) async {
    final url = '${config.serverUrl}/api/auth/login';
    final response = await _dio.post(url, data: {
      'username': username,
      'password': password,
    });
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> refreshToken(SyncConfig config) async {
    final url = '${config.serverUrl}/api/auth/refresh';
    final response = await _dio.post(
      url,
      options: Options(headers: config.authHeaders),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> deleteAccount(SyncConfig config) async {
    final url = '${config.serverUrl}/api/auth/account';
    final response = await _dio.delete(
      url,
      options: Options(headers: config.authHeaders),
    );
    return _parseResponse(response);
  }

  Map<String, dynamic> _parseResponse(Response response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      if (body['ok'] != true) {
        throw Exception(body['error'] ?? 'Unknown error');
      }
      return body['data'] ?? {};
    }
    throw Exception('Invalid response format');
  }
}
