import 'dart:io';

import 'package:flutter_app_publisher/flutter_app_publisher.dart';

const kEnvHonorClientId = 'HONOR_CLIENT_ID';
const kEnvHonorClientSecret = 'HONOR_CLIENT_SECRET';

class PublishHonorConfig extends PublishConfig {
  PublishHonorConfig({
    required this.clientId,
    required this.clientSecret,
    required this.appId,
  });

  factory PublishHonorConfig.parse(
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
  ) {
    String? clientId =
        (environment ?? Platform.environment)[kEnvHonorClientId];
    if ((clientId ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvHonorClientId` environment variable.',
      );
    }

    String? clientSecret =
        (environment ?? Platform.environment)[kEnvHonorClientSecret];
    if ((clientSecret ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvHonorClientSecret` environment variable.',
      );
    }

    String? appId = publishArguments?['app-id'];
    if ((appId ?? '').isEmpty) {
      throw PublishError('Missing `app-id` arg');
    }

    return PublishHonorConfig(
      clientId: clientId!,
      clientSecret: clientSecret!,
      appId: appId!,
    );
  }

  final String clientId;
  final String clientSecret;
  final String appId;
}
