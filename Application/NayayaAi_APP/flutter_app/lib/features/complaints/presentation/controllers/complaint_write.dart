import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/entities/complaint.dart';
import '../../domain/entities/complaint_note.dart';
import '../../domain/entities/complaint_status.dart';
import 'complaint_filter_controller.dart';
import 'complaint_providers.dart';

/// The name every note this feature writes is signed with.
///
/// A provider of its own rather than a line inside [writeComplaintChange], for
/// two reasons. It is the feature's only dependency on authentication, and
/// naming it makes that one line rather than a hidden reach across features. And
/// it is the seam a test overrides: building the real [authControllerProvider]
/// starts a session restore and the splash hold behind it, which a test about
/// what an officer typed into a sheet has no business waiting on.
///
/// Empty when there is somehow no session. [ComplaintNote.append] substitutes
/// its own stand-in rather than writing an unsigned line.
final complaintAuthorProvider = Provider<String>(
  (ref) => ref.watch(authControllerProvider).user?.displayName ?? '',
);

/// The one write the complaints feature makes, in one place.
///
/// Responding, escalating and recording an FIR are the same `PATCH` with
/// different words in it, and they are issued from two different controllers —
/// the detail screen's actions and the FIR link that fires from wherever the
/// officer happens to be when the FIR is accepted. A free function rather than a
/// method on either, so neither has to reach into the other and there is exactly
/// one implementation of "stamp a note, send the triple, refresh the inbox".
///
/// Throws whatever the repository throws. Both callers map it to a [Failure] for
/// their own screen; swallowing it here would leave a complaint the officer
/// believes they have answered.
Future<Complaint> writeComplaintChange(
  Ref ref,
  Complaint current, {
  required ComplaintStatus status,
  required String note,
  String? firNo,
}) async {
  final updated = await ref.read(complaintRepositoryProvider).update(
        current,
        status: status,
        firNo: firNo,
        officerNotes: ComplaintNote.append(
          current.officerNotes,
          body: note,
          officer: ref.read(complaintAuthorProvider),
          // The same clock the date filter reads, so a test can pin both and
          // nothing in this feature reaches for `DateTime.now()` on its own.
          at: ref.read(complaintClockProvider)(),
        ),
      );

  // The inbox in memory no longer matches the table. Invalidated rather than
  // patched locally, so what the officer sees next is what the server holds —
  // including the `updated_at` only it can write. `complaintProvider` resolves
  // out of this list, so the detail screen refreshes from the same fetch.
  ref.invalidate(complaintsProvider);

  return updated;
}
