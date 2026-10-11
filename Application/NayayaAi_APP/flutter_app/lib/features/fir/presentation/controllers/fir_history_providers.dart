import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/fir_record.dart';
import 'fir_providers.dart';

/// Every FIR in police records, newest first.
///
/// Not `autoDispose`, so leaving the history for a record and coming back does
/// not re-fetch the whole collection — the same call the evidence locker's list
/// makes, and for the same reason: `GET /api/fir-records` has no paging, so a
/// refetch is the entire station's records over a station connection.
///
/// Refreshed by exactly two things, and nothing polls:
///
///   - pull-to-refresh on the list, which is the only way to see an FIR a
///     colleague filed;
///   - filing one from this device — `FirFormController.submit` invalidates it,
///     so the receipt screen's "Done" leads to a history that already contains
///     the FIR the officer just filed rather than to one that is missing it.
final firHistoryProvider = FutureProvider<List<FirRecord>>(
  (ref) => ref.watch(firRepositoryProvider).history(),
);

/// One record, fetched by its number.
///
/// The viewer reads this rather than being handed a record from the list, so it
/// can rebuild itself from its URL after a process death and so it shows what
/// the server holds *now* — the history in memory may have been loaded an hour
/// ago. It is the same decision the evidence detail screen makes, for the same
/// reasons.
///
/// `autoDispose`, unlike the history: holding every record an officer has opened
/// would keep a growing copy of the collection alive for no benefit, since each
/// one is re-read on open anyway.
final firRecordProvider = FutureProvider.autoDispose.family<FirRecord, String>(
  (ref, firNo) => ref.watch(firRepositoryProvider).record(firNo),
);
