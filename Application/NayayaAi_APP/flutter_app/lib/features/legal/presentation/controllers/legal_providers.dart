import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/legal_remote_data_source.dart';
import '../../data/repositories/legal_repository_impl.dart';
import '../../domain/entities/legal_section.dart';
import '../../domain/repositories/legal_repository.dart';

final legalRemoteDataSourceProvider = Provider<LegalRemoteDataSource>(
  (ref) => LegalRemoteDataSource(ref.watch(dioClientProvider).dio),
);

final legalRepositoryProvider = Provider<LegalRepository>(
  (ref) => LegalRepositoryImpl(
    remote: ref.watch(legalRemoteDataSourceProvider),
  ),
);

/// The eight act codes.
///
/// Not `autoDispose`: they are the same eight every time, `IndiaLaw.db` is
/// read-only, and the picker at the top of the library would otherwise refetch
/// them on every visit to a screen an officer opens several times a shift.
final legalActsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(legalRepositoryProvider).acts(),
);

/// One section in full, keyed by `ACT/section`.
///
/// `autoDispose`, unlike [legalActsProvider]: the comparison tool can walk an
/// officer through a dozen sections in a sitting, and there is no reason to
/// hold the text of eleven of them.
final legalSectionProvider =
    FutureProvider.autoDispose.family<LegalSection, ({String act, String no})>(
  (ref, key) => ref.watch(legalRepositoryProvider).section(key.act, key.no),
);

/// A search across all eight acts, keyed on the query.
///
/// Behind `/api/search-sections?q=`, which is a different endpoint from the one
/// the library's per-act list pages through: it takes no page, returns a bare
/// array, and carries no section text. See [LegalSection.isSummary].
///
/// `autoDispose`, so the results of every word an officer has ever searched are
/// not held for the session.
final legalSearchProvider =
    FutureProvider.autoDispose.family<List<LegalSection>, String>(
  (ref, query) => ref.watch(legalRepositoryProvider).search(query),
);
