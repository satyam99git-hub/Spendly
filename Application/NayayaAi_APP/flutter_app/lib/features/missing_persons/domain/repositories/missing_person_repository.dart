import '../entities/confirmed_match.dart';
import '../entities/missing_person.dart';
import '../entities/sighting.dart';

/// A photograph and the details that go with it, on its way to being
/// registered.
///
/// Carries the picked file's path rather than its bytes, for the same reason
/// `EvidenceFile` does: putting `dart:io` in this signature would mean the
/// controller could not be driven in a test without a filesystem.
class MissingPersonDraft {
  const MissingPersonDraft({
    required this.name,
    required this.photoPath,
    required this.photoName,
    this.age = '',
    this.gender = '',
    this.description = '',
    this.lastSeenLocation = '',
    this.lastSeenDate = '',
  });

  /// The one field the server requires.
  final String name;

  final String photoPath;
  final String photoName;

  final String age;
  final String gender;
  final String description;
  final String lastSeenLocation;
  final String lastSeenDate;
}

/// What the missing-persons screens need from the server.
///
/// Every method throws `Failure` and nothing else.
///
/// **These endpoints really do check the session**, unlike the FIR and evidence
/// routes. A signed-out or non-police caller gets a 403 with the server's own
/// sentence, which reaches the UI as an [AuthFailure] the screen has to show —
/// it is not a state the router's guard can make unreachable, because the
/// session can expire while the screen is open.
abstract interface class MissingPersonRepository {
  /// Every case still marked Missing, newest first.
  ///
  /// Cases marked Found or Closed are gone from this list and from every other
  /// endpoint; see `ApiEndpoints.missingPersons`.
  Future<List<MissingPerson>> all();

  /// Registers a case. Police only, server-enforced.
  ///
  /// Rejected with a [ValidationFailure] carrying the server's wording when the
  /// photograph has no detectable face — which is a normal outcome of pointing
  /// a camera at a printed poster, not a fault.
  ///
  /// Returns the `person_id` the server minted.
  Future<String> register(MissingPersonDraft draft);

  /// Every sighting against one case, newest first. Police only.
  Future<List<Sighting>> sightings(String personId);

  /// Files a sighting: a photograph, where, and when.
  ///
  /// Any signed-in role. The face comparison runs during the call, so the
  /// result says on the spot whether it matched.
  Future<SightingResult> reportSighting({
    required String personId,
    required String photoPath,
    required String photoName,
    required String location,
    String sightingDate,
  });

  /// The confirmed matches across every open case, grouped by person. Police
  /// only.
  Future<List<ConfirmedMatch>> confirmedMatches();

  /// Moves a case to [status]. Police only.
  ///
  /// Anything but [MissingPersonStatus.missing] removes it from [all] with no
  /// way back through this API.
  Future<void> setStatus(String personId, MissingPersonStatus status);
}
