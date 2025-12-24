import 'dart:io';

import 'package:flutter_app_publisher/flutter_app_publisher.dart';


const kEnvXiaoMiClientSecret = 'XIAOMI_SECRET';
const kEnvXiaoMiIcon = 'XIAOMI_ICON';

class PublishAppXiaomiConfig extends PublishConfig {
  PublishAppXiaomiConfig({
    required this.clientSecret,
    required this.icon
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

    return PublishAppXiaomiConfig(
      clientSecret: clientSecret!,
      icon: icon!,
    );
  }

  final String clientSecret;
  final String icon;
}
