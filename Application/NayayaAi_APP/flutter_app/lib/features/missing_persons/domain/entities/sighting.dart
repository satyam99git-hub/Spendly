import '../../../../core/utils/server_time.dart';

/// One sighting reported against a missing-person case.
///
/// Reported by anyone signed in, not only police — `/report_sighting/<id>` says
/// so explicitly. The server compares the submitted photograph against the
/// registered one and stores the comparison either way, so this list holds the
/// near-misses as well as the matches. That is deliberate: a 48% match on a
/// blurred photograph from the right neighbourhood is worth an officer's eye,
/// and a list that hid it would be hiding the one lead there was.
class Sighting {
  const Sighting({
    required this.sightingId,
    this.photoPath = '',
    this.location = '',
    this.sightingDate = '',
    this.matchPercent = 0,
    this.isConfirmed = false,
    this.uploadedAt = '',
  });

  /// `SG_1A2B3C4D5E6F`, minted by the server.
  final String sightingId;

  /// Server-relative, `/`-prefixed. See [MissingPerson.photoUrl] for why the
  /// join lives on the entity.
  final String photoPath;

  final String location;

  /// When the person was seen, as reported. Defaults server-side to the day the
  /// sighting was filed when the reporter left it blank.
  final String sightingDate;

  /// How confident the face comparison was, **0 to 100**.
  ///
  /// Normalised here because the server sends it two ways: `/get_sightings`
  /// gives the raw 0–1 score as `face_match_score`, and
  /// `/get_confirmed_matches` gives an already-rounded percentage as
  /// `confidence`. One number in this app, whichever endpoint it came from.
  final double matchPercent;

  /// The server's own verdict at its tolerance of 0.55. Not derived from
  /// [matchPercent] here — the threshold is the server's to change, and a client
  /// that re-derived it would start disagreeing with the website the day it did.
  final bool isConfirmed;

  /// SQLite's `CURRENT_TIMESTAMP`, UTC.
  final String uploadedAt;

  bool get hasPhoto => photoPath.trim().isNotEmpty;

  /// `72%`. Rounded for display; nobody acts on the decimal.
  String get matchLabel => '${matchPercent.round()}%';

  DateTime? get reportedAt => ServerTime.parse(uploadedAt);
  String get reportedAtDisplay => ServerTime.display(uploadedAt);

  @override
  String toString() => 'Sighting($sightingId, $matchLabel)';
}

/// What came back from filing one sighting.
///
/// The face comparison runs during the request, so the reporter is told on the
/// spot whether it matched. Both outcomes are a success: the sighting is on the
/// record either way, and only [isMatch] differs.
class SightingResult {
  const SightingResult({
    required this.sightingId,
    this.matchPercent = 0,
    this.isMatch = false,
    this.message = '',
    this.details = '',
  });

  final String sightingId;
  final double matchPercent;
  final bool isMatch;

  /// The server's own sentence, e.g. `✓ Match confirmed! Confidence: 72.4%`.
  /// Shown verbatim.
  final String message;

  /// Whatever the comparison had to say about itself. Empty in demo mode, where
  /// `face_recognition` is not installed.
  final String details;

  String get matchLabel => '${matchPercent.round()}%';
}
