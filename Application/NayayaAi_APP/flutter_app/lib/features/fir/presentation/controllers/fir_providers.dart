import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/fir_pdf_store.dart';
import '../../data/datasources/fir_remote_data_source.dart';
import '../../data/repositories/fir_repository_impl.dart';
import '../../domain/repositories/fir_repository.dart';

/// The FIR feature's wiring.
///
/// These lived in `fir_form_controller.dart` while the form was the only thing
/// that needed them. They moved here when the history screen became a second
/// reader: leaving them there would have meant `fir_history_providers.dart`
/// importing the form's controller to reach the repository, and the form's
/// controller importing the history providers to invalidate the list after
/// filing — a cycle between two files that have nothing to say to each other.
///
/// `fir_form_controller.dart` re-exports this file, so every existing import of
/// [firRepositoryProvider] still resolves.

final firRemoteDataSourceProvider = Provider<FirRemoteDataSource>(
  (ref) => FirRemoteDataSource(ref.watch(dioClientProvider).dio),
);

final firRepositoryProvider = Provider<FirRepository>(
  (ref) => FirRepositoryImpl(remote: ref.watch(firRemoteDataSourceProvider)),
);

/// Where a downloaded PDF is written, and what opens it.
///
/// Overridden in tests with a store that answers from a temp directory, because
/// both halves of the real one need a platform channel — the same arrangement as
/// `evidenceFilePickerProvider`.
final firPdfStoreProvider = Provider<FirPdfStore>(
  (ref) => const PlatformFirPdfStore(),
);
