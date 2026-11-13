import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_app_publisher/flutter_app_publisher.dart';
import 'package:flutter_app_publisher/src/publishers/oppo/publish_oppo_config.dart';
import 'package:parse_app_package/parse_app_package.dart';

// 接入与签名：https://open.oppomobile.com/documentation/page/info?id=10998
// 发布版本：https://open.oppomobile.com/documentation/page/info?id=10999
// 查询普通包详情：https://open.oppomobile.com/documentation/page/info?id=11004
// 文件上传：https://open.oppomobile.com/documentation/page/info?id=11003
// 获取任务状态：https://open.oppomobile.com/documentation/page/info?id=11001
class AppPackagePublisherOppo extends AppPackagePublisher {
  static const String _baseUrl = 'https://oop-openapi-cn.heytapmobi.com';

  /// 发布版本是异步任务，文档建议客户端等待 10 秒以上再查询。
  static const Duration _taskPollInterval = Duration(seconds: 10);
  static const int _taskPollMaxAttempts = 30;

  /// 线上已有的商店资料，发版时原样回写，因此不必在配置里重复维护。
  static const List<String> _inheritFields = [
    'app_name',
    'second_category_id',
    'third_category_id',
    'summary',
    'detail_desc',
    'privacy_source_url',
    'icon_url',
    'pic_url',
    'landscape_pic_url',
    'test_desc',
    'copyright_url',
    'icp_url',
    'special_url',
    'special_file_url',
    'electronic_cert_url',
    'business_username',
    'business_email',
    'business_mobile',
    'age_level',
    'adaptive_equipment',
    'adaptive_type',
    'online_type',
  ];

  /// 普通应用（type=7）的必传字段，合作游戏专属字段不在此列。
  static const List<String> _requiredFields = [
    'pkg_name',
    'version_code',
    'apk_url',
    'app_name',
    'second_category_id',
    'third_category_id',
    'summary',
    'detail_desc',
    'update_desc',
    'privacy_source_url',
    'icon_url',
    'pic_url',
    'online_type',
    'test_desc',
    'copyright_url',
    'business_username',
    'business_email',
    'business_mobile',
    'age_level',
    'adaptive_equipment',
  ];

  final Dio _dio = Dio();

  @override
  String get name => 'oppo';

  @override
  List<String> get supportedPlatforms => ['android'];

  @override
  Future<PublishResult> publish(
    FileSystemEntity fileSystemEntity, {
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
    PublishProgressCallback? onPublishProgress,
  }) async {
    File file = fileSystemEntity as File;
    PublishAppOppoConfig publishConfig = PublishAppOppoConfig.parse(
      environment,
      publishArguments,
    );
    AppPackage appPackage = await parseAppPackage(file);

    String accessToken = await getAccessToken(publishConfig.clientId, publishConfig.clientSecret);
    // sign 是一次性的，每上传一个文件都要重新获取一次上传配置。
    Map<String, dynamic> uploadInfo = await getUploadUrl(accessToken, publishConfig.clientSecret);
    Map<String, dynamic> uploadResult = await uploadFile(uploadInfo, file, onPublishProgress);
    String appId = await updateApp(
      accessToken,
      publishConfig.clientSecret,
      appPackage,
      uploadResult,
      publishConfig,
    );
    return PublishResult(
      url: 'https://open.oppomobile.com/new/mcom/app/detail?app_id=$appId&pkg_symbol=0',
    );
  }

  Future<String> getAccessToken(String clientId, String clientSecret) async {
    try {
      Response response = await _dio.get(
        '$_baseUrl/developer/v1/token',
        queryParameters: {
          'client_id': clientId,
          'client_secret': clientSecret,
        },
        options: Options(responseType: ResponseType.json),
      );
      String? accessToken = response.data?['data']?['access_token'];
      if (response.statusCode == 200 && accessToken != null) {
        return accessToken;
      }
      throw PublishError('getAccessToken error: ${response.data}');
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  Future<Map<String, dynamic>> getUploadUrl(String accessToken, String clientSecret) async {
    Map<String, dynamic> params = _signedParams(accessToken, clientSecret, {});
    try {
      Response response = await _dio.get(
        '$_baseUrl/resource/v1/upload/get-upload-url',
        queryParameters: params,
        options: Options(responseType: ResponseType.json),
      );
      if (response.data?['errno'] == 0) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw PublishError('getUploadUrl error: ${response.data}');
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  Future<Map<String, dynamic>> uploadFile(
    Map<String, dynamic> uploadInfo,
    File file,
    PublishProgressCallback? onPublishProgress,
  ) async {
    FormData formData = FormData.fromMap({
      'type': 'apk',
      'sign': uploadInfo['sign'],
      'file': await MultipartFile.fromFile(file.path),
    });
    Response response = await _dio.post(
      uploadInfo['upload_url'],
      data: formData,
      options: Options(
        contentType: Headers.multipartFormDataContentType,
        responseType: ResponseType.json,
      ),
      onSendProgress: (count, total) {
        onPublishProgress?.call(count, total);
      },
    );
    if (response.statusCode == 200 && response.data?['errno'] == 0) {
      return Map<String, dynamic>.from(response.data['data']);
    }
    throw PublishError('uploadFile error: ${response.data}');
  }

  Future<Map<String, dynamic>> queryAppInfo(
    String accessToken,
    String clientSecret,
    String pkgName,
  ) async {
    Map<String, dynamic> params = _signedParams(accessToken, clientSecret, {'pkg_name': pkgName});
    try {
      Response response = await _dio.get(
        '$_baseUrl/resource/v1/app/info',
        queryParameters: params,
        options: Options(responseType: ResponseType.json),
      );
      if (response.data?['errno'] == 0) {
        Map<String, dynamic> data = Map<String, dynamic>.from(response.data['data']);
        print('OPPO 线上资料：app_id=${data['app_id']} version_code=${data['version_code']}');
        return data;
      }
      throw PublishError('queryAppInfo error: ${response.data}');
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  /// 读-改-写：先取线上资料，只覆盖版本级字段，避免把分类/隐私政策/截图等冲掉。
  Future<String> updateApp(
    String accessToken,
    String clientSecret,
    AppPackage appPackage,
    Map<String, dynamic> uploadResult,
    PublishAppOppoConfig publishConfig,
  ) async {
    Map<String, dynamic> info = await queryAppInfo(accessToken, clientSecret, appPackage.identifier);

    Map<String, dynamic> body = {};
    for (String key in _inheritFields) {
      String value = (info[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        body[key] = value;
      }
    }

    body['pkg_name'] = appPackage.identifier;
    body['version_code'] = appPackage.buildNumber.toString();
    body['app_name'] = (body['app_name'] ?? appPackage.name).toString();
    // apk_url 必须是 JSON 数组字符串，且以该字符串参与签名。
    body['apk_url'] = jsonEncode([
      {
        'url': uploadResult['url'],
        'md5': uploadResult['md5'],
        'cpu_code': 0,
      }
    ]);

    String? updateDesc = publishConfig.updateDesc ?? info['update_desc']?.toString();
    if ((updateDesc ?? '').trim().isEmpty) {
      throw PublishError('缺少版本说明：请传 `oppo-update-desc`，或先在 OPPO 后台填写一次。');
    }
    if (publishConfig.updateDesc == null) {
      print('未提供 oppo-update-desc，沿用线上版本说明：$updateDesc');
    }
    body['update_desc'] = updateDesc;

    List<String> missing = _requiredFields
        .where((key) => (body[key] ?? '').toString().trim().isEmpty)
        .toList();
    if (missing.isNotEmpty) {
      throw PublishError(
        'OPPO 发布版本缺少必传字段：${missing.join(', ')}。'
        '请先在 OPPO 后台补全一次，之后发版会自动沿用线上资料。',
      );
    }

    Map<String, dynamic> params = _signedParams(accessToken, clientSecret, body);
    Response response;
    try {
      response = await _dio.post(
        '$_baseUrl/resource/v1/app/upd',
        data: params,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } catch (e) {
      throw PublishError(e.toString());
    }
    print(response.data);
    if (response.data?['errno'] != 0 || response.data?['data']?['success'] != true) {
      throw PublishError('updateApp error: ${response.data}');
    }

    await waitForTaskSuccess(
      accessToken,
      clientSecret,
      body['pkg_name'].toString(),
      body['version_code'].toString(),
    );
    return info['app_id'].toString();
  }

  Future<Map<String, dynamic>> queryTaskState(
    String accessToken,
    String clientSecret,
    String pkgName,
    String versionCode,
  ) async {
    Map<String, dynamic> params = _signedParams(accessToken, clientSecret, {
      'pkg_name': pkgName,
      'version_code': versionCode,
    });
    try {
      Response response = await _dio.post(
        '$_baseUrl/resource/v1/app/task-state',
        data: params,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      if (response.data?['errno'] == 0) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw PublishError('queryTaskState error: ${response.data}');
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  /// errno=0 只代表查询成功，真实结果看 task_state：1-待处理；2-成功；3-失败。
  Future<void> waitForTaskSuccess(
    String accessToken,
    String clientSecret,
    String pkgName,
    String versionCode,
  ) async {
    for (int attempt = 1; attempt <= _taskPollMaxAttempts; attempt++) {
      await Future.delayed(_taskPollInterval);
      Map<String, dynamic> data = await queryTaskState(accessToken, clientSecret, pkgName, versionCode);
      String state = (data['task_state'] ?? '').toString();
      if (state == '2') {
        print('OPPO 发布任务处理成功：$pkgName $versionCode');
        return;
      }
      if (state == '3') {
        throw PublishError('OPPO 发布任务处理失败：${data['err_msg'] ?? data}');
      }
      print('OPPO 发布任务待处理，第 $attempt/$_taskPollMaxAttempts 次查询…');
    }
    throw PublishError(
      'OPPO 发布任务在 ${_taskPollMaxAttempts * _taskPollInterval.inSeconds} 秒内仍未完成，'
      '请到开放平台后台确认结果。',
    );
  }

  /// 公共参数：access_token + 秒级 timestamp（文档要求秒级，允许误差 15 分钟）。
  Map<String, dynamic> _signedParams(
    String accessToken,
    String clientSecret,
    Map<String, dynamic> business,
  ) {
    Map<String, dynamic> params = {
      'access_token': accessToken,
      'timestamp': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      ...business,
    };
    params['api_sign'] = getSign(params, clientSecret);
    return params;
  }

  String hmacSHA256(String data, String key) {
    var keyBytes = utf8.encode(key);
    var dataBytes = utf8.encode(data);
    var hmac = Hmac(sha256, keyBytes);
    var digest = hmac.convert(dataBytes);
    return digest.toString();
  }

  static String getUrlParamsFromMap(Map<String, dynamic> paramsMap) {
    var keysList = paramsMap.keys.toList()..sort();

    var paramList = <String>[];
    for (var key in keysList) {
      var value = paramsMap[key];
      if (value == null) {
        continue;
      }
      // 数组/Map 需转成 JSON 字符串后再参与拼接与签名。
      String text = (value is Map || value is List) ? jsonEncode(value) : value.toString();
      paramList.add('$key=$text');
    }

    return paramList.join('&');
  }

  String getSign(
    Map<String, dynamic> params,
    String accessSecret,
  ) {
    return hmacSHA256(getUrlParamsFromMap(params), accessSecret);
  }
}