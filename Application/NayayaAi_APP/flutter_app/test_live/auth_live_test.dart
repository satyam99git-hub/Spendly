@Tags(['live'])
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/config/app_config.dart';
import 'package:nayaya_app/core/constants/api_headers.dart';
import 'package:nayaya_app/core/enums/user_role.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:nayaya_app/features/authentication/data/models/auth_models.dart';

/// Contract tests against a RUNNING NyayaAI server.
///
/// Everything else in `test/` runs against a fake. These prove the real thing:
/// that the paths exist, that the JSON shapes are what the models expect, and --
/// the part no unit test can cover -- that the Flask session cookie is issued,
/// stored, replayed on the next request, and invalidated by sign-out.
///
/// NOT part of the default run. See dart_test.yaml.
///
///   # 1. start the website (from the repo root)
///   venv/bin/python app.py
///   # 2. then, from flutter_app/
///   flutter test test_live/ --dart-define=API_BASE_URL=http://127.0.0.1:5000
///
/// WRITES TO THE DATABASE. Registration is the only way to obtain an account
/// whose password is known, so the suite creates one under a clearly marked
/// address and deletes it afterwards -- see the tearDownAll note.
void main() {
  late Dio dio;
  late AuthRemoteDataSource remote;

  /// Unique per run, so a suite that dies before cleanup does not collide with
  /// the next one on the server's unique-email constraint.
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final testEmail = 'zz.flutter.live.$stamp@example.com';
  const testPassword = 'LiveProbe123!';

  setUpAll(() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
        // Built by hand rather than by createLiveDio() because this suite needs
        // a cookie jar the others do not -- but the client header is not
        // optional anywhere. Without it `require_same_origin` answers 403 to
        // every POST here, which is the exact failure this suite exists to
        // catch.
        headers: const {ApiHeaders.appClient: ApiHeaders.appClientValue},
        validateStatus: (_) => true,
      ),
    );

    // In-memory rather than PersistCookieJar: the on-disk jar needs
    // path_provider, which needs a platform channel this suite does not have.
    // The behaviour under test -- issue, replay, clear -- is the jar's, not the
    // storage backend's.
    dio.interceptors.add(CookieManager(CookieJar()));

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

    remote = AuthRemoteDataSource(dio);
  });

  tearDownAll(() {
    // The server exposes no delete-account route, so the probe account cannot be
    // removed over HTTP. Remove it directly after the run:
    //
    //   venv/bin/python -c "from pymongo import MongoClient; \
    //     print(MongoClient('mongodb://127.0.0.1:27017/')['NyayaAI_DB']['users'] \
    //       .delete_many({'email': {'\$regex': '^zz\\.flutter\\.live\\.'}}).deleted_count)"
    //
    // ignore: avoid_print
    print('Live test account left behind: $testEmail — see tearDownAll note.');
  });

  group('server reachability', () {
    test('the configured base URL answers', () async {
      final response = await dio.get<dynamic>('/health');
      expect(response.statusCode, 200);
      expect(response.data['status'], 'ok');
    });
  });

  group('sign-in failures', () {
    test('rejected credentials come back as an AuthFailure', () async {
      await expectLater(
        remote.login(
          const LoginRequest(
            email: 'definitely-not-a-user@example.com',
            password: 'wrong',
          ),
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            'Invalid credentials',
          ),
        ),
      );
    });

    test('a missing field comes back as a ValidationFailure', () async {
      await expectLater(
        remote.login(const LoginRequest(email: '', password: '')),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            'Email and password are required',
          ),
        ),
      );
    });
  });

  group('registration failures', () {
    test('a wrong ID prefix is rejected with the server wording', () async {
      await expectLater(
        remote.signup(
          SignupRequest(
            fullName: 'Live Probe',
            email: 'zz.prefix.$stamp@example.com',
            password: testPassword,
            role: UserRole.police,
            uniqueId: 'ABC123',
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            'Unique ID for police must start with POL',
          ),
        ),
      );
    });
  });

  // Ordered, and deliberately so: each step depends on the session the previous
  // one established. This is the sequence a real launch performs.
  group('the full session lifecycle', () {
    test('1. registration assigns a citizen ID', () async {
      final response = await remote.signup(
        SignupRequest(
          fullName: 'Live Probe',
          email: testEmail,
          password: testPassword,
          role: UserRole.citizen,
        ),
      );

      // Server-generated, CIT-prefixed.
      expect(response.uniqueId, startsWith('CIT'));
    });

    test('2. registration does NOT establish a session', () async {
      final session = await remote.me();
      expect(
        session.loggedIn,
        isFalse,
        reason: 'POST /signup sets no cookie — the app must not assume it does',
      );
    });

    test('3. sign-in returns role and unique ID', () async {
      final response = await remote.login(
        LoginRequest(email: testEmail, password: testPassword),
      );

      expect(response.role, UserRole.citizen);
      expect(response.uniqueId, startsWith('CIT'));
      expect(response.redirect, '/citizen-dashboard');
    });

    // The one thing only a live test can prove: the cookie issued by /login was
    // stored by the jar and replayed on a later, unrelated request.
    test('4. the session cookie authorises the next request', () async {
      final session = await remote.me();

      expect(session.loggedIn, isTrue);
      expect(session.role, UserRole.citizen);
      expect(session.userId, isNotEmpty);
    });

    test('5. sign-out ends the session server-side', () async {
      await remote.logout();

      final session = await remote.me();
      expect(session.loggedIn, isFalse);
      expect(session.role, isNull);
    });
  });
}
