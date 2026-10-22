import 'dart:io';

import 'package:flutter_app_publisher/src/api/app_package_publisher.dart';
import 'package:pub_semver/pub_semver.dart';

const kEnvQiniuAccessKey = 'QINIU_ACCESS_KEY';
const kEnvQiniuSecretKey = 'QINIU_SECRET_KEY';
const kEnvPgyerUpdateDescriptionDetail = 'PGYER_UPDATE_DESCRIPTION_DETAIL';

class PublishQiniuConfig extends PublishConfig {
  PublishQiniuConfig({
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
    this.bucketDomain,
    this.savekeyPrefix,
    this.updateVersionInfo = false,
    this.updateDescription = '',
  });

  factory PublishQiniuConfig.parse(
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
  ) {
    String? accessKey =
        (environment ?? Platform.environment)[kEnvQiniuAccessKey];
    String? secretKey =
        (environment ?? Platform.environment)[kEnvQiniuSecretKey];
    if ((accessKey ?? '').isEmpty) {
      throw PublishError('Missing `$kEnvQiniuAccessKey` environment variable.');
    }
    if ((secretKey ?? '').isEmpty) {
      throw PublishError('Missing `$kEnvQiniuSecretKey` environment variable.');
    }

    final updateVersionInfo = publishArguments?['update-version-info'] == true ||
        publishArguments?['update-version-info']?.toString() == 'true';

    if (updateVersionInfo) {
      final bucketDomain = publishArguments?['bucket-domain'];
      if ((bucketDomain ?? '').isEmpty) {
        throw PublishError(
          '`update-version-info` requires `bucket-domain` to build the apk_url.',
        );
      }
    }

    return PublishQiniuConfig(
      accessKey: accessKey!,
      secretKey: secretKey!,
      bucket: publishArguments?['bucket'],
      bucketDomain: publishArguments?['bucket-domain'],
      savekeyPrefix: publishArguments?['savekey-prefix'] ?? '',
      updateVersionInfo: updateVersionInfo,
      updateDescription: (environment ?? Platform.environment)
              [kEnvPgyerUpdateDescriptionDetail] ??
          '',
    );
  }

  final String accessKey;
  final String secretKey;
  final String bucket;
  String? bucketDomain;
  String? savekeyPrefix;
  final bool updateVersionInfo;
  final String updateDescription;

  /// 后台 `version` 字段校验为 `\d+(\.\d+)*`，构建号与预发布标记都要去掉。
  String get version {
    final Version v = pubspec.version ?? Version.none;
    return '${v.major}.${v.minor}.${v.patch}';
  }
}
