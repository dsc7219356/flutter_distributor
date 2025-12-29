
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' ;
import 'package:dio/dio.dart';
import 'package:flutter_app_publisher/flutter_app_publisher.dart';
import 'package:flutter_app_publisher/src/publishers/oppo/publish_oppo_config.dart';
import 'package:parse_app_package/parse_app_package.dart';


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
    Map<String, dynamic> uploadInfo = await uploadFile(accessToken, timestamp, data, publishConfig.clientSecret, file,onPublishProgress);
    await updateApp(accessToken, timestamp, publishConfig.clientSecret,file,uploadInfo);
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
      File file,
      PublishProgressCallback? onPublishProgress
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
        onPublishProgress?.call(count, total);
      },
    );
    if (response.statusCode == 200 && response.data['errno'] == 0) {
      print('上传成功，等待提审...');
      return response.data['data'];
    } else {
      throw PublishError('getAccessToken error: ${response.data}');
    }
  }

  Future<Map<String,dynamic>>updateApp(
      String accessToken,
      String timestamp,
      String accessSecret,
      File file,
  Map<String, dynamic> data,
      )async{
    AppPackage appPackage = await parseAppPackage(file);
    Map<String, dynamic> query = {
      'access_token': accessToken,
      'timestamp': timestamp,
      'pkg_name':'cn.sigo',
      'version_code':appPackage.buildNumber,
      'apk_url':{
        'url':data['url'],
        'md5':await generateMd5(file),
        'cpu_code':0
      },
      // 'app_name':'视客眼镜网',
      // 'second_category_id':6762,
      // 'third_category_id':6692,
      // 'summary':'美瞳隐形眼镜商城',
      // 'detail_desc':'视客眼镜网 (sigo.cn)，一个专业的隐形眼镜购物平台，拥有自己的网站、APP和小程序。十多年来，视客对入驻平台的品牌资质严格把关，致力于为消费者带来舒心的购物体验。',
      // 'update_desc':'',
      // 'privacy_source_url':'https://m.vsigo.cn/privacyagreement',
      'online_type':1,

    };
    String appsign = getSign(query, accessSecret);
    query.addAll({
      'api_sign': appsign
    });
    try {
      Response response = await _dio.post(
        'https://oop-openapi-cn.heytapmobi.com/resource/v1/app/upd',
        data: query,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );
      print(response.data);
      if (response.data?['errno'] == 0) {
        if(response.data['data']['success']){
          return Map<String, dynamic>.from(response.data['data']);
        }
        throw PublishError('updateapp error: ${response.data}');
      } else {
        throw PublishError('updateapp error: ${response.data}');
      }
    } catch (e) {
      throw PublishError(e.toString());
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

  static Future<String> generateMd5(File file) async{
    List<int> fileBytes = await file.readAsBytes();
    var digest = md5.convert(fileBytes);
    return digest.toString(); // 返回十六进制字符串
  }

}