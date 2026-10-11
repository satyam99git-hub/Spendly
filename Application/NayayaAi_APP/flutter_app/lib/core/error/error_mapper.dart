import 'package:dio/dio.dart';

import 'failure.dart';

/// Turns transport-level errors into domain [Failure]s.
///
/// This is the only place in the app that knows what a [DioException] is.
/// Everything above the data layer sees failures, which is what lets the
/// networking package be swapped without touching a controller or a screen.
abstract final class ErrorMapper {
  const ErrorMapper._();

  static Failure map(Object error, {String? context}) {
    if (error is Failure) return error;
    if (error is DioException) return _fromDio(error, context);

    return UnknownFailure(debugDetail: '$context: $error');
  }

  static Failure _fromDio(DioException e, String? context) {
    final detail = '$context: ${e.type.name} ${e.requestOptions.path}';

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      // Raised when decoding a response outruns its budget. Rare, but it is a
      // timeout and reads to the user like any other slow-connection failure.
      case DioExceptionType.transformTimeout:
        return NetworkFailure(
          message:
              'The server took too long to respond. Check your connection and '
              'try again.',
          debugDetail: detail,
        );

      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return NetworkFailure(debugDetail: '$detail — ${e.message}');

      case DioExceptionType.cancel:
        return const UnknownFailure(
          message: 'The request was cancelled.',
          debugDetail: 'request cancelled',
        );

      case DioExceptionType.badResponse:
        return _fromStatus(e, detail);

      case DioExceptionType.unknown:
        // Dio reports a dead socket as `unknown` wrapping a SocketException,
        // which is a connectivity problem and should read like one rather than
        // like a generic crash.
        final inner = e.error;
        if (inner is Exception && '$inner'.contains('SocketException')) {
          return NetworkFailure(debugDetail: '$detail — $inner');
        }
        return UnknownFailure(debugDetail: '$detail — ${e.message}');
    }
  }

  static Failure _fromStatus(DioException e, String detail) {
    final status = e.response?.statusCode ?? 0;
    final serverMessage = extractMessage(e.response?.data);

    if (status >= 500) {
      return ServerFailure(debugDetail: '$detail — HTTP $status');
    }

    switch (status) {
      case 400:
        return ValidationFailure(
          serverMessage ?? 'The details you entered were not accepted.',
          debugDetail: '$detail — HTTP 400',
        );

      case 401:
        return AuthFailure(
          message: serverMessage ?? 'Invalid email or password.',
          debugDetail: '$detail — HTTP 401',
        );

      case 403:
        return ValidationFailure(
          serverMessage ?? 'You do not have permission to do that.',
          debugDetail: '$detail — HTTP 403',
        );

      case 404:
        return ValidationFailure(
          serverMessage ?? 'Not found.',
          debugDetail: '$detail — HTTP 404',
        );

      default:
        return UnknownFailure(
          message: serverMessage ?? 'Something went wrong. Please try again.',
          debugDetail: '$detail — HTTP $status',
        );
    }
  }

  /// Digs the human-readable line out of an error body.
  ///
  /// This server is not consistent: `/login` and `/signup` use `{"error": ...}`,
  /// the missing-persons blueprint uses `{"success": false, "error": ...}`, and
  /// some handlers use `{"message": ...}`. Rather than make each data source
  /// know which, they all come through here.
  ///
  /// Returns null for an HTML error page — Flask's debug 500 is a full document,
  /// and putting that in a snackbar would be worse than the generic fallback.
  static String? extractMessage(Object? data) {
    if (data is Map) {
      for (final key in const ['error', 'message', 'detail']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      // An HTML document, not a message.
      if (trimmed.startsWith('<')) return null;
      // Long bodies are almost certainly not a sentence meant for a human.
      if (trimmed.length > 200) return null;
      return trimmed;
    }

    return null;
  }
}
