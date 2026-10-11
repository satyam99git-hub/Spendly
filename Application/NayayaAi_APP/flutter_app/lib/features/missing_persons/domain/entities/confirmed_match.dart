import 'missing_person.dart';
import 'sighting.dart';

/// A missing person the face comparison has matched to at least one sighting.
///
/// Grouped by person server-side rather than one row per sighting, because the
/// question this list answers is "who has been found?" and three sightings of
/// the same child are one answer, not three.
///
/// [best] is the highest-scoring of them — the handler orders by score, so it
/// is simply the first — and is what the card leads with. The rest are behind
/// it: an officer deciding whether to act wants the strongest evidence first
/// and the corroboration second.
class ConfirmedMatch {
  const ConfirmedMatch({
    required this.personId,
    this.name = '',
    this.personPhotoPath = '',
    this.sightings = const [],
  });

  final String personId;
  final String name;

  /// The registered photograph, server-relative. Shown beside the sighting so
  /// an officer can judge the match themselves rather than taking the score's
  /// word for it — which matters at a tolerance of 0.55.
  final String personPhotoPath;

  /// Every confirmed sighting for this person, strongest first.
  final List<Sighting> sightings;

  Sighting? get best => sightings.isEmpty ? null : sightings.first;

  /// How many *other* sightings there are behind [best].
  int get otherCount => sightings.isEmpty ? 0 : sightings.length - 1;

  /// The absolute URL of the registered photograph. Same join as
  /// [MissingPerson.photoUrl], and it has to agree with it — the two pictures
  /// on this card come from the same static root.
  String photoUrl(String baseUrl) => MissingPerson(
        personId: personId,
        photoPath: personPhotoPath,
      ).photoUrl(baseUrl);

  @override
  String toString() => 'ConfirmedMatch($personId, ${sightings.length})';
}
