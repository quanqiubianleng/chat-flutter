import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cryptography/cryptography.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../core/cache/user_cache.dart';

class ApiClient {
  final Dio dio;
  // 固定 32 字节 AES Key（前端写死）
  static final List<int> aesKeyBytes =
      utf8.encode("12345678901234567890123456789012"); // 32 字节

  static const String baseUrl = "http://127.0.0.1:8860";

  ApiClient() : dio = Dio(
          BaseOptions(
            baseUrl: "$baseUrl",
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
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
        final method = options.method.toUpperCase();
        final shouldEncrypt = method == "POST" || method == "PUT" || method == "PATCH";

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
          if (code == 0) {
            // 弹出提示
            Fluttertoast.showToast(
              msg: msg,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
            );
          }
          if (code != 200) {
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

        print("---- CURL ----\n$buf\n--------------");
        handler.next(options);
      },
    );
  }

  /// 封装常规方法
  Future<Response> post(String path, {Map<String, dynamic>? data}) =>
      dio.post(path, data: data);

  Future<Response> get(String path, {Map<String, dynamic>? query}) =>
      dio.get(path, queryParameters: query);
}
