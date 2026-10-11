import '../../../../core/enums/user_role.dart';

/// A signed-in person, as the app understands them.
///
/// Assembled from more than one source, because no single server response
/// carries the whole picture:
///   - `POST /login` returns `role` and `unique_id`, but not the name or email
///   - the email is what the user typed on the sign-in form
///   - `GET /api/me` returns `role` and `user_id` on session restore, but
///     neither the name nor the unique ID
///
/// So the name, email and unique ID are cached locally at sign-in and re-read on
/// restore, while [role] is always taken from whichever server response is most
/// recent. That ordering matters: role drives access, so it must never be the
/// stale local copy when the server has said otherwise.
class AuthUser {
  const AuthUser({
    required this.role,
    required this.uniqueId,
    this.fullName,
    this.email,
    this.userId,
  });

  final UserRole role;

  /// Role-prefixed identifier, e.g. `CIT004`, `POL9999`. Empty only when a
  /// session was restored before any sign-in on this install cached one.
  final String uniqueId;

  /// Display name. Null when restored from a session whose cache was lost.
  final String? fullName;

  final String? email;

  /// The server's Mongo `_id`, as returned by `/api/me`. Not shown in the UI.
  final String? userId;

  /// What to greet the user with when the cached name is missing.
  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (uniqueId.isNotEmpty) return uniqueId;
    return role.label;
  }

  AuthUser copyWith({
    UserRole? role,
    String? uniqueId,
    String? fullName,
    String? email,
    String? userId,
  }) {
    return AuthUser(
      role: role ?? this.role,
      uniqueId: uniqueId ?? this.uniqueId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      userId: userId ?? this.userId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.role == role &&
          other.uniqueId == uniqueId &&
          other.fullName == fullName &&
          other.email == email &&
          other.userId == userId;

  @override
  int get hashCode => Object.hash(role, uniqueId, fullName, email, userId);

  @override
  String toString() => 'AuthUser($uniqueId, ${role.wireValue})';
}
