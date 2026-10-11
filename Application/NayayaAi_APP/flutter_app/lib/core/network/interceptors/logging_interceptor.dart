import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Request/response logging, debug builds only.
///
/// Bodies are deliberately NOT logged. Auth requests carry plaintext passwords
/// and auth responses carry the session cookie; a convenience log is how those
/// end up in a bug report, a screen recording, or `adb logcat` on a shared
/// handset. Method, path, status and duration are enough to debug wiring, which
/// is what this is for.
class LoggingInterceptor extends Interceptor {
  const LoggingInterceptor();

  static const _stopwatchKey = 'nyayaai_started_at';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.extra[_stopwatchKey] = DateTime.now();
      developer.log(
        '→ ${options.method} ${options.path}',
        name: 'net',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      developer.log(
        '← ${response.statusCode} ${response.requestOptions.path}'
        '${_elapsed(response.requestOptions)}',
        name: 'net',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      developer.log(
        '✖ ${err.response?.statusCode ?? err.type.name} '
        '${err.requestOptions.path}${_elapsed(err.requestOptions)}',
        name: 'net',
      );
    }
    handler.next(err);
  }

  String _elapsed(RequestOptions options) {
    final started = options.extra[_stopwatchKey];
    if (started is! DateTime) return '';
    return ' (${DateTime.now().difference(started).inMilliseconds}ms)';
  }
}
