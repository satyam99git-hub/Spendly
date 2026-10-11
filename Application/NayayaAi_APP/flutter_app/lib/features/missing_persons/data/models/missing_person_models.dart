import '../../domain/entities/confirmed_match.dart';
import '../../domain/entities/missing_person.dart';
import '../../domain/entities/sighting.dart';

/// One row of `GET /get_missing_persons`.
class MissingPersonResponse {
  const MissingPersonResponse._();

  static MissingPerson fromJson(Map<String, dynamic> json) {
    return MissingPerson(
      personId: _text(json, 'person_id'),
      name: _text(json, 'name'),
      // INTEGER column, nullable. Read as text — see [MissingPerson.age].
      age: _text(json, 'age'),
      gender: _text(json, 'gender'),
      description: _text(json, 'description'),
      photoPath: _text(json, 'photo_url'),
      lastSeenLocation: _text(json, 'last_seen_location'),
      lastSeenDate: _text(json, 'last_seen_date'),
      createdAt: _text(json, 'created_at'),
      statusRaw: _text(json, 'status'),
    );
  }
}

/// One row of `GET /get_sightings/<person_id>`.
class SightingResponse {
  const SightingResponse._();

  static Sighting fromJson(Map<String, dynamic> json) {
    return Sighting(
      sightingId: _text(json, 'sighting_id'),
      photoPath: _text(json, 'photo_url'),
      location: _text(json, 'location'),
      sightingDate: _text(json, 'sighting_date'),
      // Raw 0-1 here, unlike the already-multiplied `confidence` on a confirmed
      // match. Normalised to a percentage so the app has one number.
      matchPercent: _double(json, 'face_match_score') * 100,
      isConfirmed: _bool(json, 'is_confirmed'),
      uploadedAt: _text(json, 'uploaded_at'),
    );
  }
}

/// The answer to `POST /report_sighting/<person_id>`.
class SightingResultResponse {
  const SightingResultResponse._();

  static SightingResult fromJson(Map<String, dynamic> json) {
    return SightingResult(
      sightingId: _text(json, 'sighting_id'),
      matchPercent: _double(json, 'face_match_score') * 100,
      isMatch: _bool(json, 'is_match'),
      message: _text(json, 'message'),
      details: _text(json, 'details'),
    );
  }
}

/// One entry of `confirmed_matches`.
///
/// The envelope is doubly redundant: the group carries a `sighting_photo`,
/// `location`, `sighting_date` and `confidence` for the best sighting *and* a
/// `sightings` array that starts with the same one. The array is read, and the
/// flat copy is used only when the array is missing — which is what the
/// handler's own "backward compat with frontend fallback" comment describes.
class ConfirmedMatchResponse {
  const ConfirmedMatchResponse._();

  static ConfirmedMatch fromJson(Map<String, dynamic> json) {
    final rows = json['sightings'];

    final sightings = rows is List && rows.isNotEmpty
        ? rows
            .whereType<Map>()
            .map((row) => _grouped(row.cast<String, dynamic>()))
            .toList()
        : [
            // The flat fallback. Only reachable against a server whose handler
            // does not send the array.
            Sighting(
              sightingId: '',
              photoPath: _text(json, 'sighting_photo'),
              location: _text(json, 'location'),
              sightingDate: _text(json, 'sighting_date'),
              matchPercent: _double(json, 'confidence'),
              isConfirmed: true,
              uploadedAt: _text(json, 'uploaded_at'),
            ),
          ];

    return ConfirmedMatch(
      personId: _text(json, 'person_id'),
      name: _text(json, 'name'),
      personPhotoPath: _text(json, 'missing_person_photo'),
      sightings: sightings,
    );
  }

  /// One entry of the nested `sightings` array, whose keys are shorter than
  /// [SightingResponse]'s and whose `score` is already a percentage.
  static Sighting _grouped(Map<String, dynamic> json) {
    return Sighting(
      // The nested rows carry no ID — the handler does not select one — so
      // there is nothing to address an individual confirmed sighting by.
      sightingId: '',
      photoPath: _text(json, 'photo'),
      location: _text(json, 'location'),
      sightingDate: _text(json, 'date'),
      // Already 0-100 here. Multiplying again would report every match as
      // several thousand per cent.
      matchPercent: _double(json, 'score'),
      isConfirmed: true,
    );
  }
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value == null ? '' : value.toString().trim();
}

double _double(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

/// SQLite has no boolean, so `is_confirmed` can arrive as 0/1 from a raw row or
/// as a real boolean from a handler that cast it — this one does, but the other
/// endpoints in the same blueprint do not, so both are read.
bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = '${value ?? ''}'.trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}
