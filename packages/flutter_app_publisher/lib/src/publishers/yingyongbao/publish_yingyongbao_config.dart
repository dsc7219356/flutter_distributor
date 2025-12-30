import 'dart:io';

import 'package:flutter_app_publisher/flutter_app_publisher.dart';


const kEnvYingyongbaoClientSecret = 'YINGYONGBAP_SECRET';
const kEnvYingyongbaoUserId = 'YINGYONGBAP_USERID';

class PublishAppYingyongbaoConfig extends PublishConfig {
  PublishAppYingyongbaoConfig({
    required this.clientSecret,
    required this.userId
  });

  factory PublishAppYingyongbaoConfig.parse(
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
  ) {

    String? clientSecret =
        (environment ?? Platform.environment)[kEnvYingyongbaoClientSecret];
    if ((clientSecret ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvYingyongbaoClientSecret` environment variable.',
      );
    }

    String? userId =
    (environment ?? Platform.environment)[kEnvYingyongbaoUserId];
    if ((clientSecret ?? '').isEmpty) {
      throw PublishError(
        'Missing `$kEnvYingyongbaoUserId` environment variable.',
      );
    }

    return PublishAppYingyongbaoConfig(
      clientSecret: clientSecret!,
      userId: userId!
    );
  }

  final String clientSecret;
  final String userId;

}
