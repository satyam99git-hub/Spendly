import '../../domain/entities/evidence_file.dart';
import '../../domain/entities/evidence_item.dart';
import '../../domain/repositories/evidence_repository.dart';
import '../datasources/evidence_remote_data_source.dart';

/// The evidence repository over the live server.
///
/// Thin by design, and with no local cache. The locker's whole point is that
/// what an officer sees is what the station holds; a cached list would show a
/// file that has since been replaced, or hide one a colleague uploaded a minute
/// ago, and neither is a mistake worth making to save a request.
class EvidenceRepositoryImpl implements EvidenceRepository {
  const EvidenceRepositoryImpl({required EvidenceRemoteDataSource remote})
      : _remote = remote;

  final EvidenceRemoteDataSource _remote;

  @override
  Future<bool> verifyPin(String pin) => _remote.verifyLockerPin(pin);

  @override
  Future<List<EvidenceItem>> all() => _remote.all();

  @override
  Future<List<EvidenceItem>> forFir(String firNo) {
    final trimmed = firNo.trim();
    // The endpoint answers `[]` for a blank `fir_no` anyway; not asking is one
    // fewer round trip on a screen that can be opened before a number is typed.
    if (trimmed.isEmpty) return Future.value(const []);
    return _remote.forFir(trimmed);
  }

  @override
  Future<EvidenceItem> upload({
    required String firNo,
    required EvidenceFile file,
  }) =>
      _remote.upload(firNo: firNo.trim(), file: file);

  @override
  Future<void> logAccess({
    required String firNo,
    required String filename,
    required String action,
  }) =>
      _remote.logAccess({
        'fir_no': firNo,
        'filename': filename,
        'action': action,
      });
}
