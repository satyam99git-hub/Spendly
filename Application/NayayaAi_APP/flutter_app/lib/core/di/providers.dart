import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import '../storage/secure_storage_service.dart';

/// Application-wide singletons.
///
/// Feature-specific providers live with their feature; only things more than one
/// feature will need belong here.

/// The configured HTTP client.
///
/// Overridden in `main()` with the instance built by `bootstrap()`. It has no
/// default because construction is async (it opens the cookie jar's directory)
/// and a provider cannot await — so reading this without the override is a
/// wiring bug, and the [UnimplementedError] says so immediately rather than
/// letting a second, session-less client be created silently.
final dioClientProvider = Provider<DioClient>((ref) {
  throw UnimplementedError(
    'dioClientProvider must be overridden in main() with the DioClient from '
    'bootstrap(). See bootstrap.dart.',
  );
});

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService.standard(),
);
