@Tags(['live'])
library;

import 'dart:io';

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
import 'package:nayaya_app/features/citizen/data/datasources/citizen_remote_data_sources.dart';
import 'package:nayaya_app/features/citizen/data/models/citizen_complaint_models.dart';
import 'package:nayaya_app/features/missing_persons/data/datasources/missing_person_remote_data_source.dart';

/// The Citizen Portal's data layer against a REAL NyayaAI server.
///
/// Runs the app's own data sources — the code the screens call — over a
/// cookie-carrying Dio configured as `DioClient` is, so what passes here is
/// what the handset sends.
///
/// WRITES TO THE SHARED DATABASE. Everything it creates is marked:
///   - a Mongo user `zz.flutter.citizen.<stamp>@example.com`
///   - a `citizen_complaints` row with full_name "ZZ Flutter Citizen"
///   - one `missing_person_sightings` row (+ its photo under
///     static/uploads/sightings/) when an active case exists
/// Nothing on the server has a delete route; see HOW_TO_START.md for cleanup.
///
///   flutter test test_live/citizen_live_test.dart \
///       --dart-define=API_BASE_URL=http://127.0.0.1:5000
void main() {
  late Dio dio;
  late AuthRemoteDataSource auth;
  late CitizenComplaintRemoteDataSource complaints;
  late RightsChatRemoteDataSource rights;
  late CaseStatusRemoteDataSource cases;
  late MissingPersonRemoteDataSource missing;

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'zz.flutter.citizen.$stamp@example.com';
  const password = 'LiveProbe123!';
  String? trackingId;

  setUpAll(() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: const Duration(seconds: 120),
        contentType: Headers.jsonContentType,
        headers: const {ApiHeaders.appClient: ApiHeaders.appClientValue},
        validateStatus: (_) => true,
      ),
    );
    dio.interceptors.add(CookieManager(CookieJar(ignoreExpires: true)));
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
    auth = AuthRemoteDataSource(dio);
    complaints = CitizenComplaintRemoteDataSource(dio);
    rights = RightsChatRemoteDataSource(dio);
    cases = CaseStatusRemoteDataSource(dio);
    missing = MissingPersonRemoteDataSource(dio);
  });

  group('P-1..P-4 registration, login, session', () {
    test('a citizen registers and is given a CIT ID', () async {
      final response = await auth.signup(
        SignupRequest(
          fullName: 'ZZ Flutter Citizen',
          email: email,
          password: password,
          role: UserRole.citizen,
        ),
      );
      expect(response.uniqueId, startsWith('CIT'));
    });

    // AUTH-1: the already-registered answer is 200, no ID, and this sentence.
    test('registering the same email again returns no ID', () async {
      final response = await auth.signup(
        SignupRequest(
          fullName: 'ZZ Flutter Citizen',
          email: email,
          password: password,
          role: UserRole.citizen,
        ),
      );
      expect(response.uniqueId, isEmpty);
      expect(response.message, 'If eligible, your account has been created.');
    });

    test('signs in as a citizen and the session is live', () async {
      final login = await auth.login(
        LoginRequest(email: email, password: password),
      );
      expect(login.role, UserRole.citizen);

      final me = await auth.me();
      expect(me.loggedIn, isTrue);
      expect(me.role, UserRole.citizen);
    });
  });

  group('P-11..P-13 file and track a complaint', () {
    test('files a complaint and gets a tracking ID', () async {
      final receipt = await complaints.file(
        const ComplaintSubmission(
          fullName: 'ZZ Flutter Citizen',
          phone: '9876543210',
          incidentDate: '2026-09-19',
          location: 'Parity check',
          incidentDescription: 'ZZ parity check: my phone was stolen.',
        ),
      );
      trackingId = receipt.trackingId;
      expect(trackingId, matches(RegExp(r'^CMP-[0-9A-F]{8}$')));
      expect(receipt.status, 'Pending');
    });

    test('tracks it back as Pending', () async {
      final complaint = await complaints.track(trackingId!.toLowerCase());
      expect(complaint.trackingId, trackingId);
      expect(complaint.fullName, 'ZZ Flutter Citizen');
      expect(complaint.statusRaw, 'Pending');
      expect(complaint.location, 'Parity check');
    });

    test("an unknown ID fails with the server's sentence", () async {
      await expectLater(
        complaints.track('CMP-00000000'),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Complaint not found. Check your tracking ID.',
          ),
        ),
      );
    });

    test('an empty name is refused by the server', () async {
      await expectLater(
        complaints.file(
          const ComplaintSubmission(fullName: '', incidentDescription: 'x'),
        ),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Name and incident description are required',
          ),
        ),
      );
    });
  });

  group('P-14 Know Your Rights', () {
    test('a greeting is answered by the canned intro', () async {
      final answer = await rights.ask('hi');
      expect(answer, contains("NyayaAI's rights assistant"));
    });

    // Whatever the server can do right now: an answer, or — if the question
    // matches no section — limitation L2's 500, which the app shows as the
    // website does. Printed so the run records which one happened.
    test(
      'a preset question is answered or fails as the website does',
      () async {
        try {
          final answer =
              await rights.ask('What are my rights when I am arrested?');
          stdout.writeln('[rights-chat] answered, ${answer.length} chars');
          expect(answer, isNotEmpty);
        } on NetworkFailure catch (f) {
          stdout.writeln('[rights-chat] ${f.message}');
          expect(f.message, RightsChatRemoteDataSource.couldNotConnect);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('P-15 My Case Status', () {
    test('an FIR nobody shared reads the server sentence', () async {
      await expectLater(
        cases.lookup('ZZ-NO-SUCH-FIR'),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Status not available for this FIR',
          ),
        ),
      );
    });
  });

  group('P-16..P-18 Missing Persons', () {
    test('lists active cases and reports a sighting as a citizen', () async {
      final people = await missing.all();
      stdout.writeln('[missing] ${people.length} active case(s)');
      if (people.isEmpty) {
        markTestSkipped('No active case to report a sighting against.');
        return;
      }

      // The case's own registered photograph, straight off the server's disk:
      // a face is guaranteed, and a real face matcher must call it a match.
      final person = people.first;
      final websiteRoot =
          Platform.environment['NYAYAAI_WEBSITE_ROOT'] ?? '../../../website';
      final photo = File('$websiteRoot${person.photoPath}');
      if (!photo.existsSync()) {
        markTestSkipped('Photo ${photo.path} is not on this machine.');
        return;
      }

      final result = await missing.reportSighting(
        personId: person.personId,
        photoPath: photo.path,
        photoName: photo.uri.pathSegments.last,
        location: 'ZZ parity check',
        sightingDate: '2026-09-20',
      );
      stdout.writeln(
        '[sighting] match=${result.isMatch} '
        'confidence=${result.matchPercent.round()}% details="${result.details}"',
      );
      expect(result.sightingId, startsWith('SG_'));
    });
  });

  group('P-9 logout', () {
    test('ends the session', () async {
      await auth.logout();
      final me = await auth.me();
      expect(me.loggedIn, isFalse);
    });
  });
}
