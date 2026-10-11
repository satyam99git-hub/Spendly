import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';

/// Turns an error from a citizen endpoint into the sentence the website shows.
///
/// The app's shared `ErrorMapper` phrases failures for the police console. The
/// citizen screens reproduce the website instead, and every citizen page on it
/// handles a failed `fetch` the same way:
///
///   - the server answered with JSON → show its `error`, or the page's own
///     fallback when there is none (`data.error || 'Submission failed.'`);
///   - anything else — no connection, a timeout, or a body that is not JSON,
///     which is what `res.json()` throws on — → the page's network sentence.
///
/// The last case includes a Flask 500 debug page. The website cannot read it
/// and says "Network error…"; so does the app, rather than claiming to know
/// more than the page does.
Failure citizenFailure(
  Object error, {
  required String fallback,
  required String network,
  required String context,
}) {
  if (error is Failure) return error;

  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map) {
      final message = body['error'];
      return ValidationFailure(
        message is String && message.trim().isNotEmpty
            ? message.trim()
            : fallback,
        debugDetail: '$context: HTTP ${error.response?.statusCode}',
      );
    }
    return NetworkFailure(
      message: network,
      debugDetail: '$context: ${error.type.name} '
          'HTTP ${error.response?.statusCode}',
    );
  }

  // A 2xx whose body could not be read.
  return NetworkFailure(message: network, debugDetail: '$context: $error');
}

/// Guards a 2xx body that should be a JSON object.
Map<String, dynamic> citizenJsonObject(Object? data, String context) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw FormatException('$context: expected a JSON object');
}
