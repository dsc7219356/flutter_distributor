import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_app_publisher/flutter_app_publisher.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_app_publisher/src/publishers/vivo/publish_vivo_config.dart';

/// HONOR Connect publishing API doc
/// [https://developer.honor.com/cn/doc/guides/101359#h2-1712046097865]
class AppPackagePublisherVivo extends AppPackagePublisher {
  final Dio _dio = Dio();

  @override
  String get name => 'honor';

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
    PublishVivoConfig publishConfig = PublishVivoConfig.parse(
      environment,
      publishArguments,
    );
    Map<String, dynamic> uploadResult = await uploadFile(
      publishConfig,
      file,
      onPublishProgress,
    );
    return PublishResult(
      url: 'https://dev.vivo.com.cn/app/appService/166035',
    );
  }

  Future<Map<String, dynamic>> uploadFile(
  PublishVivoConfig publishConfig,
      File file,
      PublishProgressCallback? onPublishProgress,
      ) async {
    try {
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      String fileMd5 = await getFileSha256(file);
      Map<String, dynamic> params = {
        "access_key": publishConfig.clientId,
        "timestamp": timestamp.toString(),
        "method": "app.upload.apk.app",
        "v": "1.0",
        "sign_method": "HMAC-SHA256",
        "format": "json",
        "target_app_key": "developer",
        'packageName': 'cn.sigo',
        'fileMd5':fileMd5
      };
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'method': 'app.upload.apk.app',
        'access_key': publishConfig.clientId,
        'timestamp': timestamp.toString(),
        'format': 'json',
        'v': 1.0,
        'sign_method': 'HMAC-SHA256',
        'target_app_key': 'developer',
        'packageName': 'cn.sigo',
        'sign': getSign(params, publishConfig.clientSecret),
        'fileMd5':fileMd5,
      });
      Response response = await _dio.post(
        'https://developer-api.vivo.com.cn/router/rest',
        data: formData,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          responseType: ResponseType.json,
        ),
        onSendProgress: (count, total) {
          onPublishProgress?.call(count, total);
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 0) {print('上传成功，等待下一步发布');
       return response.data['data'];
      } else {
        throw PublishError('getAccessToken error: ${response.data}');
      }
    } catch (e) {
      throw PublishError(e.toString());
    }
  }


  Future<String> getFileSha256(File file) async {
    List<int> fileBytes = await file.readAsBytes();
    Digest digest = sha256.convert(fileBytes);
    return digest.toString();
  }

  static String hmacSHA256(String data, String key) {
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
      String param = '$key=${value.toString()}';
      paramList.add(param);
    }

    return paramList.join('&');
  }

  static String getSign(Map<String, dynamic> params, String accessSecret,) {
    String sign = hmacSHA256(getUrlParamsFromMap(params), accessSecret);
    return sign;
  }
}
