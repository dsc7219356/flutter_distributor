import 'dart:io';

import 'package:flutter_app_publisher/flutter_app_publisher.dart';


const kEnvXiaoMiClientSecret = 'XIAOMI_SECRET';


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

    return PublishAppXiaomiConfig(
      clientSecret: clientSecret!,
      icon:  _parseString(publishArguments?['icon'])??'',
      updateDesc:
        _parseString(publishArguments?['update-description'])??'',
      cer: _parseString(publishArguments?['cer'])??'',
    );
  }

  /// 解析字符串值
  ///
  /// 支持将任意类型安全转换为字符串；空字符串将按原样保留
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  final String clientSecret;
  final String icon;
  final String updateDesc;
  final String cer;
}
