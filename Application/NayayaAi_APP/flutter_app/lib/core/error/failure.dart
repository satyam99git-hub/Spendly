/// What the domain layer throws. One closed set, so a `switch` over a failure
/// is exhaustive and adding a new kind breaks compilation at every site that
/// has to care.
///
/// Every failure carries a [message] that is safe to show a user directly.
/// Diagnostic detail goes in [debugDetail], which is for logs only and must
/// never reach the screen -- it can contain URLs, payloads and stack context.
sealed class Failure implements Exception {
  const Failure(this.message, {this.debugDetail});

  /// User-facing, already phrased for display.
  final String message;

  /// Developer-facing. Logged, never rendered.
  final String? debugDetail;

  @override
  String toString() {
    final detail = debugDetail;
    return '$runtimeType: $message${detail == null ? '' : ' ($detail)'}';
  }
}

/// The server was unreachable, or took too long.
///
/// Kept distinct from [ServerFailure] because it is the one kind worth offering
/// a Retry button for: nothing is wrong with the request, so repeating it
/// unchanged is a reasonable thing to do.
final class NetworkFailure extends Failure {
  const NetworkFailure({
    String message =
        'Cannot reach the NyayaAI server. Check your connection and try again.',
    String? debugDetail,
  }) : super(message, debugDetail: debugDetail);
}

/// The server answered, but with a fault of its own (5xx, or a body that did
/// not parse). Retrying rarely helps, so the copy does not invite it.
final class ServerFailure extends Failure {
  const ServerFailure({
    String message = 'The server ran into a problem. Please try again later.',
    String? debugDetail,
  }) : super(message, debugDetail: debugDetail);
}

/// Credentials were rejected, or a session that was assumed valid was not.
///
/// [sessionExpired] separates "you typed the wrong password" from "you were
/// signed in and no longer are" -- the second needs to bounce the user to
/// sign-in, the first must not.
final class AuthFailure extends Failure {
  const AuthFailure({
    String message = 'Invalid email or password.',
    String? debugDetail,
    this.sessionExpired = false,
  }) : super(message, debugDetail: debugDetail);

  final bool sessionExpired;

  const AuthFailure.sessionExpired({
    String message = 'Your session has ended. Please sign in again.',
    String? debugDetail,
  })  : sessionExpired = true,
        super(message, debugDetail: debugDetail);
}

/// The server rejected the input (HTTP 400) and said why.
///
/// The message is passed through verbatim, because this server's 400s are
/// already written for humans -- "Email already registered", "Unique ID for
/// police must start with POL". Rewording them client-side would mean
/// maintaining a second copy of rules that live on the server.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.debugDetail});
}

/// Nothing else fit. Always logged with detail so it can be reclassified.
final class UnknownFailure extends Failure {
  const UnknownFailure({
    String message = 'Something went wrong. Please try again.',
    String? debugDetail,
  }) : super(message, debugDetail: debugDetail);
}
