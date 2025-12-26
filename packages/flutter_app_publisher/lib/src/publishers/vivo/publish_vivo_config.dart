import 'dart:io';

import 'package:flutter_app_publisher/flutter_app_publisher.dart';

const kEnvVivoClientId = 'VIVO_ACCESS_KEY';
const kEnvVivoClientSecret = 'VIVO_ACCESS_SECRET';

class PublishVivoConfig extends PublishConfig {
  PublishVivoConfig({
    required this.clientId,
    required this.clientSecret,
  });

  factory PublishVivoConfig.parse(
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
  ) {
    String? clientId =
        (environment ?? Platform.environment)[kEnvVivoClientId];
    if ((clientId ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvVivoClientId` environment variable.',
      );
    }

    String? clientSecret =
        (environment ?? Platform.environment)[kEnvVivoClientSecret];
    if ((clientSecret ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvVivoClientSecret` environment variable.',
      );
    }

    return PublishVivoConfig(
      clientId: clientId!,
      clientSecret: clientSecret!,

    );
  }

  final String clientId;
  final String clientSecret;

}
