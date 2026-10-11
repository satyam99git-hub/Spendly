import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/missing_persons/domain/entities/confirmed_match.dart';
import 'package:nayaya_app/features/missing_persons/domain/entities/missing_person.dart';
import 'package:nayaya_app/features/missing_persons/domain/entities/sighting.dart';
import 'package:nayaya_app/features/missing_persons/domain/repositories/missing_person_repository.dart';

/// Scriptable [MissingPersonRepository].
class FakeMissingPersonRepository implements MissingPersonRepository {
  FakeMissingPersonRepository({
    List<MissingPerson>? people,
    this.matches = const [],
    this.sightingsByPerson = const {},
  }) : people = people ??
            [
              const MissingPerson(
                personId: 'MP_1',
                name: 'satyam gupta',
                age: '18',
                gender: 'Male',
                description: 'green shirt',
                photoPath: '/static/uploads/missing_persons/MP_1.jpg',
                lastSeenLocation: 'nalasopara',
                lastSeenDate: '2026-07-16',
                createdAt: '2026-07-17 05:54:59',
                statusRaw: 'Missing',
              ),
              const MissingPerson(
                personId: 'MP_2',
                name: 'anita rao',
                age: '12',
                gender: 'Female',
                description: 'black shirt',
                photoPath: '/static/uploads/missing_persons/MP_2.jpg',
                lastSeenLocation: 'virar',
                createdAt: '2026-07-01 14:18:10',
                statusRaw: 'Missing',
              ),
            ];

  List<MissingPerson> people;
  List<ConfirmedMatch> matches;
  Map<String, List<Sighting>> sightingsByPerson;

  Failure? listFailure;
  Failure? registerFailure;

  /// Stands in for the 403 the real endpoints answer a non-police caller with.
  Failure? policeOnlyFailure;

  Failure? sightingFailure;

  /// What [reportSighting] answers with when it does not fail.
  SightingResult sightingResult = const SightingResult(
    sightingId: 'SG_NEW',
    matchPercent: 72.4,
    isMatch: true,
    message: '✓ Match confirmed! Confidence: 72.4%',
  );
  Failure? statusFailure;

  /// What [register] returns.
  String newPersonId = 'MP_NEW';

  // ---- call log -------------------------------------------------------------

  final List<MissingPersonDraft> registered = [];

  /// Every sighting filed, in order. Named `sightingsFiled` rather than
  /// `sightings` because the interface already has a method by that name.
  final List<({String personId, String location, String photoName})>
      sightingsFiled = [];
  final List<({String personId, MissingPersonStatus status})> statuses = [];

  @override
  Future<List<MissingPerson>> all() async {
    if (listFailure != null) throw listFailure!;
    return people;
  }

  @override
  Future<String> register(MissingPersonDraft draft) async {
    registered.add(draft);
    if (registerFailure != null) throw registerFailure!;
    return newPersonId;
  }

  @override
  Future<List<Sighting>> sightings(String personId) async {
    if (policeOnlyFailure != null) throw policeOnlyFailure!;
    return sightingsByPerson[personId] ?? const [];
  }

  @override
  Future<SightingResult> reportSighting({
    required String personId,
    required String photoPath,
    required String photoName,
    required String location,
    String sightingDate = '',
  }) async {
    sightingsFiled
        .add((personId: personId, location: location, photoName: photoName));
    if (sightingFailure != null) throw sightingFailure!;
    return sightingResult;
  }

  @override
  Future<List<ConfirmedMatch>> confirmedMatches() async {
    if (policeOnlyFailure != null) throw policeOnlyFailure!;
    return matches;
  }

  @override
  Future<void> setStatus(String personId, MissingPersonStatus status) async {
    statuses.add((personId: personId, status: status));
    if (statusFailure != null) throw statusFailure!;
    people = people.where((p) => p.personId != personId).toList();
  }
}
