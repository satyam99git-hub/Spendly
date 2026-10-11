import '../../../../core/utils/server_time.dart';

/// Where a missing-person case has got to.
///
/// Three values, and the server validates against exactly these — anything else
/// is a 400 from `/update_missing_person_status/<id>`.
///
/// Only [missing] cases are readable. `/get_missing_persons` filters on it, and
/// there is no endpoint that returns a case in either other state, so marking
/// one Found is a one-way door as far as this app is concerned. The confirmation
/// dialog says so.
enum MissingPersonStatus {
  missing('Missing', 'Still missing'),
  found('Found', 'Found'),
  closed('Closed', 'Closed');

  const MissingPersonStatus(this.wireValue, this.label);

  /// What the column holds and what the POST body must carry. Capitalised
  /// exactly as the server compares them.
  final String wireValue;

  final String label;

  /// True when the case is still open and still appears in the list.
  bool get isOpen => this == missing;

  static MissingPersonStatus? fromWire(String? value) {
    final v = value?.trim().toLowerCase();
    if (v == null || v.isEmpty) return null;
    for (final status in MissingPersonStatus.values) {
      if (status.wireValue.toLowerCase() == v) return status;
    }
    return null;
  }
}

/// One registered missing person.
class MissingPerson {
  const MissingPerson({
    required this.personId,
    this.name = '',
    this.age = '',
    this.gender = '',
    this.description = '',
    this.photoPath = '',
    this.lastSeenLocation = '',
    this.lastSeenDate = '',
    this.createdAt = '',
    this.statusRaw = '',
  });

  /// `MP_FD888AA63529`. Minted by the server from a UUID, and the only handle
  /// anything has on the case.
  final String personId;

  final String name;

  /// **Text, though the column is an INTEGER.** It is printed and never
  /// arithmetic, and the column is nullable — a case reported with no age at
  /// all is normal, and `0` would be a lie about a missing child.
  final String age;

  final String gender;

  /// What they were wearing, or anything else the officer recorded.
  final String description;

  /// Server-relative, already `/`-prefixed: `/static/uploads/missing_persons/
  /// MP_….jpg`. Resolved against the base URL where it is shown — see
  /// [photoUrl].
  final String photoPath;

  final String lastSeenLocation;

  /// `yyyy-MM-dd` in practice, but free text on the wire like every other date
  /// the citizen-facing forms collect.
  final String lastSeenDate;

  /// SQLite's `CURRENT_TIMESTAMP`, UTC. Parsed by [ServerTime].
  final String createdAt;

  /// The status column verbatim, kept raw beside [status] for the same reason
  /// a complaint's is: nothing constrains the column but the one handler that
  /// writes it.
  final String statusRaw;

  MissingPersonStatus? get status => MissingPersonStatus.fromWire(statusRaw);

  String get statusLabel {
    final known = status;
    if (known != null) return known.label;
    final raw = statusRaw.trim();
    return raw.isEmpty ? 'No status' : raw;
  }

  bool get hasPhoto => photoPath.trim().isNotEmpty;

  /// The photograph's absolute URL, given the server's base.
  ///
  /// Built here rather than by every widget that shows one: the column is a
  /// path and `Image.network` needs a URL, and a screen that joined them itself
  /// would be the screen that forgot the leading slash.
  String photoUrl(String baseUrl) {
    final path = photoPath.trim();
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  /// `18 · Male`, or whichever half was recorded.
  String get ageAndGender {
    final parts = [
      if (age.trim().isNotEmpty) age.trim(),
      if (gender.trim().isNotEmpty) gender.trim(),
    ];
    return parts.join(' · ');
  }

  DateTime? get reportedAt => ServerTime.parse(createdAt);
  String get reportedOnDisplay => ServerTime.displayDay(createdAt);

  /// Whether this case answers [lowercaseQuery], already trimmed and lowered.
  bool matches(String lowercaseQuery) {
    if (lowercaseQuery.isEmpty) return true;
    for (final field in [
      personId,
      name,
      gender,
      description,
      lastSeenLocation,
      lastSeenDate,
    ]) {
      if (field.toLowerCase().contains(lowercaseQuery)) return true;
    }
    return false;
  }

  @override
  String toString() => 'MissingPerson($personId, $name)';
}
