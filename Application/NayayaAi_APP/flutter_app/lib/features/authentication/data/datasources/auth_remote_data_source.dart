import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../models/auth_models.dart';

/// Talks to the authentication endpoints. Knows about HTTP; knows nothing about
/// storage, state or navigation.
///
/// Each method converts transport errors into [Failure]s at its own boundary, so
/// the repository above never sees a [DioException].
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.login,
        data: request.toJson(),
      );
      return LoginResponse.fromJson(_asMap(response.data, 'login'));
    } catch (e) {
      throw ErrorMapper.map(e, context: 'login');
    }
  }

  Future<SignupResponse> signup(SignupRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.signup,
        data: request.toJson(),
      );
      return SignupResponse.fromJson(_asMap(response.data, 'signup'));
    } catch (e) {
      throw ErrorMapper.map(e, context: 'signup');
    }
  }

  /// Ends the server session.
  ///
  /// Returns normally on any completed request. `GET /logout` answers with a 302
  /// to `/`, and if Dio is configured to follow it the final response is the
  /// sign-up page's HTML — neither is a failure, and neither has a body worth
  /// parsing. Only an unreachable server throws.
  Future<void> logout() async {
    try {
      await _dio.get<dynamic>(
        ApiEndpoints.logout,
        options: Options(
          // Do not chase the redirect: the destination renders a full HTML page
          // that would be downloaded and discarded.
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } catch (e) {
      throw ErrorMapper.map(e, context: 'logout');
    }
  }

  /// Probes the stored session.
  ///
  /// The endpoint answers 200 whether or not anyone is signed in, so a thrown
  /// error here means the server could not be reached — never that the session
  /// was rejected.
  Future<SessionResponse> me() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.me);
      return SessionResponse.fromJson(_asMap(response.data, 'me'));
    } catch (e) {
      throw ErrorMapper.map(e, context: 'me');
    }
  }

  /// Guards against a handler that answered 200 with something other than a JSON
  /// object — an HTML error page, or a bare string. Without this the cast throws
  /// a raw `TypeError` that ErrorMapper would file as unknown.
  Map<String, dynamic> _asMap(Object? data, String context) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ServerFailure(
      debugDetail: '$context: expected a JSON object, got ${data.runtimeType}',
    );
  }
}
