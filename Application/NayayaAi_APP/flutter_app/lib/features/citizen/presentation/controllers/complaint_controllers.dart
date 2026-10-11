import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../complaints/domain/entities/complaint.dart';
import '../../data/models/citizen_complaint_models.dart';
import 'citizen_providers.dart';

// ---- filing -----------------------------------------------------------------

/// The checks `submitComplaint()` makes before it sends anything, in its order
/// and with its words (citizen_dashboard.html:818-832). Null when the form may
/// be sent.
///
/// The phone rule is the one the website's code states — optional, exactly ten
/// digits when given. The website's own phone box cannot currently be filled
/// in (its id is wrong, see the parity spec W1); the project owner decided the
/// app follows the rule rather than the defect (decision D-1).
String? validateComplaint({
  required String name,
  required String phone,
  required String description,
}) {
  final n = name.trim();
  if (n.isEmpty || description.trim().isEmpty) {
    return 'Name and incident description are required.';
  }
  if (!RegExp(r'^[A-Za-z ]+$').hasMatch(n)) {
    return 'Name should only contain letters and spaces.';
  }
  final p = phone.trim();
  if (p.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(p)) {
    return 'Phone number must be exactly 10 digits.';
  }
  return null;
}

class ComplaintFormState {
  const ComplaintFormState({this.busy = false, this.receipt});

  final bool busy;

  /// Set once the complaint is filed. The website then hides the form and
  /// shows the tracking ID until the page is reloaded; the screen does the same.
  final ComplaintReceipt? receipt;
}

final complaintFormControllerProvider =
    NotifierProvider.autoDispose<ComplaintFormController, ComplaintFormState>(
  ComplaintFormController.new,
);

class ComplaintFormController extends AutoDisposeNotifier<ComplaintFormState> {
  bool _disposed = false;

  @override
  ComplaintFormState build() {
    ref.onDispose(() => _disposed = true);
    return const ComplaintFormState();
  }

  /// Returns the message the website would `alert()`, or null on success.
  Future<String?> submit(ComplaintSubmission submission) async {
    if (state.busy) return null;

    final invalid = validateComplaint(
      name: submission.fullName,
      phone: submission.phone,
      description: submission.incidentDescription,
    );
    if (invalid != null) return invalid;

    state = const ComplaintFormState(busy: true);
    try {
      final receipt =
          await ref.read(citizenComplaintRepositoryProvider).file(submission);
      if (!_disposed) state = ComplaintFormState(receipt: receipt);
      return null;
    } on Failure catch (failure) {
      if (!_disposed) state = const ComplaintFormState();
      return failure.message;
    }
  }
}

// ---- tracking ---------------------------------------------------------------

class TrackComplaintState {
  const TrackComplaintState({this.busy = false, this.complaint, this.error});

  final bool busy;
  final Complaint? complaint;

  /// Shown in the red box under the search, as `#trackError` is.
  final String? error;
}

final trackComplaintControllerProvider =
    NotifierProvider.autoDispose<TrackComplaintController, TrackComplaintState>(
  TrackComplaintController.new,
);

class TrackComplaintController
    extends AutoDisposeNotifier<TrackComplaintState> {
  bool _disposed = false;

  @override
  TrackComplaintState build() {
    ref.onDispose(() => _disposed = true);
    return const TrackComplaintState();
  }

  /// Returns the website's `alert` text for an empty ID, otherwise null. The
  /// previous result and error are cleared before the lookup, as
  /// `trackComplaint()` hides both first.
  Future<String?> track(String trackingId) async {
    final id = trackingId.trim();
    if (id.isEmpty) return 'Please enter your tracking ID.';
    if (state.busy) return null;

    state = const TrackComplaintState(busy: true);
    try {
      final complaint =
          await ref.read(citizenComplaintRepositoryProvider).track(id);
      if (!_disposed) state = TrackComplaintState(complaint: complaint);
    } on Failure catch (failure) {
      if (!_disposed) state = TrackComplaintState(error: failure.message);
    }
    return null;
  }
}
