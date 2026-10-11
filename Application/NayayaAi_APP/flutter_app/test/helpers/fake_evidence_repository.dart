import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/evidence/data/datasources/evidence_file_picker.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_category.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_file.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_item.dart';
import 'package:nayaya_app/features/evidence/domain/repositories/evidence_repository.dart';

/// Scriptable [EvidenceRepository].
///
/// Hand-written rather than mocked, for the same reason as `FakeFirRepository`:
/// five methods, and a fake that records what it was handed reads better in a
/// failing test than a mock's verification syntax.
class FakeEvidenceRepository implements EvidenceRepository {
  FakeEvidenceRepository({
    List<EvidenceItem>? items,
    this.perFir = const {},
  }) : items = items ??
            [
              const EvidenceItem(
                firNo: 'FIR001',
                filename: 'scene.jpg',
                category: EvidenceCategory.image,
              ),
              const EvidenceItem(
                firNo: 'FIR001',
                filename: 'statement.pdf',
                category: EvidenceCategory.pdf,
              ),
              const EvidenceItem(
                firNo: 'FIR002',
                filename: 'cctv.mp4',
                category: EvidenceCategory.video,
              ),
            ];

  /// What [all] returns.
  List<EvidenceItem> items;

  /// What [forFir] returns, per FIR number. Falls back to filtering [items], so
  /// a test only overrides this when it cares about the metadata that
  /// `/get-all-evidence` cannot carry.
  Map<String, List<EvidenceItem>> perFir;

  Failure? listFailure;
  Failure? uploadFailure;

  /// Thrown by [verifyPin] instead of answering. Stands in for an unreachable
  /// server, which the gate has to tell apart from a rejected PIN.
  Failure? verifyFailure;

  /// The PIN [verifyPin] accepts. The real server compares against its own
  /// constant; a test only needs *a* right answer and *a* wrong one.
  String acceptedPin = 'secure@123';

  /// Every PIN sent to the server, in order.
  final List<String> pinAttempts = [];

  /// Artificial latency, so a test can observe the in-flight state.
  Duration delay = Duration.zero;

  // ---- call log -------------------------------------------------------------

  /// Every upload attempted, in order. Length is the assertion that a
  /// double-tap did not file two copies.
  final List<({String firNo, EvidenceFile file})> uploads = [];

  final List<({String firNo, String filename, String action})> accessLog = [];

  @override
  Future<bool> verifyPin(String pin) async {
    pinAttempts.add(pin);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (verifyFailure != null) throw verifyFailure!;
    return pin == acceptedPin;
  }

  @override
  Future<List<EvidenceItem>> all() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = listFailure;
    if (failure != null) throw failure;
    return items;
  }

  @override
  Future<List<EvidenceItem>> forFir(String firNo) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = listFailure;
    if (failure != null) throw failure;
    return perFir[firNo] ?? items.where((item) => item.firNo == firNo).toList();
  }

  @override
  Future<EvidenceItem> upload({
    required String firNo,
    required EvidenceFile file,
  }) async {
    uploads.add((firNo: firNo, file: file));
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = uploadFailure;
    if (failure != null) throw failure;

    final item = EvidenceItem(
      firNo: firNo,
      filename: file.name,
      category: EvidenceCategory.fromExtension(file.name),
    );
    items = [...items, item];
    return item;
  }

  @override
  Future<void> logAccess({
    required String firNo,
    required String filename,
    required String action,
  }) async {
    accessLog.add((firNo: firNo, filename: filename, action: action));
  }
}

/// An [EvidenceFilePicker] that hands back a file without a platform channel.
class FakeEvidenceFilePicker implements EvidenceFilePicker {
  FakeEvidenceFilePicker({this.result, this.error});

  /// Returned by every [pick]. Null models a dismissed chooser.
  EvidenceFile? result;

  /// Thrown instead — a denied camera permission, in practice.
  Object? error;

  final List<EvidenceSource> asked = [];

  @override
  Future<EvidenceFile?> pick(EvidenceSource source) async {
    asked.add(source);
    final failure = error;
    if (failure != null) throw failure;
    return result;
  }
}
