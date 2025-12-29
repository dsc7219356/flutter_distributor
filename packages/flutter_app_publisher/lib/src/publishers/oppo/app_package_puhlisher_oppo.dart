
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' ;
import 'package:dio/dio.dart';
import 'package:flutter_app_publisher/flutter_app_publisher.dart';
import 'package:flutter_app_publisher/src/publishers/oppo/publish_oppo_config.dart';


class AppPackagePublisherOppo extends AppPackagePublisher {

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

   String accessToken = await getAccessToken(publishConfig.clientId, publishConfig.clientSecret);
    String timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    Map<String, dynamic> data = await getUploadUrl(accessToken, publishConfig.clientSecret, timestamp);
    Map<String, dynamic> uploadInfo = await uploadFile(accessToken, timestamp, data, publishConfig.clientSecret, file);
    return PublishResult(
      url:
      'https://open.oppomobile.com/new/mcom/app/detail?app_id=3497867&pkg_symbol=0',
    );
  }

  Future<String> getAccessToken(String clientId, String clientSecret) async {
    try {
      Response response = await _dio.get(
        'https://oop-openapi-cn.heytapmobi.com/developer/v1/token?client_id=${clientId}&client_secret=${clientSecret}',
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          responseType: ResponseType.json,
        ),
      );
      if (response.statusCode == 200 && response.data['data']['access_token'] != null) {
        return response.data['data']['access_token'];
      } else {
         throw PublishError('getAccessToken error: ${response.data}');
      }
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  Future<Map<String, dynamic>> getUploadUrl(String accessToken, String accessSecret, String timestamp) async {
    Map<String, dynamic> query = {
      'access_token': accessToken,
      'timestamp': timestamp,
    };
    String appsign = getSign(query, accessSecret);

    try {
      Response response = await _dio.get(
        'https://oop-openapi-cn.heytapmobi.com/resource/v1/upload/get-upload-url?access_token=${accessToken}&timestamp=${timestamp}&api_sign=${appsign}',
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );
      if (response.data?['errno'] == 0) {
        return Map<String, dynamic>.from(response.data['data']);
      } else {
        throw PublishError('getUploadUrl error: ${response.data}');
      }
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  Future<Map<String, dynamic>> uploadFile(
      String accessToken,
      String timestamp,
      Map<String, dynamic> uploadInfo,
      String accessSecret,
      File file
      ) async {
    Map<String, dynamic> params = {
      'access_token': accessToken,
      'timestamp': timestamp,
      'sign': uploadInfo['sign'],
      'type': 'apk'
    };
    String appsign = getSign(params, accessSecret);
    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'api_sign': appsign,
      ...params,
    });
    Response response = await _dio.post(
      uploadInfo['upload_url'],
      data: formData,
      options: Options(
        contentType: Headers.multipartFormDataContentType,
        responseType: ResponseType.json,
      ),
      onSendProgress: (count, total) {
        print(count);
      },
    );
    print(response.data);
    if (response.statusCode == 200 && response.data['errno'] == 0) {
      return response.data['data'];
    } else {
      throw PublishError('getAccessToken error: ${response.data}');
    }
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
      String param = '$key=${value.toString()}';
      paramList.add(param);
    }

    return paramList.join('&');
  }

  String getSign(
      Map<String, dynamic> params,
      String accessSecret,
      ) {
    String sign = hmacSHA256(getUrlParamsFromMap(params), accessSecret);
    return sign;
  }

}