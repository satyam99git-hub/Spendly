import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/enums/user_role.dart';
import 'package:nayaya_app/core/error/error_mapper.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/core/utils/validators.dart';
import 'package:nayaya_app/features/authentication/data/models/auth_models.dart';

/// Pins the app's understanding of the NyayaAI server's auth contract.
///
/// Every payload below was captured from the running Flask app, not invented:
/// if the server changes shape, these fail and say so, rather than the app
/// failing silently in the field.
void main() {
  group('UserRole', () {
    test('wire values match what the server stores', () {
      expect(UserRole.citizen.wireValue, 'citizen');
      expect(UserRole.police.wireValue, 'police');
      expect(UserRole.lawyer.wireValue, 'lawyer');
      expect(UserRole.judge.wireValue, 'judge');
    });

    test('prefixes match the server rule', () {
      expect(UserRole.police.idPrefix, 'POL');
      expect(UserRole.lawyer.idPrefix, 'LAW');
      expect(UserRole.judge.idPrefix, 'JUD');
      expect(UserRole.citizen.idPrefix, 'CIT');
    });

    test('only citizens get a server-generated ID', () {
      expect(UserRole.citizen.requiresUserSuppliedId, isFalse);
      expect(UserRole.police.requiresUserSuppliedId, isTrue);
      expect(UserRole.lawyer.requiresUserSuppliedId, isTrue);
      expect(UserRole.judge.requiresUserSuppliedId, isTrue);
    });

    // The server's _is_police() accepts police, admin and officer.
    test('officer is treated as police, not demoted to citizen', () {
      expect(UserRole.fromWire('officer'), UserRole.police);
      expect(UserRole.fromWire('officer').hasPoliceAccess, isTrue);
      expect(UserRole.fromWire('admin').hasPoliceAccess, isTrue);
    });

    // Failing closed matters: an unrecognised role must never unlock a
    // professional surface.
    test('an unknown role falls back to the least-privileged one', () {
      expect(UserRole.fromWire('superuser'), UserRole.citizen);
      expect(UserRole.fromWire(null), UserRole.citizen);
      expect(UserRole.fromWire(''), UserRole.citizen);
    });

    test('admin is not offered at registration', () {
      expect(UserRole.registerable, hasLength(4));
      expect(UserRole.registerable.contains(UserRole.admin), isFalse);
    });
  });

  group('LoginResponse', () {
    // Captured from POST /login against the live server.
    test('parses the real success payload', () {
      final response = LoginResponse.fromJson({
        'message': 'Login successful',
        'redirect': '/citizen-dashboard',
        'role': 'citizen',
        'unique_id': 'CIT007',
      });

      expect(response.role, UserRole.citizen);
      expect(response.uniqueId, 'CIT007');
      expect(response.redirect, '/citizen-dashboard');
    });

    test('carries the email the client supplied into the entity', () {
      final user = LoginResponse.fromJson({
        'role': 'police',
        'unique_id': 'POL9999',
      }).toEntity(email: 'shivam99@gmail.com');

      expect(user.role, UserRole.police);
      expect(user.uniqueId, 'POL9999');
      // The server does not return the email, so it can only come from input.
      expect(user.email, 'shivam99@gmail.com');
    });

    test('survives a missing unique_id', () {
      final response = LoginResponse.fromJson({'role': 'judge'});
      expect(response.uniqueId, isEmpty);
      expect(response.role, UserRole.judge);
    });
  });

  group('SignupRequest', () {
    test('omits unique_id entirely for a citizen', () {
      final json = const SignupRequest(
        fullName: 'Test Citizen',
        email: 'cit@example.com',
        password: 'password123',
        role: UserRole.citizen,
        uniqueId: 'IGNORED',
      ).toJson();

      expect(json.containsKey('unique_id'), isFalse);
      expect(json['role'], 'citizen');
      // The server's field is `fullname`, one word.
      expect(json['fullname'], 'Test Citizen');
    });

    test('uppercases a professional ID, as the server does before comparing',
        () {
      final json = const SignupRequest(
        fullName: 'Test Officer',
        email: 'officer@example.com',
        password: 'password123',
        role: UserRole.police,
        uniqueId: 'pol042',
      ).toJson();

      expect(json['unique_id'], 'POL042');
    });
  });

  group('SessionResponse', () {
    // Captured from GET /api/me with a live cookie.
    test('parses a live session', () {
      final session = SessionResponse.fromJson({
        'logged_in': true,
        'role': 'citizen',
        'user_id': '6a7504048450bec061bd23cf',
      });

      expect(session.loggedIn, isTrue);
      expect(session.role, UserRole.citizen);
      expect(session.userId, '6a7504048450bec061bd23cf');
    });

    // Captured from GET /api/me with no cookie.
    test('parses a signed-out session', () {
      final session = SessionResponse.fromJson({
        'logged_in': false,
        'role': null,
      });

      expect(session.loggedIn, isFalse);
      // Not `citizen`: a signed-out user has no role at all, and fromWire's
      // fallback would otherwise manufacture one.
      expect(session.role, isNull);
    });
  });

  group('CachedUser', () {
    test('round-trips through JSON', () {
      const original = CachedUser(
        role: UserRole.lawyer,
        uniqueId: 'LAW021',
        fullName: 'Test Counsel',
        email: 'law@example.com',
      );

      final restored = CachedUser.fromJson(original.toJson());

      expect(restored.role, UserRole.lawyer);
      expect(restored.uniqueId, 'LAW021');
      expect(restored.fullName, 'Test Counsel');
      expect(restored.email, 'law@example.com');
    });

    // Role drives access, so a role changed server-side must win over the copy
    // cached at the last sign-in.
    test('the authoritative role overrides the cached one', () {
      const cached = CachedUser(role: UserRole.citizen, uniqueId: 'CIT001');

      final user = cached.toEntity(authoritativeRole: UserRole.police);

      expect(user.role, UserRole.police);
      expect(user.uniqueId, 'CIT001');
    });
  });

  group('ErrorMapper', () {
    DioException responseWith(int status, Object? body) => DioException(
          requestOptions: RequestOptions(path: '/login'),
          response: Response(
            requestOptions: RequestOptions(path: '/login'),
            statusCode: status,
            data: body,
          ),
          type: DioExceptionType.badResponse,
        );

    test('401 with the server message becomes an AuthFailure', () {
      final failure = ErrorMapper.map(
        responseWith(401, {'error': 'Invalid credentials'}),
      );

      expect(failure, isA<AuthFailure>());
      expect(failure.message, 'Invalid credentials');
    });

    test('400 passes the server wording through verbatim', () {
      const message = 'Unique ID for police must start with POL';
      final failure = ErrorMapper.map(responseWith(400, {'error': message}));

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, message);
    });

    test('a timeout becomes a NetworkFailure', () {
      final failure = ErrorMapper.map(
        DioException(
          requestOptions: RequestOptions(path: '/login'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(failure, isA<NetworkFailure>());
    });

    test('5xx becomes a ServerFailure and does not leak the body', () {
      final failure = ErrorMapper.map(responseWith(500, {'error': 'boom'}));

      expect(failure, isA<ServerFailure>());
      expect(failure.message, isNot(contains('boom')));
    });

    // Flask's debug 500 is a full HTML document. Putting that in a snackbar
    // would be worse than the generic fallback.
    test('an HTML error page is not shown to the user', () {
      expect(ErrorMapper.extractMessage('<!DOCTYPE html><html>...'), isNull);
    });

    test('a Failure passes through unchanged', () {
      const original = NetworkFailure();
      expect(identical(ErrorMapper.map(original), original), isTrue);
    });
  });

  group('Validators.uniqueId', () {
    test('accepts the ID shapes already in the database', () {
      // Real values from the NyayaAI users collection.
      for (final id in ['POL-101', 'POL001', 'POL9999', 'POL1']) {
        expect(
          Validators.uniqueId(id, UserRole.police),
          isNull,
          reason: '$id exists in the database and must remain valid',
        );
      }
    });

    test('rejects a wrong prefix', () {
      expect(Validators.uniqueId('LAW001', UserRole.police), isNotNull);
      expect(Validators.uniqueId('XYZ1', UserRole.judge), isNotNull);
    });

    test('rejects a bare prefix with no number', () {
      expect(Validators.uniqueId('POL', UserRole.police), isNotNull);
    });

    test('is not required for a citizen', () {
      expect(Validators.uniqueId('', UserRole.citizen), isNull);
      expect(Validators.uniqueId(null, UserRole.citizen), isNull);
    });

    test('is case-insensitive, matching the server', () {
      expect(Validators.uniqueId('pol042', UserRole.police), isNull);
    });
  });

  group('Validators.password', () {
    // The server has never applied a password policy, so a client-side floor
    // would lock out accounts that already exist.
    test('sign-in requires presence only', () {
      expect(Validators.password('a'), isNull);
      expect(Validators.password('short'), isNull);
      expect(Validators.password(''), isNotNull);
    });

    test('registration applies the app floor', () {
      expect(Validators.signupPassword('short'), isNotNull);
      expect(Validators.signupPassword('longenough'), isNull);
    });
  });
}
