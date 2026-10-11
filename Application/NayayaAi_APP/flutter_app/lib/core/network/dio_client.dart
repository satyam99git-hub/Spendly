import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../constants/api_headers.dart';
import 'interceptors/logging_interceptor.dart';

/// Builds the single configured [Dio] the app makes every request through.
///
/// ## Why a cookie jar and not a token store
///
/// The NyayaAI server authenticates with a Flask session cookie. `POST /login`
/// replies with `Set-Cookie: session=<signed>; HttpOnly; Path=/`, and every
/// later request is authorised purely by sending that cookie back. There is no
/// bearer token, no refresh token, and no `Authorization` header anywhere in the
/// server. So "the session" *is* the cookie, and persisting it is what makes
/// stay-signed-in work.
///
/// ## The header that matters just as much
///
/// `POST /login` and `POST /signup` are guarded server-side by
/// `require_same_origin`, which rejects any state-changing request that does
/// not prove it came from somewhere the server trusts. A browser proves it with
/// `Origin`, which it attaches to every POST. Dio is not a browser and sends
/// no `Origin`, so both endpoints answered **403 `{"error": "Request
/// rejected."}`** and the app could never leave its sign-in screen.
///
/// [ApiHeaders.appClient] is how this client proves the same thing. It is set
/// on every request rather than on the two that need it, because the server is
/// free to guard more endpoints later and a client that only sometimes
/// identifies itself would fail one endpoint at a time.
///
/// ## The flag that matters
///
/// The server sets no `Expires` and no `Max-Age`. By the cookie spec that makes
/// it a *session cookie*, which a jar is entitled to drop the moment the process
/// ends — and [PersistCookieJar] does exactly that unless constructed with
/// `ignoreExpires: true`. Without the flag, sign-in works, and then every cold
/// start silently lands back on the login screen. It is set below; do not
/// remove it without replacing the mechanism.
class DioClient {
  DioClient._(this.dio, this._cookieJar);

  final Dio dio;
  final PersistCookieJar _cookieJar;

  /// Creates the client and restores any previously stored session cookie.
  static Future<DioClient> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final cookieDir = Directory('${dir.path}/.cookies');
    if (!await cookieDir.exists()) {
      await cookieDir.create(recursive: true);
    }

    final jar = PersistCookieJar(
      // See the class doc — this is load-bearing, not a tuning knob.
      ignoreExpires: true,
      storage: FileStorage(cookieDir.path),
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: const {ApiHeaders.appClient: ApiHeaders.appClientValue},
        // Let every status through to the caller. Dio's default throws on
        // non-2xx before an interceptor can read the body, and this server puts
        // its most useful text in the body of a 400. ErrorMapper needs that
        // text, so validation happens in the handler below instead.
        validateStatus: (_) => true,
      ),
    );

    dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(const LoggingInterceptor());

    // Reinstates the throw-on-error behaviour that `validateStatus` above turned
    // off, but *after* the body has been parsed, so DioException carries the
    // server's message. 3xx counts as success: `GET /logout` answers with a 302
    // to `/`, which is a completed logout, not a failure.
    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          final status = response.statusCode ?? 0;
          if (status >= 200 && status < 400) {
            return handler.next(response);
          }
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
            ),
            // `true` = deliver as an error to the caller's future rather than
            // swallowing it here.
            true,
          );
        },
      ),
    );

    return DioClient._(dio, jar);
  }

  /// Drops the stored session cookie.
  ///
  /// Called on sign-out *and* after a failed sign-out: if the server could not
  /// be reached to end the session, the local credential still has to go, or the
  /// next launch restores a session the user asked to leave.
  Future<void> clearSession() => _cookieJar.deleteAll();
}
