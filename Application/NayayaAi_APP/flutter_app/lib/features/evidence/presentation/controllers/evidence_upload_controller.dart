import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../data/datasources/evidence_file_picker.dart';
import '../../domain/entities/evidence_file.dart';
import '../../domain/entities/evidence_item.dart';
import 'evidence_providers.dart';

/// What the Add screen is doing.
enum EvidenceUploadStatus { editing, uploading, uploaded }

class EvidenceUploadState {
  const EvidenceUploadState({
    this.firNo = '',
    this.file,
    this.status = EvidenceUploadStatus.editing,
    this.showErrors = false,
    this.failure,
    this.uploaded,
  });

  /// The FIR the file is being filed against. Typed, not picked: the app has no
  /// endpoint that lists FIR numbers cheaply, and an officer adding evidence
  /// already has the number in front of them — it is what the complainant was
  /// given.
  final String firNo;

  /// Null until something has been chosen.
  final EvidenceFile? file;

  final EvidenceUploadStatus status;

  /// Whether the two required entries may show their message. False until the
  /// first refused Upload — see `FirFormController.submit` for the same rule and
  /// the same reason.
  final bool showErrors;

  final Failure? failure;

  /// Set exactly when [status] is [EvidenceUploadStatus.uploaded]. Carries the
  /// filename the *server* stored, which `secure_filename` may have rewritten.
  final EvidenceItem? uploaded;

  bool get isUploading => status == EvidenceUploadStatus.uploading;
  bool get isUploaded => status == EvidenceUploadStatus.uploaded;

  /// The required entries that are still missing, by their on-screen label.
  List<String> get missing => [
        if (firNo.trim().isEmpty) 'FIR number',
        if (file == null) 'File',
      ];

  bool get canUpload => missing.isEmpty;

  EvidenceUploadState copyWith({
    String? firNo,
    EvidenceFile? file,
    EvidenceUploadStatus? status,
    bool? showErrors,
    EvidenceItem? uploaded,
    bool clearFailure = false,
    Failure? failure,
  }) {
    return EvidenceUploadState(
      firNo: firNo ?? this.firNo,
      file: file ?? this.file,
      status: status ?? this.status,
      showErrors: showErrors ?? this.showErrors,
      failure: clearFailure ? null : (failure ?? this.failure),
      uploaded: uploaded ?? this.uploaded,
    );
  }
}

/// One upload, from picking a file to the server confirming it.
///
/// `autoDispose`, unlike the FIR form's controller, and the difference is the
/// point: an FIR is minutes of typing worth recovering, an upload is a FIR
/// number and a file chooser. Leaving the screen and coming back should offer a
/// clean form, not a half-finished one referring to a file the officer has
/// forgotten they picked.
final evidenceUploadControllerProvider = NotifierProvider.autoDispose<
    EvidenceUploadController, EvidenceUploadState>(
  EvidenceUploadController.new,
);

class EvidenceUploadController extends AutoDisposeNotifier<EvidenceUploadState> {
  @override
  EvidenceUploadState build() => const EvidenceUploadState();

  void setFirNo(String value) {
    if (state.isUploading || state.isUploaded) return;
    state = state.copyWith(firNo: value, clearFailure: true);
  }

  /// Opens the chooser for [source] and keeps whatever comes back.
  ///
  /// A dismissed picker leaves the state untouched — including any file already
  /// chosen. Cancelling out of "Choose a file" must not throw away the photo
  /// taken a moment earlier.
  Future<void> pick(EvidenceSource source) async {
    if (state.isUploading || state.isUploaded) return;

    try {
      final picked = await ref.read(evidenceFilePickerProvider).pick(source);
      if (picked == null) return;
      state = state.copyWith(file: picked, clearFailure: true);
    } catch (error) {
      // A denied camera or storage permission surfaces here as a
      // PlatformException. It is the officer's to resolve in system settings,
      // so it has to be said out loud rather than logged.
      state = state.copyWith(
        failure: UnknownFailure(
          message: 'Could not open the file chooser. Check that NyayaAI is '
              'allowed to use the camera and storage.',
          debugDetail: 'evidence pick ${source.name}: $error',
        ),
      );
    }
  }

  /// Sends it. Returns true when the server has the file.
  ///
  /// Never retried automatically, for the same reason the FIR is not: the server
  /// overwrites a file of the same name in the same FIR folder without saying
  /// so, and a silent retry after a timeout would be a second write against a
  /// row that may already exist.
  Future<bool> upload() async {
    if (state.isUploading || state.isUploaded) return false;

    if (!state.canUpload) {
      state = state.copyWith(showErrors: true, clearFailure: true);
      return false;
    }

    state = state.copyWith(
      status: EvidenceUploadStatus.uploading,
      clearFailure: true,
    );

    try {
      final item = await ref.read(evidenceRepositoryProvider).upload(
            firNo: state.firNo,
            file: state.file!,
          );

      // The locker's list is now stale by exactly one file. Invalidating rather
      // than appending locally keeps one source of truth: what the server says
      // is in the locker.
      ref.invalidate(allEvidenceProvider);
      ref.invalidate(evidenceForFirProvider(item.firNo));

      state = state.copyWith(
        status: EvidenceUploadStatus.uploaded,
        uploaded: item,
        clearFailure: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        status: EvidenceUploadStatus.editing,
        failure: ErrorMapper.map(error, context: 'upload-evidence'),
      );
      return false;
    }
  }
}
