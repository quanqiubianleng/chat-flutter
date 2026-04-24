import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cryptography/cryptography.dart';
import 'package:education/config/app_config.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/utils/logger.dart';

class ApiClient {
  final Dio dio;

  /// 与网关 [gateway/internal/handler/routes.go] 一致：POST /v1/users/auth/refreshToken
  static const String _refreshPath = '/v1/users/auth/refreshToken';
  static const String _authRetriedKey = '__auth_retried';
  static const String _networkRetriedKey = '__network_retried_once';

  /// 并发 401 时合并为一次刷新，避免风暴
  static Future<Map<String, dynamic>?>? _refreshInFlight;

  // 固定 32 字节 AES Key（应由服务端下发或协商，勿提交真实密钥）
  static final List<int> aesKeyBytes =
      utf8.encode("12345678901234567890123456789012"); // 32 字节
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 20);

  ApiClient() : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.reqUrl,
            connectTimeout: _connectTimeout,
            receiveTimeout: _receiveTimeout,
            headers: {'Content-Type': 'application/json'},
            contentType: "application/json",
            validateStatus: (status) => status != null && status >= 200 && status < 300,
          ),
        ) {
    dio.interceptors.add(_authInterceptor());
    dio.interceptors.add(_refreshOn401Interceptor());
    dio.interceptors.add(_serverErrorInterceptor());
    dio.interceptors.add(_networkExceptionInterceptor());
    dio.interceptors.add(_encryptInterceptor());
    dio.interceptors.add(_curlLogInterceptor());
  }

  /// 网络异常统一转业务错误，避免直接抛 DioException 影响页面流程
  InterceptorsWrapper _networkExceptionInterceptor() {
    return InterceptorsWrapper(
      onError: (err, handler) async {
        final isTimeout =
            err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.sendTimeout ||
            err.type == DioExceptionType.receiveTimeout;
        final rawError = (err.error ?? '').toString().toLowerCase();
        final isConnectionReset =
            rawError.contains('connection reset by peer') ||
            rawError.contains('connection reset');
        final isConnectionIssue =
            err.type == DioExceptionType.connectionError ||
            (err.type == DioExceptionType.unknown && isConnectionReset);

        // connection reset 场景自动重试 1 次（短延迟），降低启动瞬时抖动造成的失败率
        if (isConnectionReset && err.requestOptions.extra[_networkRetriedKey] != true) {
          final req = err.requestOptions;
          req.extra[_networkRetriedKey] = true;
          try {
            await Future.delayed(const Duration(milliseconds: 350));
            final retryResp = await dio.fetch(req);
            AppLogger.w('[API_RETRY] reset 重试成功: ${req.uri}');
            return handler.resolve(retryResp);
          } catch (retryErr) {
            AppLogger.w('[API_RETRY] reset 重试失败: ${req.uri}, err=$retryErr');
          }
        }

        if (isTimeout || isConnectionIssue) {
          final msg = isTimeout
              ? '网络请求超时，请检查网络后重试'
              : '网络连接不稳定，请稍后重试';
          AppLogger.w(
            '[API_NETWORK] ${err.requestOptions.uri} type=${err.type} err=${err.error}',
          );
          return handler.resolve(
            Response(
              requestOptions: err.requestOptions,
              statusCode: 200,
              data: <String, dynamic>{
                'code': -1,
                'msg': msg,
                '_error': true,
                '_errorMsg': msg,
              },
            ),
          );
        }
        return handler.next(err);
      },
    );
  }

  /// 5xx 服务器错误：转为统一业务错误，避免 DioException 直接抛出
  static Response _fake5xxResponse(RequestOptions opts, {String? msg}) {
    return Response(
      requestOptions: opts,
      statusCode: 200,
      data: <String, dynamic>{
        'code': 500,
        'msg': msg ?? '服务器繁忙，请稍后再试',
        '_error': true,
        '_errorMsg': msg ?? '服务器繁忙，请稍后再试',
      },
    );
  }

  InterceptorsWrapper _serverErrorInterceptor() {
    return InterceptorsWrapper(
      onError: (err, handler) async {
        final statusCode = err.response?.statusCode;
        if (statusCode != null && statusCode >= 500 && statusCode < 600) {
          AppLogger.e('服务器错误 $statusCode: ${err.requestOptions.uri}');
          return handler.resolve(_fake5xxResponse(err.requestOptions));
        }
        return handler.next(err);
      },
    );
  }

  // 请求拦截器：自动加 token（刷新 token 的请求不加）
  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final path = options.uri.path;
        if (_isRefreshRequestPath(path)) {
          handler.next(options);
          return;
        }
        final token = await UserCache.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = token;
        }
        handler.next(options);
      },
    );
  }

  static bool _isRefreshRequestPath(String path) =>
      path.contains('users/auth/refreshToken') || path.contains('auth/refreshToken');

  /// 401 且无法刷新时返回业务错误，避免抛出 DioException 刷屏
  static Response _fake401Response(RequestOptions opts) {
    unawaited(UserCache.clearAuthTokens());
    return Response(
      requestOptions: opts,
      statusCode: 200,
      data: <String, dynamic>{
        'code': 401,
        'msg': '登录已过期，请到个人中心重新验证',
        '_error': true,
        '_errorMsg': '登录已过期，请到个人中心重新验证',
      },
    );
  }

  Future<Map<String, dynamic>?> _performTokenRefresh(String refreshToken) async {
    final resp = await dio.post(
      _refreshPath,
      data: <String, dynamic>{'refreshToken': refreshToken},
    );
    final data = resp.data is Map<String, dynamic> ? resp.data as Map<String, dynamic> : null;
    if (data == null || data['code'] != 200) return null;
    final newToken = data['token']?.toString();
    final newRefresh = data['refreshToken']?.toString();
    if (newToken == null || newToken.isEmpty) return null;
    await UserCache.saveToken(newToken);
    if (newRefresh != null && newRefresh.isNotEmpty) {
      await UserCache.saveRefreshToken(newRefresh);
    }
    return data;
  }

  Future<Map<String, dynamic>?> _refreshSessionLocked(String refreshToken) async {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }
    _refreshInFlight = _performTokenRefresh(refreshToken);
    try {
      return await _refreshInFlight;
    } catch (_) {
      return null;
    } finally {
      _refreshInFlight = null;
    }
  }

  // 401 时用 refresh_token 换新 token 并重试一次，实现无感续登
  InterceptorsWrapper _refreshOn401Interceptor() {
    return InterceptorsWrapper(
      onError: (err, handler) async {
        final response = err.response;
        if (response?.statusCode != 401) {
          return handler.next(err);
        }
        final req = err.requestOptions;
        final path = req.uri.path;

        // 刷新接口自身 401：禁止再调刷新，否则递归卡死
        if (_isRefreshRequestPath(path)) {
          return handler.resolve(_fake401Response(req));
        }
        // 已用新 token 重试过仍 401：不再刷新
        if (req.extra[_authRetriedKey] == true) {
          return handler.resolve(_fake401Response(req));
        }

        final refreshToken = await UserCache.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          return handler.resolve(_fake401Response(req));
        }
        try {
          final data = await _refreshSessionLocked(refreshToken);
          if (data == null) {
            return handler.resolve(_fake401Response(req));
          }
          final newToken = data['token']?.toString();
          if (newToken == null || newToken.isEmpty) {
            return handler.resolve(_fake401Response(req));
          }
          final opts = response!.requestOptions;
          opts.headers['Authorization'] = newToken;
          opts.extra[_authRetriedKey] = true;
          final retry = await dio.fetch(opts);
          return handler.resolve(retry);
        } catch (_) {
          return handler.resolve(_fake401Response(req));
        }
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
      final msg = data['_errorMsg']?.toString().trim();
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
