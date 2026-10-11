import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../evidence/domain/entities/evidence_file.dart';
import '../../domain/entities/missing_person.dart';
import '../../domain/repositories/missing_person_repository.dart';
import 'missing_person_providers.dart';

/// Registering one missing person: the photograph, the details, the one call.
class MissingPersonFormState {
  const MissingPersonFormState({
    this.photo,
    this.busy = false,
    this.registeredId,
    this.failure,
  });

  /// The chosen photograph. Required by the server, and the reason the submit
  /// button refuses before it is set.
  final EvidenceFile? photo;

  final bool busy;

  /// The `person_id` the server minted, once it has.
  final String? registeredId;

  final Failure? failure;

  bool get hasPhoto => photo != null;
  bool get isRegistered => registeredId != null;

  MissingPersonFormState copyWith({
    EvidenceFile? photo,
    bool? busy,
    String? registeredId,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return MissingPersonFormState(
      photo: photo ?? this.photo,
      busy: busy ?? this.busy,
      registeredId: registeredId ?? this.registeredId,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

final missingPersonFormControllerProvider = NotifierProvider.autoDispose<
    MissingPersonFormController, MissingPersonFormState>(
  MissingPersonFormController.new,
);

class MissingPersonFormController
    extends AutoDisposeNotifier<MissingPersonFormState> {
  @override
  MissingPersonFormState build() => const MissingPersonFormState();

  /// Sets the photograph, replacing any previous one.
  ///
  /// Replaces rather than appends: the server registers one photograph per
  /// case and compares every sighting against it, so a second one is a
  /// correction and not an addition.
  void setPhoto(EvidenceFile file) {
    if (state.busy) return;
    state = state.copyWith(photo: file, clearFailure: true);
  }

  /// Files the case. Returns the new `person_id`, or null when it failed.
  ///
  /// **The face check happens server-side, during this call.** A photograph
  /// with no detectable face comes back as a 400 whose sentence tells the
  /// officer what to do about it, and that sentence is put on screen unchanged
  /// — "No face detected in the photo. Please upload a clear frontal image."
  /// is actionable in a way "Registration failed" is not.
  Future<String?> submit(
    MissingPersonDraft Function(String path, String name) build,
  ) async {
    final photo = state.photo;
    if (photo == null || state.busy) return null;

    state = state.copyWith(busy: true, clearFailure: true);

    try {
      final id = await ref
          .read(missingPersonRepositoryProvider)
          .register(build(photo.path, photo.name));

      // The register in memory no longer matches the server.
      ref.invalidate(missingPersonsProvider);

      state = state.copyWith(busy: false, registeredId: id);
      return id;
    } catch (error) {
      state = state.copyWith(
        busy: false,
        failure: ErrorMapper.map(error, context: 'upload_missing_person'),
      );
      return null;
    }
  }
}

/// Moving a case off `Missing`, which is a one-way door — see
/// [MissingPersonStatus].
final missingPersonStatusControllerProvider = NotifierProvider.autoDispose<
    MissingPersonStatusController, AsyncValue<void>>(
  MissingPersonStatusController.new,
);

class MissingPersonStatusController
    extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Returns true when the server accepted it.
  Future<bool> setStatus(String personId, MissingPersonStatus status) async {
    if (state.isLoading) return false;
    state = const AsyncValue.loading();

    try {
      await ref
          .read(missingPersonRepositoryProvider)
          .setStatus(personId, status);

      // The case has left the open list, and may have taken a confirmed match
      // with it — the matches endpoint joins on `status = 'Missing'`.
      ref
        ..invalidate(missingPersonsProvider)
        ..invalidate(confirmedMatchesProvider);

      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(
        ErrorMapper.map(error, context: 'update_missing_person_status'),
        stack,
      );
      return false;
    }
  }
}
