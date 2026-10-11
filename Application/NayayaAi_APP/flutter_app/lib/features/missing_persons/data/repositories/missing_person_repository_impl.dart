import '../../domain/entities/confirmed_match.dart';
import '../../domain/entities/missing_person.dart';
import '../../domain/entities/sighting.dart';
import '../../domain/repositories/missing_person_repository.dart';
import '../datasources/missing_person_remote_data_source.dart';

/// The missing-persons register over the live server.
///
/// Thin: the server sorts, filters to open cases and groups the matches, so
/// there is nothing left to arrange. What it does is trim, because the forms
/// behind it are free-text and the server stores whatever arrives — a name with
/// a trailing space becomes a name with a trailing space in the register, and
/// nothing ever finds it again.
class MissingPersonRepositoryImpl implements MissingPersonRepository {
  const MissingPersonRepositoryImpl({
    required MissingPersonRemoteDataSource remote,
  }) : _remote = remote;

  final MissingPersonRemoteDataSource _remote;

  @override
  Future<List<MissingPerson>> all() => _remote.all();

  @override
  Future<String> register(MissingPersonDraft draft) => _remote.register(
        MissingPersonDraft(
          name: draft.name.trim(),
          photoPath: draft.photoPath,
          photoName: draft.photoName,
          age: draft.age.trim(),
          gender: draft.gender.trim(),
          description: draft.description.trim(),
          lastSeenLocation: draft.lastSeenLocation.trim(),
          lastSeenDate: draft.lastSeenDate.trim(),
        ),
      );

  @override
  Future<List<Sighting>> sightings(String personId) =>
      _remote.sightings(personId.trim());

  @override
  Future<SightingResult> reportSighting({
    required String personId,
    required String photoPath,
    required String photoName,
    required String location,
    String sightingDate = '',
  }) =>
      _remote.reportSighting(
        personId: personId.trim(),
        photoPath: photoPath,
        photoName: photoName,
        location: location.trim(),
        sightingDate: sightingDate.trim(),
      );

  @override
  Future<List<ConfirmedMatch>> confirmedMatches() => _remote.confirmedMatches();

  @override
  Future<void> setStatus(String personId, MissingPersonStatus status) =>
      _remote.setStatus(personId.trim(), status);
}
