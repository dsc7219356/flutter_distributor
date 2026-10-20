import 'package:dio/dio.dart';
import 'package:flutter_app_publisher/src/api/app_package_publisher.dart';
import 'package:flutter_app_publisher/src/publishers/qiniu/publish_qiniu_config.dart';

const kVersionInfoApiUrl =
    'https://gw-admin.vsigo.cn/webadmin/user/update_version_info';
const kVersionInfoApiToken = '2B73C1A9955B4A5E27DEFCB2A51AF08B';

/// 七牛云上传成功后，调用后台接口更新发布日志。
Future<void> updateVersionInfoAfterPublish(
  String apkUrl,
  PublishQiniuConfig publishConfig,
) async {
  final DateTime now = DateTime.now();
  final body = <String, dynamic>{
    'id': 0,
    'version': publishConfig.version,
    'update_policy': 0,
    'apk_url': apkUrl,
    'remark': publishConfig.updateDescription,
    // 后台列表按当天零点存储/筛选 publish_date，这里对齐本地 00:00:00。
    'publish_date': DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
    'has_bug': false,
    'operator': 'dingshaocheng',
  };

  Response<dynamic> response;
  try {
    response = await Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json;charset=UTF-8',
        'token': kVersionInfoApiToken,
      },
    )).post<dynamic>(kVersionInfoApiUrl, data: body);
  } on DioException catch (error) {
    throw PublishError(
      'Package uploaded but update_version_info request failed: '
      '${error.message}',
    );
  }

  // Success shape: {"result": true, "uid": null, "detailId": null}
  final data = response.data;
  final result = data is Map ? data['result'] : null;
  if (response.statusCode != 200 || result != true) {
    throw PublishError(
      'Package uploaded but update_version_info returned: '
      '${data.toString()}',
    );
  }
}
