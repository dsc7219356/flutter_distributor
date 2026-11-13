import 'dart:io';

import 'package:flutter_app_publisher/flutter_app_publisher.dart';

const kEnvOPPOClientId = 'OPPO_CLIENT_ID';
const kEnvOPPOClientSecret = 'OPPO_CLIENT_SECRET';

class PublishAppOppoConfig extends PublishConfig {
  PublishAppOppoConfig({
    required this.clientId,
    required this.clientSecret,
    this.updateDesc,
  });

  factory PublishAppOppoConfig.parse(
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
  ) {
    final env = environment ?? Platform.environment;

    String? clientId = env[kEnvOPPOClientId];
    if ((clientId ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvOPPOClientId` environment variable.',
      );
    }
    String? clientSecret = env[kEnvOPPOClientSecret];
    if ((clientSecret ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvOPPOClientSecret` environment variable.',
      );
    }

    // YAML 里写 oppo-update-desc，框架会剥掉 `oppo-` 前缀后传进来。
    String? updateDesc = publishArguments?['update-desc']?.toString();
    if (updateDesc != null && updateDesc.trim().length < 5) {
      throw PublishError('`oppo-update-desc` 不少于 5 个字（OPPO 发布版本接口要求）。');
    }

    return PublishAppOppoConfig(
      clientId: clientId!,
      clientSecret: clientSecret!,
      updateDesc: updateDesc,
    );
  }

  final String clientSecret;
  final String clientId;

  /// 版本说明。不传则沿用线上已有值，其余资料字段一律读-改-写，无需配置。
  final String? updateDesc;
}
