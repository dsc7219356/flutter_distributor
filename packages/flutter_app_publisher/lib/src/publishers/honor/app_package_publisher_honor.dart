import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_app_publisher/flutter_app_publisher.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_app_publisher/src/publishers/honor/publish_honor_config.dart';

/// HONOR Connect publishing API doc
/// [https://developer.honor.com/cn/doc/guides/101359#h2-1712046097865]
class AppPackagePublisherHonor extends AppPackagePublisher {
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
    PublishHonorConfig publishConfig = PublishHonorConfig.parse(
      environment,
      publishArguments,
    );

    try {
      String fileName = file.uri.pathSegments.last;

      // Get access token (1/4)
      String accessToken = await getAccessToken(
        publishConfig.clientId,
        publishConfig.clientSecret,
      );

      // Get upload URL (2/4)
      Map<String, dynamic> uploadUrlInfo = await getUploadUrl(
          publishConfig.clientId, accessToken, publishConfig.appId, fileName, file.lengthSync(), file);

      // Upload file (3/4)
      await uploadFile(
        publishConfig.appId,
        accessToken,
        uploadUrlInfo,
        file,
        onPublishProgress,
      );

      // Apply Package Info (4/4)
      await applyUploadAndroid(
        publishConfig.clientId,
        accessToken,
        publishConfig.appId,
        fileName,
        uploadUrlInfo,
      );

      await publishHonor(accessToken, publishConfig.appId);

      return PublishResult(
        url: 'https://developer.honor.com/cn/manageCenter/app/E00006?~id=11',
      );
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  Future<String> getAccessToken(
    String clientId,
    String clientSecret,
  ) async {
    Map<String, dynamic> data = {
      'grant_type': 'client_credentials',
      'client_id': clientId,
      'client_secret': clientSecret,
    };
    try {
      Response response = await _dio.post(
        'https://iam.developer.honor.com/auth/token',
        data: data,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          responseType: ResponseType.json,
        ),
      );
      if (response.statusCode == 200 && response.data['access_token'] != null) {
        return response.data['access_token'];
      } else {
        throw PublishError('getAccessToken error: ${response.data}');
      }
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  Future<Map<String, dynamic>> getUploadUrl(
      String clientId, String accessToken, String appId, String fileName, int contentLength, File file) async {
    List query = [
      {'fileName': fileName, 'fileType': 100, 'fileSize': contentLength, 'fileSha256':await getFileSha256(file)}
    ];
    try {
      Response response = await _dio.post(
        'https://appmarket-openapi-drcn.cloud.honor.com/openapi/v1/publish/get-file-upload-url?appId=${appId}',
        data: query,
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
        }, contentType: 'application/json'),
      );
      if (response.data['code'] == 0) {
        return Map<String, dynamic>.from(response.data['data'][0]);
      } else {
        throw PublishError('getUploadUrl error: ${response.data}');
      }
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  Future<void> uploadFile(
    String appId,
    String accessToken,
    Map<String, dynamic> urlInfo,
    File file,
    PublishProgressCallback? onPublishProgress,
  ) async {
    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    try {
      Response response = await _dio.post(
        'https://appmarket-openapi-drcn.cloud.honor.com/openapi/v1/publish/file-upload?appId=${appId}&objectId=${urlInfo['objectId']}',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
          contentType: Headers.multipartFormDataContentType,
        ),
        onSendProgress: (count, total) {
          onPublishProgress?.call(count, total);
        },
      );
      if (response.statusCode != 200) {
        throw PublishError('uploadFile error: ${response.data}');
      }
    } catch (e) {
      throw PublishError('uploadFile error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> applyUploadAndroid(
    String clientId,
    String accessToken,
    String appId,
    String fileName, Map<String, dynamic> urlInfo,
  ) async {
    Map data = {
      'bindingFileList':[
        {
          'objectId': urlInfo['objectId'],
        }
      ]
    };
    try {
      Response response = await _dio.post(
        'https://appmarket-openapi-drcn.cloud.honor.com/openapi/v1/publish/update-file-info?appId=${appId}',
        data: data,
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
        }, contentType: 'application/json'),
      );
      if (response.statusCode == 200 && response.data['code'] == 0) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw PublishError('applyUpload error: ${response.data}');
      }
    } catch (e) {
      throw PublishError('applyUpload error: ${e.toString()}');
    }
  }

  Future<void>publishHonor(
      String accessToken,
      String appId,
      ) async{

    try {
      Response response = await _dio.post(
        'https://appmarket-openapi-drcn.cloud.honor.com/openapi/v1/publish/submit-audit?appId=${appId}',
        data: {
          'releaseType':1,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
        }, contentType: 'application/json'),
      );
      if (response.statusCode != 200 || response.data['code'] != 0) {
        throw PublishError('uploadFile error: ${response.data}');
      }
    } catch (e) {
      throw PublishError('applyUpload error: ${e.toString()}');
    }
  }

  Future<String> getFileSha256(File file) async {
    List<int> fileBytes = await file.readAsBytes();
    crypto.Digest digest = crypto.sha256.convert(fileBytes);
    return digest.toString();
  }
}
