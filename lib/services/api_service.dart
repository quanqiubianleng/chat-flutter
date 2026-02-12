import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cryptography/cryptography.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:education/config/app_config.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/utils/logger.dart';

class ApiClient {
  final Dio dio;
  // 固定 32 字节 AES Key（应由服务端下发或协商，勿提交真实密钥）
  static final List<int> aesKeyBytes =
      utf8.encode("12345678901234567890123456789012"); // 32 字节

  ApiClient() : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.reqUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
            // 全局强制所有请求都用 JSON
            contentType: "application/json",
          ),
        ) {
    dio.interceptors.add(_authInterceptor());
    dio.interceptors.add(_encryptInterceptor());
    dio.interceptors.add(_curlLogInterceptor());
  }


  // 请求拦截器：自动加 token
  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await UserCache.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = token;
        }
        handler.next(options);
      },
    );
  }

  /// AES-256-GCM 加密/解密拦截器
  InterceptorsWrapper _encryptInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // final method = options.method.toUpperCase();
        final shouldEncrypt = true;

        if (shouldEncrypt && options.data != null) {
          try {
            final plaintext = utf8.encode(jsonEncode(options.data));

            // 改成 256 位 AES-GCM
            final algorithm = AesGcm.with256bits();
            final secretKey = await algorithm.newSecretKeyFromBytes(aesKeyBytes);
            final nonce = algorithm.newNonce(); // List<int>

            final encrypted = await algorithm.encrypt(
              plaintext,
              secretKey: secretKey,
              nonce: nonce,
            );

            options.data = {
              "nonce": base64Encode(encrypted.nonce),
              "payload": base64Encode(encrypted.cipherText),
              "mac": base64Encode(encrypted.mac.bytes),
            };
          } catch (e) {
            return handler.reject(
              DioError(
                requestOptions: options,
                error: "encrypt error: $e",
                type: DioErrorType.unknown,
              ),
            );
          }
        }

        handler.next(options);
      },

      onResponse: (response, handler) async {
        final data = response.data;

        if (data is Map && data["payload"] != null && data["nonce"] != null) {
          try {
            final algorithm = AesGcm.with256bits(); // 改成 256 位
            final secretKey = await algorithm.newSecretKeyFromBytes(aesKeyBytes);

            final nonce = base64Decode(data["nonce"]);
            final cipher = base64Decode(data["payload"]);
            final macBytes = base64Decode(data["mac"]);

            final secretBox = SecretBox(
              cipher,
              nonce: nonce,
              mac: Mac(macBytes),
            );

            final decrypted = await algorithm.decrypt(secretBox, secretKey: secretKey);
            final jsonStr = utf8.decode(decrypted);

            response.data = jsonDecode(jsonStr);
          } catch (e) {
            return handler.reject(
              DioError(
                requestOptions: response.requestOptions,
                error: "decrypt error: $e",
                response: response,
                type: DioErrorType.unknown,
              ),
            );
          }
        }

        // 2. 统一业务状态检查，不直接 reject
        if (response.data is Map<String, dynamic>) {
          final respMap = response.data as Map<String, dynamic>;
          final code = respMap["code"] ?? 0;
          final msg = respMap["msg"] ?? "";

          // code != 0 或者 200 时，只做标记，不阻断响应
          // 接口成功后不弹出提示
          // if (code == 200) { Fluttertoast.showToast(...); }
          if (code != 200 && code != 0) {
            // 可以加一个统一字段，模板里判断
            respMap["_error"] = true;
            respMap["_errorMsg"] = msg;
          }
        }

        handler.next(response);
      },
    );
  }

  /// 生成 CURL 日志
  InterceptorsWrapper _curlLogInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final buf = StringBuffer();
        buf.write("curl -X ${options.method} '${options.uri}'");

        options.headers.forEach((k, v) {
          buf.write(" -H '$k: $v'");
        });

        if (options.data != null) {
          final body = jsonEncode(options.data);
          buf.write(" -d '$body'");
        }
        if (AppConfig.isDebug) {
          AppLogger.d("---- CURL ----\n$buf\n--------------");
        }
        handler.next(options);
      },
    );
  }

  /// 封装常规方法
  Future<Response> post(String path, {Map<String, dynamic>? data}) =>
      dio.post(path, data: data);

  Future<Response> get(String path, {Map<String, dynamic>? data}) =>
      dio.get(path, data: data);

  /// 从 Response 取出 data，为 null 或业务错误时抛 [ApiException]
  static Map<String, dynamic> getDataOrThrow(Response resp) {
    final data = resp.data;
    AppLogger.d("getDataOrThrow");
    AppLogger.d(resp);
    if (data == null) throw ApiException('无响应数据');
    if (data is! Map<String, dynamic>) throw ApiException('响应格式错误');
    if (data['_error'] == true) {
      final msg = data['_errorMsg']?.toString()?.trim();
      throw ApiException(msg != null && msg.isNotEmpty ? msg : '请求失败');
    }
    return data;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}
