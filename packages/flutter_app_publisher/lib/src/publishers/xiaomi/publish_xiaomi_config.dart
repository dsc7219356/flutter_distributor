import 'dart:io';

import 'package:flutter_app_publisher/flutter_app_publisher.dart';


const kEnvXiaoMiClientSecret = 'XIAOMI_SECRET';
const kEnvXiaoMiIcon = 'XIAOMI_ICON';
const kEnvXiaoMiUpdateDesc = 'UPDATE_DESC';
const kEnvXiaoMiPublicCer = 'XIAOMI_CER';

class PublishAppXiaomiConfig extends PublishConfig {
  PublishAppXiaomiConfig({
    required this.clientSecret,
    required this.icon,
    required this.updateDesc,
    required this.cer,
  });

  factory PublishAppXiaomiConfig.parse(
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
  ) {

    String? clientSecret =
        (environment ?? Platform.environment)[kEnvXiaoMiClientSecret];
    if ((clientSecret ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvXiaoMiClientSecret` environment variable.',
      );
    }

    String? icon =
    (environment ?? Platform.environment)[kEnvXiaoMiIcon];
    if ((clientSecret ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvXiaoMiClientSecret` environment variable.',
      );
    }


    String? updateDesc =
    (environment ?? Platform.environment)[kEnvXiaoMiUpdateDesc];
    if ((clientSecret ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvXiaoMiClientSecret` environment variable.',
      );
    }

    String? cer =
    (environment ?? Platform.environment)[kEnvXiaoMiPublicCer];
    if ((clientSecret ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvXiaoMiClientSecret` environment variable.',
      );
    }

    return PublishAppXiaomiConfig(
      clientSecret: clientSecret!,
      icon: icon!,
      updateDesc:updateDesc!,
      cer: cer!,
    );
  }

  final String clientSecret;
  final String icon;
  final String updateDesc;
  final String cer;
}
