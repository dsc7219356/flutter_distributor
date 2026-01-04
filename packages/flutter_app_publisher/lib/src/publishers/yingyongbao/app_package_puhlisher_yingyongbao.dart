
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_app_publisher/flutter_app_publisher.dart';
import 'package:flutter_app_publisher/src/publishers/yingyongbao/publish_yingyongbao_config.dart';


class AppPackagePublisherYingyongbao extends AppPackagePublisher {

  final Dio _dio = Dio();

  @override
  String get name => 'yingyongbao';

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
    PublishAppYingyongbaoConfig publishConfig = PublishAppYingyongbaoConfig.parse(
      environment,
      publishArguments,
    );
    String timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    String fileName = file.uri.pathSegments.last;
    Map<String,dynamic> uploadInfo = await getUploadUrl(publishConfig.userId, publishConfig.clientSecret, timestamp, fileName);
    bool upload = await uploadApk(uploadInfo,publishConfig.userId,timestamp,file,publishConfig.clientSecret,onPublishProgress);
    if(upload){
      Map<String,dynamic> updateInfo = await updateAppInfo(uploadInfo,publishConfig.userId,timestamp,publishConfig.clientSecret,file);
      if(updateInfo['ret'] == 0){
        await queryAppUpdateStatus(publishConfig.userId,timestamp,publishConfig.clientSecret);
      }
    }

    return PublishResult(
      url:
      'https://app.open.qq.com/p/basic/distribution/update/edit?appId=1105472527',
    );
  }

  Future<Map<String, dynamic>> getUploadUrl(String userid,String accessSecret, String timestamp,String fileName) async {
    Map<String, dynamic> query = {
      'user_id':userid,
      'timestamp': timestamp,
      'pkg_name': 'cn.sigo',
      'app_id':'1105472527',
      'file_type':'apk',
      'file_name':fileName
    };
    String appsign = getSign(query, accessSecret);
    query.addAll({
      'sign':appsign
    });
    try {
      Response response = await _dio.post(
        'https://p.open.qq.com/open_file/developer_api/get_file_upload_info',
        data: query,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );
      if (response.data?['ret'] == 0) {
        return Map<String, dynamic>.from(response.data);
      } else {
         throw PublishError('getUploadUrl error: ${response.data}');
      }
    } catch (e) {
       throw PublishError(e.toString());
    }
  }

  Future<bool>uploadApk(Map<String,dynamic >uploadInfo,String userid,String timestamp,File apkFile,String accessSecret,PublishProgressCallback? onPublishProgress,) async{
    List<int> fileContent = apkFile.readAsBytesSync();
    try{
      Response response = await _dio.put(
        uploadInfo['pre_sign_url'],
        data: apkFile.openRead(),
        options: Options(
            contentType: 'application/octet-stream',
            headers: {
              Headers.contentLengthHeader: fileContent.length, // 设置 content-length.
            },
          sendTimeout: Duration(minutes:60),
          receiveTimeout: Duration(minutes:60),
        ),
        onSendProgress: (int count, int total) {
          onPublishProgress?.call(count, total);
        },
      );
      if (response.statusCode == 200 ) {
        print('上传成功，提审中。。。');
        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  Future<Map<String, dynamic>>updateAppInfo(Map<String,dynamic >uploadInfo,String userid,String timestamp,String accessSecret,File file)async{
    Map<String, dynamic> query = {
      'user_id':userid,
      'timestamp': timestamp,
      'pkg_name': 'cn.sigo',
      'app_id':'1105472527',
      'deploy_type':1,
      'apk32_flag':1,
      'apk32_file_serial_number':uploadInfo['serial_number'],
      'apk32_file_md5': await generateMd5(file)
    };
    String appsign = getSign(query, accessSecret);
    query.addAll({
      'sign':appsign
    });
    try {
      Response response = await _dio.post(
        'https://p.open.qq.com/open_file/developer_api/update_app',
        data: query,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );
      if (response.data?['ret'] == 0) {
        print(response.data);
        return Map<String, dynamic>.from(response.data);
      } else {
        throw PublishError('update error: ${response.data}');
      }
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  Future<Map<String, dynamic>>queryAppUpdateStatus(String userid,String timestamp,String accessSecret,)async{
    Map<String, dynamic> query = {
      'user_id':userid,
      'timestamp': timestamp,
      'pkg_name': 'cn.sigo',
      'app_id':'1105472527',
    };
    String appsign = getSign(query, accessSecret);
    query.addAll({
      'sign':appsign
    });
    try {
      Response response = await _dio.post(
        'https://p.open.qq.com/open_file/developer_api/query_app_update_status',
        data: query,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );
      if (response.data?['ret'] == 0) {
        int auditStatus = response.data?['audit_status'];
        if(auditStatus==1){
          print('审核中。。。');
        } else if(auditStatus==2){
          print('审核驳回');
        } else if(auditStatus==3){
          print('审核通过');
        }else if(auditStatus==8){
          print('开发者主动撤销');
        }
        return Map<String, dynamic>.from(response.data);
      } else {
        throw PublishError('update error: ${response.data}');
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