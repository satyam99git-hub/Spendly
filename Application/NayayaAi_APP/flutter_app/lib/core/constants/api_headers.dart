/// Request headers the NyayaAI server reads.
///
/// One header, but it lives in its own file for the same reason
/// [ApiEndpoints] does: the server's name for it is a contract, and a contract
/// that is spelled out in two places eventually gets spelled two ways.
abstract final class ApiHeaders {
  const ApiHeaders._();

  /// Identifies this client as the Flutter app rather than a browser page.
  ///
  /// The server's `require_same_origin` guard (see `app.py`) lets a request
  /// through when it carries either a trusted `Origin` or this header. The
  /// website has the first; a native app has neither an `Origin` nor any way to
  /// grow one, so without this every `POST`, `PUT`, `PATCH` and `DELETE` comes
  /// back **403 `{"error": "Request rejected."}`** — which is what used to make
  /// sign-in impossible from the app.
  ///
  /// It is a real CSRF defence and not a password: a cross-origin page cannot
  /// set a custom header without a CORS preflight, and the server answers none,
  /// so the browser never sends the request that would carry it. Its value is
  /// therefore not a secret and does not need to be one.
  static const appClient = 'X-NyayaAI-Client';

  /// Sent as [appClient]'s value. The server checks only that the header is
  /// present, so this is for server logs to read, not for it to match on.
  static const appClientValue = 'nyayaai-flutter';
}
