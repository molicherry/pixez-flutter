import 'dart:convert';

import 'package:mobx/mobx.dart';
import 'package:pixez/er/prefer.dart';

part 'sync_config.g.dart';

class SyncConfig = _SyncConfigBase with _$SyncConfig;

abstract class _SyncConfigBase with Store {
  static const String KEY_ENABLED = 'sync_enabled';
  static const String KEY_SERVER_URL = 'sync_server_url';
  static const String KEY_USERNAME = 'sync_username';
  static const String KEY_TOKEN = 'sync_token';
  static const String KEY_LAST_SYNC = 'sync_last_sync';

  @observable
  bool enabled = false;

  @observable
  String serverUrl = '';

  @observable
  String username = '';

  @observable
  String token = '';

  @observable
  int lastSyncTimestamp = 0;

  @observable
  bool isSyncing = false;

  @observable
  String? lastSyncError;

  @action
  Future<void> init() async {
    await Prefer.init();
    enabled = Prefer.getBool(KEY_ENABLED) ?? false;
    serverUrl = Prefer.getString(KEY_SERVER_URL) ?? '';
    username = Prefer.getString(KEY_USERNAME) ?? '';
    token = Prefer.getString(KEY_TOKEN) ?? '';
    lastSyncTimestamp = Prefer.getInt(KEY_LAST_SYNC) ?? 0;
  }

  @action
  Future<void> setEnabled(bool value) async {
    await Prefer.setBool(KEY_ENABLED, value);
    enabled = value;
  }

  @action
  Future<void> setServerUrl(String value) async {
    await Prefer.setString(KEY_SERVER_URL, value.trim());
    serverUrl = value.trim();
  }

  @action
  Future<void> setCredentials(String user, String tok) async {
    await Prefer.setString(KEY_USERNAME, user);
    await Prefer.setString(KEY_TOKEN, tok);
    username = user;
    token = tok;
  }

  @action
  Future<void> clearCredentials() async {
    await Prefer.remove(KEY_USERNAME);
    await Prefer.remove(KEY_TOKEN);
    await Prefer.setBool(KEY_ENABLED, false);
    username = '';
    token = '';
    enabled = false;
  }

  @action
  Future<void> updateLastSync(int timestamp) async {
    await Prefer.setInt(KEY_LAST_SYNC, timestamp);
    lastSyncTimestamp = timestamp;
  }

  @action
  void setSyncing(bool value) {
    isSyncing = value;
  }

  @action
  void setLastError(String? error) {
    lastSyncError = error;
  }

  Map<String, String> get authHeaders {
    final creds = base64.encode(utf8.encode('$username:$token'));
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }
}
