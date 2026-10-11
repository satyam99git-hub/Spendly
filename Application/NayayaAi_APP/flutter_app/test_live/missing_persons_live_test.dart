@Tags(['live'])
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/config/app_config.dart';
import 'package:nayaya_app/core/constants/api_headers.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:nayaya_app/features/authentication/data/models/auth_models.dart';
import 'package:nayaya_app/core/enums/user_role.dart';
import 'package:nayaya_app/features/missing_persons/data/datasources/missing_person_remote_data_source.dart';

/// Contract tests for the missing-persons blueprint, against a RUNNING server.
///
/// ---------------------------------------------------------------------------
/// THE ONLY SUITE HERE THAT NEEDS A SESSION
///
/// These are the only endpoints in the app whose police check actually works.
/// `/get_sightings`, `/get_confirmed_matches`, `/upload_missing_person` and
/// `/update_missing_person_status` all call `_is_police()` and answer 403 to
/// anyone else — where `/generate_fir` and the whole evidence locker have no
/// check at all.
///
/// So this suite signs in, which the FIR and evidence suites do not have to.
/// That is the point of the first group: proving the refusal is real is worth
/// as much as proving the success is, because it is the one place in this app
/// where a lapsed session produces an error an officer will actually see.
/// ---------------------------------------------------------------------------
///
/// Read-only apart from the sign-in. Registering a person needs a photograph
/// with a detectable face, which a test cannot manufacture — the server deletes
/// the upload and refuses without one — so registration is covered by the unit
/// suite and by the refusal asserted below.
///
///   flutter test test_live/ --dart-define=API_BASE_URL=http://127.0.0.1:5000
void main() {
  late Dio dio;
  late MissingPersonRemoteDataSource remote;
  late AuthRemoteDataSource auth;

  /// Unique per run: the server rejects a unique ID that is already taken.
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'zz.flutter.mp.$stamp@example.com';
  const password = 'LiveProbe123!';
  final badgeId = 'POL${stamp % 100000}';

  Dio buildDio() {
    final client = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
        headers: const {ApiHeaders.appClient: ApiHeaders.appClientValue},
        validateStatus: (_) => true,
      ),
    );
    client.interceptors.add(CookieManager(CookieJar()));
    client.interceptors.add(
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
    return client;
  }

  setUpAll(() {
    dio = buildDio();
    remote = MissingPersonRemoteDataSource(dio);
    auth = AuthRemoteDataSource(dio);
  });

  tearDownAll(() {
    dio.close(force: true);
    // ignore: avoid_print
    print('Live police account left behind: $email / $badgeId.');
  });

  // Signed out. Runs first, before the sign-in below, and that ordering is the
  // test — a suite that signed in during setUpAll could not check this at all.
  group('signed out', () {
    test('the open register is readable by anyone', () async {
      // No session check on this one: a citizen has to be able to see who is
      // missing.
      final people = await remote.all();
      expect(people, isA<List<dynamic>>());
    });

    test('the confirmed matches are refused, in the server\'s words', () async {
      await expectLater(
        remote.confirmedMatches(),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            contains('Police login required'),
          ),
        ),
      );
    });

    test('the sightings on a case are refused too', () async {
      await expectLater(
        remote.sightings('MP_NOSUCHCASE'),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            contains('Police login required'),
          ),
        ),
      );
    });
  });

  group('signed in as police', () {
    setUpAll(() async {
      await auth.signup(
        SignupRequest(
          fullName: 'Live Probe Officer',
          email: email,
          password: password,
          role: UserRole.police,
          uniqueId: badgeId,
        ),
      );
      await auth.login(LoginRequest(email: email, password: password));
    });

    test('the register reads back through the model', () async {
      final people = await remote.all();

      for (final person in people) {
        expect(person.personId, isNotEmpty);
        // The list filters on it server-side, so nothing else can appear here.
        expect(person.statusRaw, 'Missing');
        // INTEGER column read as text — a cast would throw on the first row.
        expect(person.age, isA<String>());
        // Already `/`-prefixed by the handler, which is what the photo widget's
        // join relies on.
        if (person.hasPhoto) expect(person.photoPath, startsWith('/'));
      }
    });

    test('the confirmed matches are now readable, and grouped by person',
        () async {
      final matches = await remote.confirmedMatches();

      for (final match in matches) {
        expect(match.personId, isNotEmpty);
        expect(match.sightings, isNotEmpty);
        // `score` on a grouped sighting is already a percentage — the handler
        // multiplies by 100. Reading it as a 0-1 figure and multiplying again
        // would report every match as several thousand per cent.
        expect(match.best!.matchPercent, lessThanOrEqualTo(100));
        expect(match.best!.isConfirmed, isTrue);
      }
    });

    test('a case with no sightings answers an empty list, not a 404', () async {
      expect(await remote.sightings('MP_NOSUCHCASE'), isEmpty);
    });

    test('sightings read back with the raw score scaled to a percentage',
        () async {
      final people = await remote.all();
      if (people.isEmpty) return;

      for (final person in people.take(3)) {
        for (final sighting in await remote.sightings(person.personId)) {
          // `face_match_score` is the raw 0-1 figure here, unlike a grouped
          // match's `score`. Both end up on the same 0-100 scale.
          expect(sighting.matchPercent, inInclusiveRange(0, 100));
        }
      }
    });

    // The server validates the value; anything else is a 400 with its own
    // wording, and the enum in the app is exactly that list.
    test('an invalid status is refused', () async {
      await expectLater(
        dio.post<dynamic>(
          '/update_missing_person_status/MP_NOSUCHCASE',
          data: {'status': 'Vanished'},
        ),
        throwsA(isA<DioException>()),
      );
    });
  });
}
