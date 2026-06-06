import 'dart:convert';

import 'package:pixez/models/account.dart';
import 'package:pixez/models/ban_illust_id.dart';
import 'package:pixez/models/ban_tag.dart';
import 'package:pixez/models/ban_user_id.dart';
import 'package:pixez/models/glance_illust_persist.dart';
import 'package:pixez/models/illust_persist.dart';
import 'package:pixez/models/novel_persist.dart';
import 'package:pixez/models/novel_viewer_persist.dart';
import 'package:pixez/models/tags.dart';
import 'package:pixez/models/task_persist.dart';

class SyncDataMapper {
  static Map<String, dynamic> illustPersistToJson(IllustPersist p) {
    return {
      'illust_id': p.illustId,
      'user_id': p.userId,
      'picture_url': p.pictureUrl,
      'title': p.title,
      'user_name': p.userName,
      'time': p.time,
    };
  }

  static IllustPersist illustPersistFromJson(Map<String, dynamic> json) {
    return IllustPersist(
      illustId: json['illust_id'],
      userId: json['user_id'],
      pictureUrl: json['picture_url'],
      title: json['title'],
      userName: json['user_name'],
      time: json['time'],
    );
  }

  static Map<String, dynamic> novelPersistToJson(NovelPersist p) {
    return {
      'novel_id': p.novelId,
      'user_id': p.userId,
      'picture_url': p.pictureUrl,
      'title': p.title,
      'user_name': p.userName,
      'time': p.time,
    };
  }

  static NovelPersist novelPersistFromJson(Map<String, dynamic> json) {
    return NovelPersist(
      novelId: json['novel_id'],
      userId: json['user_id'],
      pictureUrl: json['picture_url'],
      title: json['title'],
      userName: json['user_name'],
      time: json['time'],
    );
  }

  static Map<String, dynamic> glanceIllustToJson(GlanceIllustPersist p) {
    return {
      'illust_id': p.illustId,
      'user_id': p.userId,
      'picture_url': p.pictureUrl,
      'original_url': p.originalUrl,
      'large_url': p.largeUrl,
      'title': p.title,
      'user_name': p.userName,
      'type': p.type,
      'time': p.time,
    };
  }

  static Map<String, dynamic> novelViewerToJson(NovelViewerPersist p) {
    return {
      'novel_id': p.novelId,
      'offset': p.offset,
    };
  }

  static Map<String, dynamic> tagsPersistToJson(TagsPersist t) {
    return {
      'name': t.name,
      'translated_name': t.translatedName,
      'type': t.type,
    };
  }

  static Map<String, dynamic> banUserIdToJson(BanUserIdPersist b) {
    return {
      'user_id': b.userId,
      'name': b.name,
    };
  }

  static Map<String, dynamic> banIllustIdToJson(BanIllustIdPersist b) {
    return {
      'illust_id': b.illustId,
      'name': b.name,
    };
  }

  static Map<String, dynamic> banTagToJson(BanTagPersist b) {
    return {
      'name': b.name,
      'translate_name': b.translateName,
    };
  }

  static Map<String, dynamic> accountToJson(AccountPersist a) {
    return {
      'user_id': a.userId,
      'user_image': a.userImage,
      'access_token': a.accessToken,
      'refresh_token': a.refreshToken,
      'device_token': a.deviceToken,
      'name': a.name,
      'account': a.account,
      'mail_address': a.mailAddress,
      'password': a.passWord,
      'is_premium': a.isPremium,
      'x_restrict': a.xRestrict,
      'is_mail_authorized': a.isMailAuthorized,
    };
  }

  static Map<String, dynamic> taskToJson(TaskPersist t) {
    return {
      'url': t.url,
      'file_name': t.fileName,
      'title': t.title,
      'user_name': t.userName,
      'user_id': t.userId,
      'illust_id': t.illustId,
      'sanity_level': t.sanityLevel,
      'status': t.status,
      'medium': t.medium,
    };
  }

  static const Map<String, List<String>> dataTypeKeys = {
    'illust_history': ['illustpersist.db'],
    'novel_history': ['Novelpersist.db'],
    'glance_illust': ['glanceillustpersist.db'],
    'novel_progress': ['NovelViewerPersist.db'],
    'tag_history': ['tag.db'],
    'ban_user': ['banuserid.db'],
    'ban_illust': ['banillustid.db'],
    'ban_tag': ['bantag.db'],
    'ban_comment': ['banncommentid.db'],
    'account': ['account.db'],
    'download_task': ['task1.db'],
  };
}
