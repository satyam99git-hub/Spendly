import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/complaint_remote_data_source.dart';
import '../../data/repositories/complaint_repository_impl.dart';
import '../../domain/entities/complaint.dart';
import '../../domain/repositories/complaint_repository.dart';

/// The complaints feature's wiring, and the two providers everything reads.

final complaintRemoteDataSourceProvider = Provider<ComplaintRemoteDataSource>(
  (ref) => ComplaintRemoteDataSource(ref.watch(dioClientProvider).dio),
);

final complaintRepositoryProvider = Provider<ComplaintRepository>(
  (ref) => ComplaintRepositoryImpl(
    remote: ref.watch(complaintRemoteDataSourceProvider),
  ),
);

/// Every complaint the station has, newest arrival first.
///
/// Not `autoDispose`, like the FIR history and the evidence list: the inbox is a
/// tab an officer leaves and comes back to several times an hour, and
/// `GET /api/complaints/all` has no paging — a refetch is the whole table over a
/// station connection.
///
/// Refreshed by three things, and nothing polls:
///
///   - pull-to-refresh on the list, which is the only way to see a complaint
///     filed while the app was open;
///   - any response, escalation or FIR link written from this device, because
///     `ComplaintActionController` invalidates it;
///   - the FIR link that lands when a complaint is converted, for the same
///     reason.
final complaintsProvider = FutureProvider<List<Complaint>>(
  (ref) => ref.watch(complaintRepositoryProvider).all(),
);

/// One complaint, by its tracking ID.
///
/// ---------------------------------------------------------------------------
/// WHY THIS READS THE LIST INSTEAD OF `GET /api/complaint/<id>`
///
/// The single-complaint handler does not select `phone`. An officer opening a
/// complaint is usually about to ring the person who filed it, so a detail
/// screen built on that endpoint would be missing the one thing they came for.
///
/// The list has every column, is already in memory, and is invalidated by every
/// write — so resolving out of it also means the detail screen updates itself
/// the moment a response is saved, with no second fetch and no chance of the
/// two screens disagreeing about the same complaint.
///
/// The direct endpoint is still the fallback, for the case the list genuinely
/// cannot answer: a deep link into a complaint filed since the list was loaded,
/// or a return from process death. A phone number missing on that path is worth
/// far more than a "not found" would be.
/// ---------------------------------------------------------------------------
final complaintProvider =
    FutureProvider.autoDispose.family<Complaint, String>((ref, trackingId) async {
  final id = trackingId.trim().toUpperCase();

  final all = await ref.watch(complaintsProvider.future);
  for (final complaint in all) {
    if (complaint.trackingId == id) return complaint;
  }

  return ref.watch(complaintRepositoryProvider).byTrackingId(id);
});
