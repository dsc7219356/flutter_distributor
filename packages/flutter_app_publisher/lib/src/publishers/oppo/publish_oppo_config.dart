import 'dart:io';

import 'package:flutter_app_publisher/flutter_app_publisher.dart';


const kEnvOPPOClientId = 'OPPO_CLIENT_ID';
const kEnvOPPOClientSecret = 'OPPO_CLIENT_SECRET';


class PublishAppOppoConfig extends PublishConfig {
  PublishAppOppoConfig({
    required this.clientId,
    required this.clientSecret,
  });

  factory PublishAppOppoConfig.parse(
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
  ) {

    String? clientId =
    (environment ?? Platform.environment)[kEnvOPPOClientId];
    if ((kEnvOPPOClientId ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvOPPOClientId` environment variable.',
      );
    }
    String? clientSecret =
        (environment ?? Platform.environment)[kEnvOPPOClientId];
    if ((clientSecret ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvOPPOClientId` environment variable.',
      );
    }
    return PublishAppOppoConfig(
      clientId: clientId!,
      clientSecret: clientSecret!,
    );
  }


  final String clientSecret;
  final String clientId;

}
