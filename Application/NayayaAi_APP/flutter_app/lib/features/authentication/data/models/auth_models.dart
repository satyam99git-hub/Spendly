/// Wire models for the authentication endpoints.
///
/// Hand-written rather than code-generated: there are four small shapes here and
/// adding build_runner to the toolchain for them would cost more than it saves.
/// If the API surface grows past a dozen models, revisit with json_serializable.
///
/// Every `fromJson` is defensive about types. The server builds these responses
/// by hand in Python, so a field that is a String today can be null tomorrow
/// without a schema change to catch it.
library;

import '../../../../core/enums/user_role.dart';
import '../../domain/entities/auth_user.dart';

/// `POST /login` request body.
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

/// `POST /login` 200 response: `{message, role, unique_id, redirect}`.
class LoginResponse {
  const LoginResponse({
    required this.role,
    required this.uniqueId,
    this.message,
    this.redirect,
  });

  final UserRole role;
  final String uniqueId;
  final String? message;

  /// The server's own post-login destination (`/citizen-dashboard`, etc.).
  /// Captured for completeness but deliberately NOT used for navigation — those
  /// are website routes, and the app derives its landing screen from [role].
  final String? redirect;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      role: UserRole.fromWire(json['role'] as String?),
      uniqueId: (json['unique_id'] as String?)?.trim() ?? '',
      message: json['message'] as String?,
      redirect: json['redirect'] as String?,
    );
  }

  /// Combines the response with the values only the client knows.
  AuthUser toEntity({required String email}) =>
      AuthUser(role: role, uniqueId: uniqueId, email: email);
}

/// `POST /signup` request body.
///
/// `unique_id` is omitted entirely for citizens rather than sent as null or
/// empty: the server reads it only for the professional roles, and sending a
/// key it does not expect is needless surface.
class SignupRequest {
  const SignupRequest({
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
    this.uniqueId,
  });

  final String fullName;
  final String email;
  final String password;
  final UserRole role;
  final String? uniqueId;

  Map<String, dynamic> toJson() {
    return {
      'fullname': fullName,
      'email': email,
      'password': password,
      'role': role.wireValue,
      if (role.requiresUserSuppliedId && (uniqueId?.isNotEmpty ?? false))
        'unique_id': uniqueId!.toUpperCase(),
    };
  }
}

/// `POST /signup` 201 response: `{message, unique_id, role}`.
class SignupResponse {
  const SignupResponse({required this.uniqueId, this.message});

  final String uniqueId;
  final String? message;

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    return SignupResponse(
      uniqueId: (json['unique_id'] as String?)?.trim() ?? '',
      message: json['message'] as String?,
    );
  }
}

/// `GET /api/me` response: `{logged_in, role, user_id}`.
///
/// Always HTTP 200 by design — the server catches its own errors here and
/// reports a logged-out session rather than a 500, so the status code says
/// nothing and [loggedIn] is the only signal that counts.
class SessionResponse {
  const SessionResponse({required this.loggedIn, this.role, this.userId});

  final bool loggedIn;
  final UserRole? role;
  final String? userId;

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    final loggedIn = json['logged_in'] == true;
    return SessionResponse(
      loggedIn: loggedIn,
      // Only trust the role when the session is live. A role beside
      // `logged_in: false` would be meaningless, and UserRole.fromWire's
      // fallback would turn null into `citizen` — a signed-out user with a role.
      role: loggedIn ? UserRole.fromWire(json['role'] as String?) : null,
      userId: json['user_id'] as String?,
    );
  }
}

/// The locally cached profile, held between launches.
///
/// Carries exactly the fields no server response gives back on restore. The role
/// is stored too, but only as a fallback for rendering before `/api/me`
/// answers — the server's role always wins once it does.
class CachedUser {
  const CachedUser({
    required this.role,
    required this.uniqueId,
    this.fullName,
    this.email,
  });

  final UserRole role;
  final String uniqueId;
  final String? fullName;
  final String? email;

  Map<String, dynamic> toJson() => {
        'role': role.wireValue,
        'unique_id': uniqueId,
        'fullname': fullName,
        'email': email,
      };

  factory CachedUser.fromJson(Map<String, dynamic> json) {
    return CachedUser(
      role: UserRole.fromWire(json['role'] as String?),
      uniqueId: (json['unique_id'] as String?) ?? '',
      fullName: json['fullname'] as String?,
      email: json['email'] as String?,
    );
  }

  factory CachedUser.fromEntity(AuthUser user) => CachedUser(
        role: user.role,
        uniqueId: user.uniqueId,
        fullName: user.fullName,
        email: user.email,
      );

  AuthUser toEntity({UserRole? authoritativeRole, String? userId}) => AuthUser(
        role: authoritativeRole ?? role,
        uniqueId: uniqueId,
        fullName: fullName,
        email: email,
        userId: userId,
      );
}
