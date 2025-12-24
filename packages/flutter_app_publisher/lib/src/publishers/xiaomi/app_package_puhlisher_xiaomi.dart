
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter_app_publisher/flutter_app_publisher.dart';
import 'package:flutter_app_publisher/src/publishers/xiaomi/publish_xiaomi_config.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/pkcs1.dart';
import 'package:pointycastle/asymmetric/rsa.dart';

class AppPackagePublisherXiaoMi extends AppPackagePublisher {

  final Dio _dio = Dio();

  @override
  String get name => 'xiaomi';

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
    PublishAppXiaomiConfig publishConfig = PublishAppXiaomiConfig.parse(
      environment,
      publishArguments,
    );
    await getAppInfo(publishConfig.clientSecret);
    await applyUpload(file,publishConfig.clientSecret,publishConfig.icon);
    return PublishResult(
      url:
      'https://developer.huawei.com/consumer/cn/service/josp/agc/index.html',
    );
  }

  // 获取应用信息
  Future<Map<String, dynamic>> getAppInfo(String clientSecret) async{
    Map requestData= {
      'packageName': 'cn.sigo',
      'userName':'yangrui@sigo.cn'
    };
    // 1. 将RequestData转换为JSON字符串
    String requestDataJson = jsonEncode(requestData);
    // 2. 计算RequestData JSON字符串的MD5哈希值（32位小写）
    String md5Hash = crypto.md5.convert(utf8.encode(requestDataJson)).toString();
    // 3. 构建sig数组
    List<Map<String, String>> sig = [
      {
        'name': 'RequestData',
        'hash': md5Hash,
      }
    ];
    // 4. 构建最终的JSON对象
    Map<String, dynamic> finalJson = {
      'sig': sig,
      'password': clientSecret
    };

    // 5. 转换为JSON字符串
    String jsonString = jsonEncode(finalJson);

    // 6. 使用公钥加密（需要实现加密逻辑）
    String encryptedString = await encryptWithPublicKey(jsonString,getPublicKey());

    // 7. 构建请求数据
    Map<String, dynamic> data = {
      'RequestData': requestDataJson,
      'SIG': encryptedString, // 将加密后的数据发送
    };

    try {
      Response response = await _dio.post(
        'https://api.developer.xiaomi.com/devupload/dev/query',
        data: data,
        options: Options(
          contentType: 'application/x-www-form-urlencoded; charset=utf-8',
          responseType: ResponseType.json, // 确保响应解析为JSON
        ),
      );
      if (response.statusCode == 200 && response.data['result'] == 0) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw PublishError('applyUpload error: ${response.data}');
      }
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  // 上传应用信息
  Future<Map<String,dynamic>> applyUpload(File file,String clientSecret,String icon) async {
    Map appInfo = {
      'appName':'视客眼镜网-美瞳隐形眼镜商城',
      'packageName':'cn.sigo',
      'updateDesc':'【视客SVIP】开卡礼赠、生日惊喜、更享折上折！ 【首单补贴】首单新人福利加码，立享百元礼包！买到就是省！ 【超值满赠】平台礼赠多多，邀请好友一起来，超多好礼等你来拿！ 【限时拼团】拼拼更划算，月抛到手9.9！ 【深浅瞳对比】对于不同瞳色（深中浅）的用户都提供了可参考的佩戴图，真实评价可同步生成美瞳记录册！ *视客销售所有商品均为官方授权正品，平台支持30天价保，承诺顺丰24h发货，终身无忧售后；还有专业医师线上问诊，守护你的眼部健康！'
    ,
      'privacyUrl':'https://m.vsigo.cn/privacyagreement',

    };
    Map requestData= {
      'userName':'yangrui@sigo.cn',
      'synchroType':1,
      'appInfo':jsonEncode(appInfo)
    };

    String requestDataJson = jsonEncode(requestData);
    // 2. 计算RequestData JSON字符串的MD5哈希值（32位小写）
    String md5Hash = crypto.md5.convert(utf8.encode(requestDataJson)).toString();
    // 3. 构建sig数组
    List<Map<String, String>> sig = [
      {
        'name': 'RequestData',
        'hash': md5Hash,
      },
      {
        'name':'apk',
        'hash':await _getFileMD5(file)
      },
      {
        "name": "icon",
        "hash": await _getFileMD5(File(icon))
      },

    ];
    // 4. 构建最终的JSON对象
    Map<String, dynamic> finalJson = {
      'sig': sig,
      'password': clientSecret
    };

    // 5. 转换为JSON字符串
    String jsonString = jsonEncode(finalJson);
    String encryptedString = await encryptWithPublicKey(jsonString,getPublicKey());
    // // 7. 构建请求数据
    // Map<String, dynamic> data = {
    //   'RequestData': requestDataJson,
    //   'SIG': encryptedString, // 将加密后的数据发送
    //   'apk': await MultipartFile.fromFile(
    //     file.path,
    //     filename: file.uri.pathSegments.last,
    //     contentType: DioMediaType.parse("application/octet-stream")
    //   ),
    //   'icon': await MultipartFile.fromFile(
    //     icon,
    //     filename: File(icon).uri.pathSegments.last,
    //       contentType: DioMediaType.parse("application/octet-stream")
    //   )
    // };

    FormData formData = FormData.fromMap({
      'RequestData': requestDataJson,
      'SIG': encryptedString,
      'apk': await MultipartFile.fromFile(file.path),
      'icon': await MultipartFile.fromFile(icon),
    });

    try {
      Response response = await _dio.post(
        'https://api.developer.xiaomi.com/devupload/dev/push',
        data: formData,
        // options: Options(
        //   contentType: 'application/x-www-form-urlencoded; charset=utf-8',
        //   responseType: ResponseType.json, // 确保响应解析为JSON
        // ),
        options: Options(
          contentType: Headers.multipartFormDataContentType, // 使用 multipart/form-data
          responseType: ResponseType.json,
        ),
      );
      if (response.statusCode == 200 && response.data['result'] == 0) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw PublishError('applyUpload error: ${response.data}');
      }
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  String getPublicKey()  {
    return '-----BEGIN CERTIFICATE-----MIICsjCCAhugAwIBAgIUbANcYrk1DOkSSBAxRZo+FcIru9wwDQYJKoZIhvcNAQEEBQAwajELMAkGA1UEBhMCQ04xEDAOBgNVBAgMB0JlaUppbmcxEDAOBgNVBAcMB0JlaUppbmcxDzANBgNVBAoMBnhpYW9taTENMAsGA1UECwwEbWl1aTEXMBUGA1UEAwwOZGV2LnhpYW9taS5jb20wIBcNMjMwMjIxMDIwOTA2WhgPMjEyMzAxMjgwMjA5MDZaMGoxCzAJBgNVBAYTAkNOMRAwDgYDVQQIDAdCZWlKaW5nMRAwDgYDVQQHDAdCZWlKaW5nMQ8wDQYDVQQKDAZ4aWFvbWkxDTALBgNVBAsMBG1pdWkxFzAVBgNVBAMMDmRldi54aWFvbWkuY29tMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDAX+S8xIjMtIvC3hDV1Pb9G0xeHKDP5C3yukb41kuvf+rVMTcSb4wxTWy7JlOMaRd6hWPUSNKskX+/aZin2FHlqJkAjP4SqNpSiG1le/0VYXmYRAtshm1DEcoCMyatwAoQU9jDtWu2wPSyDXL/sS5qMufpdzJ1cG1VKVrAvxiOfQIDAQABo1MwUTAdBgNVHQ4EFgQUSerMKItNhZ/Od9mhtMVd4vE/pBEwHwYDVR0jBBgwFoAUSerMKItNhZ/Od9mhtMVd4vE/pBEwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQQFAAOBgQCpyfyMQ1tXgiwbd6j4kU8suUwwFdRcpnjoABwndExs38XF7EoLcHFHpt3WUmIs4fdnOD6+549n0usGOCkRb8H47P7Y+qnJgH/YM42sZEp4vVHczr7MyOquQC/ZO5gnAwaYoVMkKqs06u5dP/MMoedva3PCu9tBkNSQpAnle2BiYg==-----END CERTIFICATE-----';
  }

  /// 使用公钥加密数据，对应Java中的encryptByPublicKey方法
  Future<String> encryptWithPublicKey(String data, String publicKeyPem) async {
    // 将数据转换为字节数组
    Uint8List dataBytes = Uint8List.fromList(utf8.encode(data));

    // 解析公钥
    RSAPublicKey publicKey = _parsePublicKey(publicKeyPem);

    // 创建RSA加密器，使用PKCS1Padding
    final cipher = PKCS1Encoding(RSAEngine());
    cipher.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    // 计算分段加密的块大小（类似Java中的ENCRYPT_GROUP_SIZE）
    int keySizeInBytes = publicKey.modulus!.bitLength ~/ 8;
    int blockSize = keySizeInBytes - 11; // PKCS1填充需要11字节

    // 分段加密
    List<int> result = [];
    int offset = 0;

    while (offset < dataBytes.length) {
      int segmentSize = (offset + blockSize < dataBytes.length) ? blockSize : dataBytes.length - offset;
      // 确保segment是Uint8List类型
      Uint8List segment = Uint8List.fromList(dataBytes.sublist(offset, offset + segmentSize));

      // 加密当前段
      Uint8List encryptedSegment = cipher.process(segment);
      result.addAll(encryptedSegment);

      offset += segmentSize;
    }

    // 将加密结果转换为十六进制字符串（对应Java中的Hex.encodeHexString）
    return _bytesToHex(result);
  }

  /// 解析PEM格式的公钥（修复版本）
  RSAPublicKey _parsePublicKey(String pem) {
    // 移除PEM格式的头部和尾部标记
    String publicKeyPEM = pem
        .replaceAll('-----BEGIN CERTIFICATE-----', '')
        .replaceAll('-----END CERTIFICATE-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '');

    // 解码Base64
    Uint8List certBytes = base64Decode(publicKeyPEM);

    try {
      // 解析X.509证书
      final parser = ASN1Parser(certBytes);
      final certSequence = parser.nextObject() as ASN1Sequence;

      // 遍历证书结构找到公钥部分
      ASN1BitString? publicKeyBitString;

      for (var element in certSequence.elements) {
        if (element is ASN1Sequence) {
          // 查找包含公钥信息的序列
          for (var subElement in element.elements) {
            if (subElement is ASN1BitString) {
              publicKeyBitString = subElement;
              break;
            } else if (subElement is ASN1Sequence) {
              // 检查是否是公钥信息部分
              if (subElement.elements.length >= 2 &&
                  subElement.elements[1] is ASN1BitString) {
                publicKeyBitString = subElement.elements[1] as ASN1BitString;
                break;
              }
            }
          }
          if (publicKeyBitString != null) break;
        }
      }

      if (publicKeyBitString == null) {
        throw Exception('无法找到公钥信息');
      }

      // 将 List<int> 转换为 Uint8List
      Uint8List publicKeyBytes = Uint8List.fromList(publicKeyBitString.stringValue);

      // 解析RSA公钥参数
      final keyParser = ASN1Parser(publicKeyBytes);
      final rsaKeySequence = keyParser.nextObject() as ASN1Sequence;

      BigInt modulus = (rsaKeySequence.elements[0] as ASN1Integer).valueAsBigInteger!;
      BigInt exponent = (rsaKeySequence.elements[1] as ASN1Integer).valueAsBigInteger!;

      return RSAPublicKey(modulus, exponent);
    } catch (e) {
      print('证书解析错误: $e');
      rethrow;
    }
  }

  /// 将字节数组转换为十六进制字符串
  String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// 计算文件的MD5哈希值（32位小写）
  Future<String> _getFileMD5(File file) async {
    try {
      // 读取文件内容
      List<int> fileBytes = await file.readAsBytes();

      // 使用crypto前缀的MD5函数
      crypto.Digest digest = crypto.md5.convert(fileBytes);

      // 返回32位小写的十六进制字符串
      return digest.toString();
    } catch (e) {
      throw PublishError('计算文件MD5失败: $e');
    }
  }


}