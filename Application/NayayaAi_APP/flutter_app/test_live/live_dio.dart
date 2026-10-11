import 'package:dio/dio.dart';
import 'package:nayaya_app/core/config/app_config.dart';
import 'package:nayaya_app/core/constants/api_headers.dart';

/// A [Dio] configured the way `DioClient` configures the app's.
///
/// Shared by the live suites so a change to how the app treats a non-2xx cannot
/// hold for the FIR probe and not for the evidence one. Deliberately built here
/// rather than by calling `DioClient.create()`: that opens a persistent cookie
/// jar under the application documents directory, which a headless test run has
/// no business writing to.
///
/// No cookie manager, for the same reason the tests can get away without one —
/// none of the endpoints these suites touch has a session check. That is a
/// property of the server, not of the tests, and it is the thing that should
/// change first.
Dio createLiveDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      contentType: Headers.jsonContentType,
      // The app identifies itself on every request and the server's
      // `require_same_origin` guard lets it through on the strength of it. A
      // live suite without the header would 403 on every POST and PATCH, which
      // is precisely the bug this header exists to fix.
      headers: const {ApiHeaders.appClient: ApiHeaders.appClientValue},
      validateStatus: (_) => true,
    ),
  );

  // Turns a non-2xx into the DioException the data sources' error mapping
  // expects, after the body has been parsed so the server's own message
  // survives. Mirrors what DioClient does in the app.
  dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        if (status >= 200 && status < 400) return handler.next(response);
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
          true,
        );
      },
    ),
  );

  return dio;
}
