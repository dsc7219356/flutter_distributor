
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart';
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
    Map requestData= {
      'packageName': 'cn.sigo',
      'userName':'yangrui@sigo.cn'
    };
    // 1. 将RequestData转换为JSON字符串
    String requestDataJson = jsonEncode(requestData);
    // 2. 计算RequestData JSON字符串的MD5哈希值（32位小写）
    String md5Hash = md5.convert(utf8.encode(requestDataJson)).toString();
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
      'password': publishConfig.clientSecret
    };

    // 5. 转换为JSON字符串
    String jsonString = jsonEncode(finalJson);

    // 6. 使用公钥加密（需要实现加密逻辑）
    String encryptedString = await encryptWithPublicKey(jsonString,await getPublicKey());

    // 7. 构建请求数据
    Map<String, dynamic> data = {
      'RequestData': requestDataJson,
      'SIG': encryptedString, // 将加密后的数据发送
    };

    try {
      Response response = await _dio.post(
        'hhttps://api.developer.xiaomi.com/devupload/dev/query',
        data: data,
      );
      if (response.statusCode == 200) {
        throw PublishError('getAccessToken error: ${response.data}');
        // return response.data;
        return PublishResult(
            url:
            'https://dev.mi.com/xiaomihyperos/console/apps/app-detail?appId=2882303761517570314&isOffStore=false');
      } else {
        throw PublishError('getAccessToken error: ${response.data}');
      }
    } catch (e) {
      throw PublishError(e.toString());
    }
  }

  /// 获取公钥，从证书文件中读取
  Future<String> getPublicKey() async {
    try {
      // 使用绝对路径或包内资源路径
      String publicKeyPath = 'packages/flutter_app_publisher/lib/src/publishers/xiaomi/dev.api.public.cer';

      // 检查文件是否存在
      File publicKeyFile = File(publicKeyPath);
      if (!await publicKeyFile.exists()) {
        throw PublishError('Public key file not found: $publicKeyPath');
      }

      // 读取公钥文件内容
      String publicKeyContent = await publicKeyFile.readAsString();

      return publicKeyContent;
    } catch (e) {
      throw PublishError('Failed to load public key: $e');
    }
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

  /// 解析PEM格式的公钥
  RSAPublicKey _parsePublicKey(String pem) {
    // 移除PEM格式的头部和尾部标记
    String publicKeyPEM = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '');

    // 解码Base64
    Uint8List keyBytes = base64Decode(publicKeyPEM);

    // 使用ASN1解析器解析X.509格式的公钥
    final parser = ASN1Parser(keyBytes);
    final sequence = parser.nextObject() as ASN1Sequence;

    // 获取模数和指数
    ASN1Sequence keyInfo = sequence.elements[1] as ASN1Sequence;
    ASN1BitString bitString = keyInfo.elements[1] as ASN1BitString;

    // 解析RSA公钥参数
    final keyParser = ASN1Parser(bitString.encodedBytes);
    final rsaKeySequence = keyParser.nextObject() as ASN1Sequence;

    BigInt modulus = (rsaKeySequence.elements[0] as ASN1Integer).valueAsBigInteger!;
    BigInt exponent = (rsaKeySequence.elements[1] as ASN1Integer).valueAsBigInteger!;

    return RSAPublicKey(modulus, exponent);
  }

  /// 将字节数组转换为十六进制字符串
  String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
  }

}