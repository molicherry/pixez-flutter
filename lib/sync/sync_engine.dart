import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/account.dart';
import 'package:pixez/models/ban_comment_persist.dart';
import 'package:pixez/models/ban_illust_id.dart';
import 'package:pixez/models/ban_tag.dart';
import 'package:pixez/models/ban_user_id.dart';
import 'package:pixez/models/illust_persist.dart';
import 'package:pixez/models/novel_persist.dart';
import 'package:pixez/models/novel_viewer_persist.dart';
import 'package:pixez/models/tags.dart';
import 'package:pixez/models/task_persist.dart';
import 'package:pixez/store/account_store.dart';
import 'package:pixez/store/book_tag_store.dart';
import 'package:pixez/store/mute_store.dart';
import 'package:pixez/store/tag_history_store.dart';
import 'package:pixez/store/user_setting.dart';
import 'package:pixez/sync/sync_config.dart';
import 'package:pixez/sync/sync_data_mapper.dart';
import 'package:pixez/page/history/history_store.dart';
import 'package:pixez/page/novel/history/novel_history_store.dart';

class SyncEngine {
  final SyncConfig config;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  SyncEngine(this.config);

  Future<bool> pushAll() async {
    if (!config.enabled || config.token.isEmpty) return false;

    try {
      await _pushIllustHistory();
      await _pushNovelHistory();
      await _pushGlanceIllusts();
      await _pushNovelProgress();
      await _pushTagHistory();
      await _pushBanLists();
      await _pushAccounts();
      await _pushDownloadTasks();
      await _pushSettings();
      return true;
    } catch (e) {
      config.setLastError(e.toString());
      return false;
    }
  }

  Future<bool> pullAll() async {
    if (!config.enabled || config.token.isEmpty) return false;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final response = await _dio.post(
        '${config.serverUrl}/api/sync/pull',
        options: Options(headers: config.authHeaders),
        data: {'last_sync': config.lastSyncTimestamp > 0 ? config.lastSyncTimestamp : null},
      );

      final data = response.data;
      if (data['ok'] != true) return false;

      final records = data['data']['records'] as List? ?? [];
      await _mergeRecords(records);
      await _pullSettings();

      config.updateLastSync(now);
      return true;
    } catch (e) {
      config.setLastError(e.toString());
      return false;
    }
  }

  Future<void> _pushIllustHistory() async {
    final provider = IllustPersistProvider();
    await provider.open();
    final items = await provider.getAllAccount();
    final records = items.map((i) => {
      'data_type': 'illust_history',
      'data_key': i.illustId.toString(),
      'payload': SyncDataMapper.illustPersistToJson(i),
      'updated_at': _toIso8601(i.time),
    }).toList();

    if (records.isNotEmpty) {
      await _dio.post(
        '${config.serverUrl}/api/sync/push',
        options: Options(headers: config.authHeaders),
        data: {'records': records},
      );
    }
  }

  Future<void> _pushNovelHistory() async {
    final provider = NovelPersistProvider();
    await provider.open();
    final items = await provider.getAllAccount();
    final records = items.map((n) => {
      'data_type': 'novel_history',
      'data_key': n.novelId.toString(),
      'payload': SyncDataMapper.novelPersistToJson(n),
      'updated_at': _toIso8601(n.time),
    }).toList();

    if (records.isNotEmpty) {
      await _postRecords(records);
    }
  }

  Future<void> _pushGlanceIllusts() async {
    final provider = GlanceIllustPersistProvider();
    await provider.open();
    final items = await provider.getAllAccount();
    final records = items.map((g) => {
      'data_type': 'glance_illust',
      'data_key': g.illustId.toString(),
      'payload': SyncDataMapper.glanceIllustToJson(g),
      'updated_at': _toIso8601(g.time),
    }).toList();

    if (records.isNotEmpty) {
      await _postRecords(records);
    }
  }

  Future<void> _pushNovelProgress() async {
    final provider = NovelViewerPersistProvider();
    await provider.open();
    final items = await provider.getAll();
    final now = DateTime.now().millisecondsSinceEpoch;
    final records = items.map((n) => {
      'data_type': 'novel_progress',
      'data_key': n.novelId.toString(),
      'payload': SyncDataMapper.novelViewerToJson(n),
      'updated_at': _toIso8601(now),
    }).toList();

    if (records.isNotEmpty) {
      await _postRecords(records);
    }
  }

  Future<void> _pushTagHistory() async {
    await tagHistoryStore.fetch();
    final now = DateTime.now().millisecondsSinceEpoch;
    final records = tagHistoryStore.tags.map((t) => {
      'data_type': 'tag_history',
      'data_key': t.name,
      'payload': SyncDataMapper.tagsPersistToJson(t),
      'updated_at': _toIso8601(now),
    }).toList();

    if (records.isNotEmpty) {
      await _postRecords(records);
    }
  }

  Future<void> _pushBanLists() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await muteStore.banUserIdProvider.open();
    final banUsers = await muteStore.banUserIdProvider.getAllAccount();
    final userRecords = banUsers.map((b) => {
      'data_type': 'ban_user',
      'data_key': b.userId ?? '',
      'payload': SyncDataMapper.banUserIdToJson(b),
      'updated_at': _toIso8601(now),
    }).toList();
    if (userRecords.isNotEmpty) await _postRecords(userRecords);

    await muteStore.banIllustIdProvider.open();
    final banIllusts = await muteStore.banIllustIdProvider.getAllAccount();
    final illustRecords = banIllusts.map((b) => {
      'data_type': 'ban_illust',
      'data_key': b.illustId,
      'payload': SyncDataMapper.banIllustIdToJson(b),
      'updated_at': _toIso8601(now),
    }).toList();
    if (illustRecords.isNotEmpty) await _postRecords(illustRecords);

    await muteStore.banTagProvider.open();
    final banTags = await muteStore.banTagProvider.getAllAccount();
    final tagRecords = banTags.map((b) => {
      'data_type': 'ban_tag',
      'data_key': b.name,
      'payload': SyncDataMapper.banTagToJson(b),
      'updated_at': _toIso8601(now),
    }).toList();
    if (tagRecords.isNotEmpty) await _postRecords(tagRecords);

    await muteStore.banCommentPersistProvider.open();
    final banComments = await muteStore.banCommentPersistProvider.getAllAccount();
    final commentRecords = banComments.map((b) => {
      'data_type': 'ban_comment',
      'data_key': b.commentId,
      'payload': {'comment_id': b.commentId, 'name': b.name},
      'updated_at': _toIso8601(now),
    }).toList();
    if (commentRecords.isNotEmpty) await _postRecords(commentRecords);
  }

  Future<void> _pushAccounts() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await accountStore.accountProvider.open();
    final accounts = await accountStore.accountProvider.getAllAccount();
    final records = accounts.map((a) => {
      'data_type': 'account',
      'data_key': a.userId,
      'payload': SyncDataMapper.accountToJson(a),
      'updated_at': _toIso8601(now),
    }).toList();

    if (records.isNotEmpty) {
      await _postRecords(records);
    }
  }

  Future<void> _pushDownloadTasks() async {
    final provider = TaskPersistProvider();
    await provider.open();
    final tasks = await provider.getAllAccount();
    final records = tasks.where((t) => t.id != null).map((t) => {
      'data_type': 'download_task',
      'data_key': t.url,
      'payload': SyncDataMapper.taskToJson(t),
      'updated_at': _toIso8601(DateTime.now().millisecondsSinceEpoch),
    }).toList();

    if (records.isNotEmpty) {
      await _postRecords(records);
    }
  }

  Future<void> _pushSettings() async {
    final settings = _collectSettings();
    await _dio.post(
      '${config.serverUrl}/api/sync/push-settings',
      options: Options(headers: config.authHeaders),
      data: {'payload': settings},
    );
  }

  Future<void> _pullSettings() async {
    final response = await _dio.get(
      '${config.serverUrl}/api/sync/pull-settings',
      options: Options(headers: config.authHeaders),
    );
    final data = response.data;
    if (data['ok'] == true) {
      final payload = data['data']['payload'] as Map<String, dynamic>?;
      if (payload != null) {
        await _applySettings(payload);
      }
    }
  }

  Future<void> _postRecords(List<Map<String, dynamic>> records) async {
    await _dio.post(
      '${config.serverUrl}/api/sync/push',
      options: Options(headers: config.authHeaders),
      data: {'records': records},
    );
  }

  Map<String, dynamic> _collectSettings() {
    final prefs = userSetting.prefs;
    final keys = <String>[
      'zoom_quality', 'feed_preview_quality', 'single_folder', 'save_format',
      'language_num', 'welcome_page_type', 'cross_count', 'h_cross_count',
      'picture_quality', 'manga_quality', 'is_bangs', 'is_amoled',
      'is_top_mode', 'picture_source', 'network_mode',
      'theme_mode', 'save_mode', 'novel_font_size',
      'return_again_to_exit', 'is_clear_old_format_file',
      'is_follow_after_star', 'is_over_sanity_level_folder',
      'nsfw_mask', 'save_after_star', 'star_after_save',
      'save_effect', 'save_effect_enable', 'pad_mode',
      'copy_info_text', 'name_eval', 'file_name_eval',
      'cross_adapt', 'cross_adapt_width', 'default_private_like',
      'image_picker_type_renew', 'long_press_save_confirm',
      'use_dynamic_color', 'seed_color', 'swipe_change_artwork',
      'use_sauce_nao_webview', 'feed_ai_badge',
      'illust_detail_save_skip_long_press', 'drag_start_x',
      'auto_tag_when_star', 'ban_ai_illust',
    ];

    final result = <String, dynamic>{};
    for (final key in keys) {
      final strVal = prefs.getString(key);
      if (strVal != null) {
        result[key] = strVal;
        continue;
      }
      final boolVal = prefs.getBool(key);
      if (boolVal != null) {
        result[key] = boolVal;
        continue;
      }
      final intVal = prefs.getInt(key);
      if (intVal != null) {
        result[key] = intVal;
        continue;
      }
      final doubleVal = prefs.getDouble(key);
      if (doubleVal != null) {
        result[key] = doubleVal;
      }
    }

    final bookTags = Prefer.getStringList('book_tag_list');
    if (bookTags != null) {
      result['book_tag_list'] = bookTags;
    }

    return result;
  }

  Future<void> _applySettings(Map<String, dynamic> settings) async {
    final prefs = userSetting.prefs;
    for (final entry in settings.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is List && key == 'book_tag_list') {
        await Prefer.setStringList(key, value.cast<String>());
      }
    }
    await userSetting.init();
  }

  String _toIso8601(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds).toUtc().toIso8601String();
  }

  Future<void> _mergeRecords(List<dynamic> records) async {
    for (final record in records) {
      final dataType = record['data_type'] as String? ?? '';
      final payload = record['payload'] as Map<String, dynamic>?;
      if (payload == null) continue;

      switch (dataType) {
        case 'illust_history':
          final provider = IllustPersistProvider();
          await provider.open();
          await provider.insert(SyncDataMapper.illustPersistFromJson(payload));
          break;
        case 'novel_history':
          final provider = NovelPersistProvider();
          await provider.open();
          final item = SyncDataMapper.novelPersistFromJson(payload);
          await provider.insert(item);
          break;
        case 'glance_illust':
          break;
        case 'novel_progress':
          final provider = NovelViewerPersistProvider();
          await provider.open();
          await provider.insert(NovelViewerPersist(
            novelId: payload['novel_id'],
            offset: (payload['offset'] as num).toDouble(),
          ));
          break;
        case 'tag_history':
          final t = TagsPersist(
            name: payload['name'],
            translatedName: payload['translated_name'] ?? '',
          );
          t.type = payload['type'] ?? 0;
          await tagHistoryStore.insert(t);
          break;
        case 'ban_user':
          await muteStore.insertBanUserId(
            payload['user_id']?.toString() ?? '',
            payload['name']?.toString() ?? '',
          );
          break;
        case 'ban_illust':
          await muteStore.insertBanIllusts(BanIllustIdPersist(
            illustId: payload['illust_id']?.toString() ?? '',
            name: payload['name']?.toString() ?? '',
          ));
          break;
        case 'ban_tag':
          await muteStore.insertBanTag(BanTagPersist(
            name: payload['name'] ?? '',
            translateName: payload['translate_name'] ?? '',
          ));
          break;
        case 'ban_comment':
          break;
        case 'account':
          final provider = AccountProvider();
          await provider.open();
          await provider.insert(AccountPersist.fromJson(payload));
          await accountStore.fetch();
          break;
        case 'download_task':
          final provider = TaskPersistProvider();
          await provider.open();
          await provider.insert(TaskPersist(
            url: payload['url'] ?? '',
            fileName: payload['file_name'] ?? '',
            title: payload['title'] ?? '',
            userName: payload['user_name'] ?? '',
            userId: payload['user_id'] ?? 0,
            illustId: payload['illust_id'] ?? 0,
            sanityLevel: payload['sanity_level'] ?? 0,
            status: payload['status'] ?? 0,
            medium: payload['medium'],
          ));
          break;
      }
    }
  }
}
