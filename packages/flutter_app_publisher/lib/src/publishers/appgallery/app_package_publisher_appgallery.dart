import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_app_publisher/flutter_app_publisher.dart';
import 'package:flutter_app_publisher/src/publishers/appgallery/publish_appgallery_config.dart';

/// Huawei AppGallery Connect publishing API doc
/// [https://developer.huawei.com/consumer/cn/doc/app/agc-help-test-api-add-test-package-0000002236201330]
class AppPackagePublisherAppGallery extends AppPackagePublisher {
  final Dio _dio = Dio();

  @override
  String get name => 'appgallery';

  @override
  List<String> get supportedPlatforms => ['android','ohos'];

  @override
  Future<PublishResult> publish(
    FileSystemEntity fileSystemEntity, {
    Map<String, String>? environment,
    Map<String, dynamic>? publishArguments,
    PublishProgressCallback? onPublishProgress,
  }) async {
    File file = fileSystemEntity as File;
    PublishAppGalleryConfig publishConfig = PublishAppGalleryConfig.parse(
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
        publishConfig.clientId,
        accessToken,
        publishConfig.appId,
        fileName,
        file.lengthSync(),
      );

      // Upload file (3/4)
      await uploadFile(
        uploadUrlInfo,
        file,
        onPublishProgress,
      );

      // Apply Package Info (4/4)
      // HarmonyOS packages (.hap/.app) use the v3 app-package-info API;
      // Android packages (.apk/.aab) use the v2 app-file-info API with fileType.
      String? pkgId;
      if (isOhosPackage(fileName)) {
        final applyResult = await applyUploadOhos(
          publishConfig.clientId,
          accessToken,
          publishConfig.appId,
          fileName,
          uploadUrlInfo['objectId'],
        );
        pkgId = _extractPkgId(applyResult);
      } else {
        await applyUploadAndroid(
          publishConfig.clientId,
          accessToken,
          publishConfig.appId,
          fileName,
          uploadUrlInfo['objectId'],
        );
      }

      // 华为在 applyUpload 后异步编译软件包，编译未完成时 app-submit 会返回
      // 204144719(编译中)。先轮询官方编译状态接口(package/compile/status)，
      // 编译完成后再提交发布。
      if (pkgId != null) {
        await waitForCompileDone(
          publishConfig.clientId,
          accessToken,
          publishConfig.appId,
          pkgId,
        );
      } else {
        print('未获取到 pkgId，等待 1 分钟后直接提交...');
        await Future.delayed(Duration(minutes: 1));
      }
      print('编译完成，提交发布...');
      await publishAppStore(
        publishConfig.clientId,
        accessToken,
        publishConfig.appId,
        fileName,
      );

      return PublishResult(
        url:
            'https://developer.huawei.com/consumer/cn/service/josp/agc/index.html#/myApp/${publishConfig.appId}',
      );
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  /// Whether the given file name refers to a HarmonyOS (OHOS) package.
  bool isOhosPackage(String fileName) {
    final String ext = fileName.toLowerCase();
    return ext.endsWith('.hap') || ext.endsWith('.app');
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
        'https://connect-api.cloud.huawei.com/api/oauth2/v1/token',
        data: data,
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
    String clientId,
    String accessToken,
    String appId,
    String fileName,
    int contentLength,
  ) async {
    Map<String, dynamic> query = {
      'appId': appId,
      'fileName': fileName,
      'contentLength': contentLength,
    };
    try {
      Response response = await _dio.get(
        'https://connect-api.cloud.huawei.com/api/publish/v2/upload-url/for-obs',
        queryParameters: query,
        options: Options(
          headers: {
            'client_id': clientId,
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      if (response.data?['ret']?['code'] == 0) {
        return Map<String, dynamic>.from(response.data['urlInfo']);
      } else {
        throw PublishError('getUploadUrl error: ${response.data}');
      }
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  Future<void> uploadFile(
    Map<String, dynamic> urlInfo,
    File file,
    PublishProgressCallback? onPublishProgress,
  ) async {
    try {
      Response response = await _dio.put(
        urlInfo['url'] as String,
        data: file.openRead(),
        options: Options(
          headers: {
            ...Map<String, String>.from(urlInfo['headers']),
            'Content-Length': file.lengthSync().toString(),
          },
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
      String fileName,
      String objectId,
      ) async {
    Map<String, dynamic> headers = {
      'client_id': clientId,
      'Authorization': 'Bearer $accessToken',
    };
    Map<String, dynamic> query = {
      'appId': appId,
      'releaseType': 1,
      // 'releasePhase': 0,
    };
    Map<String, dynamic> data = {
      'fileType':5,
      'files':[
        {
          'fileName': fileName,
          'fileDestUrl': objectId,
        }
      ]
    };
    try {
      Response response = await _dio.put(
        'https://connect-api.cloud.huawei.com/api/publish/v2/app-file-info',
        queryParameters: query,
        data: data,
        options: Options(headers: headers),
      );
      if (response.statusCode == 200 && response.data['ret']['code'] == 0) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw PublishError('applyUpload error: ${response.data}');
      }
    } catch (e) {
      throw PublishError('applyUpload error: ${e.toString()}');
    }
  }

  /// Apply package info for a HarmonyOS (OHOS) package via the v3 API.
  /// Unlike Android (v2 app-file-info with fileType), the OHOS flow uses the
  /// v3 app-package-info endpoint with fileName + objectId and no fileType —
  /// the platform is implied by the app's registration on AppGallery Connect.
  Future<Map<String, dynamic>> applyUploadOhos(
      String clientId,
      String accessToken,
      String appId,
      String fileName,
      String objectId,
      ) async {
    Map<String, dynamic> headers = {
      'client_id': clientId,
      'Authorization': 'Bearer $accessToken',
    };
    Map<String, dynamic> query = {
      'appId': appId,
      'releaseType': 1,
      'releasePhase': 0,
    };
    Map<String, dynamic> data = {
      'fileName': fileName,
      'objectId': objectId,
    };
    try {
      Response response = await _dio.put(
        'https://connect-api.cloud.huawei.com/api/publish/v3/app-package-info',
        queryParameters: query,
        data: data,
        options: Options(headers: headers),
      );
      if (response.statusCode == 200 && response.data['ret']['code'] == 0) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw PublishError('applyUpload error: ${response.data}');
      }
    } catch (e) {
      throw PublishError('applyUpload error: ${e.toString()}');
    }
  }

  /// 从 applyUploadOhos(v3 app-package-info) 的响应里提取软件包 ID(pkgId)。
  /// 字段名未知时打印完整响应，便于定位真实字段。
  String? _extractPkgId(Map<String, dynamic> data) {
    print('applyUpload(app-package-info) 返回: $data');
    for (final key in ['pkgId', 'pkgVersion', 'packageId', 'pkgIdList', 'pkgIds']) {
      final v = data[key];
      if (v is String && v.isNotEmpty) return v;
      if (v is int) return v.toString();
      if (v is List && v.isNotEmpty) {
        final first = v.first;
        if (first is String) return first;
        if (first is Map) {
          final id = first['pkgId'] ?? first['pkgVersion'] ?? first['id'];
          if (id != null) return id.toString();
        }
      }
      if (v is Map) {
        final id = v['pkgId'] ?? v['pkgVersion'] ?? v['id'];
        if (id != null) return id.toString();
      }
    }
    return null;
  }

  /// 查询软件包编译状态。
  /// GET /api/publish/v3/package/compile/status?appId=...&pkgIds=...
  Future<Map<String, dynamic>> queryCompileStatus(
      String clientId,
      String accessToken,
      String appId,
      String pkgId,
      ) async {
    Map<String, dynamic> headers = {
      'client_id': clientId,
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
    Map<String, dynamic> query = {
      'appId': appId,
      'pkgIds': pkgId,
    };
    try {
      Response response = await _dio.get(
        'https://connect-api.cloud.huawei.com/api/publish/v3/package/compile/status',
        queryParameters: query,
        options: Options(headers: headers),
      );
      if (response.statusCode == 200 && response.data['ret']?['code'] == 0) {
        return Map<String, dynamic>.from(response.data);
      }
      throw PublishError('queryCompileStatus error: ${response.data}');
    } catch (e) {
      throw PublishError('queryCompileStatus error: ${e.toString()}');
    }
  }

  /// 轮询软件包编译状态直到完成。
  /// successStatus: 0=编译成功(完成), 1=编译中, 其余=编译失败。
  Future<void> waitForCompileDone(
      String clientId,
      String accessToken,
      String appId,
      String pkgId,
      ) async {
    const int maxAttempts = 40; // 40 × 30s ≈ 20 分钟上限
    const Duration interval = Duration(seconds: 30);
    print('开始轮询软件包编译状态 (pkgId=$pkgId)...');
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      await Future.delayed(interval);
      final Map<String, dynamic> result =
          await queryCompileStatus(clientId, accessToken, appId, pkgId);
      final list = result['pkgStateList'];
      int? status;
      if (list is List && list.isNotEmpty) {
        final first = list.first;
        if (first is Map) {
          final raw = first['successStatus'];
          status = raw is int ? raw : int.tryParse('$raw');
        }
      }
      print('第 $attempt 次轮询: pkgStateList=$list, successStatus=$status');
      if (status == 0) {
        print('软件包编译完成。');
        return;
      } else if (status == 1) {
        print('软件包编译中，继续等待...');
        continue;
      } else if (status != null) {
        throw PublishError('软件包编译失败, successStatus=$status, 响应=$result');
      }
      // status 为 null（列表为空/字段缺失），继续轮询等待状态出现。
    }
    throw PublishError('软件包编译超时(${maxAttempts * 30}s)，请到 AGC 控制台查看。');
  }

  /// Submit the app for release / review.
  /// HarmonyOS (鸿蒙) uses the v3 app-submit endpoint; Android uses v2.
  /// https://developer.huawei.com/consumer/cn/doc/app/agc-help-publish-api-app-submit-0000002271160585
  Future<Map<String, dynamic>> publishAppStore(
      String clientId,
      String accessToken,
      String appId,
      String fileName,
      ) async {
    Map<String, dynamic> headers = {
      'client_id': clientId,
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
    final String submitUrl = isOhosPackage(fileName)
        ? 'https://connect-api.cloud.huawei.com/api/publish/v3/app-submit?appid=$appId'
        : 'https://connect-api.cloud.huawei.com/api/publish/v2/app-submit?appid=$appId';
    try {
      Response response = await _dio.post(
        submitUrl,
        options: Options(headers: headers),
      );
      if (response.statusCode == 200 && response.data['ret']['code'] == 0) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw PublishError('app-submit error: ${response.data}');
      }
    } catch (e) {
      throw PublishError('app-submit error: ${e.toString()}');
    }
  }


  // Future<Map<String, dynamic>> applyUpload(
  //   String clientId,
  //   String accessToken,
  //   String appId,
  //   String fileName,
  //   String objectId,
  // ) async {
  //   Map<String, dynamic> headers = {
  //     'client_id': clientId,
  //     'Authorization': 'Bearer $accessToken',
  //   };
  //   Map<String, dynamic> query = {
  //     'appId': appId,
  //     'releaseType': 1,
  //     'releasePhase': 0,
  //   };
  //   Map<String, dynamic> data = {
  //     'fileName': fileName,
  //     'objectId': objectId,
  //   };
  //   try {
  //     Response response = await _dio.put(
  //       'https://connect-api.cloud.huawei.com/api/publish/v3/app-package-info',
  //       queryParameters: query,
  //       data: data,
  //       options: Options(headers: headers),
  //     );
  //     if (response.statusCode == 200 && response.data['ret']['code'] == 0) {
  //       return Map<String, dynamic>.from(response.data);
  //     } else {
  //       throw PublishError('applyUpload error: ${response.data}');
  //     }
  //   } catch (e) {
  //     throw PublishError('applyUpload error: ${e.toString()}');
  //   }
  // }
}
