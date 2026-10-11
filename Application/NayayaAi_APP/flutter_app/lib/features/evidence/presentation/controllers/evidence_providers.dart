import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/evidence_file_picker.dart';
import '../../data/datasources/evidence_remote_data_source.dart';
import '../../data/repositories/evidence_repository_impl.dart';
import '../../domain/entities/evidence_item.dart';
import '../../domain/repositories/evidence_repository.dart';

final evidenceRemoteDataSourceProvider = Provider<EvidenceRemoteDataSource>(
  (ref) => EvidenceRemoteDataSource(ref.watch(dioClientProvider).dio),
);

final evidenceRepositoryProvider = Provider<EvidenceRepository>(
  (ref) => EvidenceRepositoryImpl(
    remote: ref.watch(evidenceRemoteDataSourceProvider),
  ),
);

/// Overridden in tests with a picker that returns a scripted file, because
/// `image_picker` and `file_picker` both need a platform channel.
final evidenceFilePickerProvider = Provider<EvidenceFilePicker>(
  (ref) => PlatformEvidenceFilePicker(),
);

/// The whole locker.
///
/// Not `autoDispose`, so switching to the FIR tab and back does not re-fetch —
/// but explicitly invalidated after every upload, which is the only thing that
/// changes it from this device. A colleague's upload is picked up by the list's
/// pull-to-refresh; nothing here polls, because a locker that reloads itself on
/// a timer is a locker that reloads while someone is reading it.
final allEvidenceProvider = FutureProvider<List<EvidenceItem>>(
  (ref) => ref.watch(evidenceRepositoryProvider).all(),
);

/// One FIR's files, with the metadata `allEvidenceProvider` cannot carry.
///
/// `.family` keyed on the FIR number, and `autoDispose` because the detail
/// screen is the only reader: holding every FIR an officer has ever opened would
/// keep timestamps around long after they stopped being current.
final evidenceForFirProvider =
    FutureProvider.autoDispose.family<List<EvidenceItem>, String>(
  (ref, firNo) => ref.watch(evidenceRepositoryProvider).forFir(firNo),
);
