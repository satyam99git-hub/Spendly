import 'package:flutter/widgets.dart';

/// Widget keys for the missing-persons screens.
abstract final class MissingPersonKeys {
  const MissingPersonKeys._();

  static const list = Key('missing-persons');
  static const search = Key('missing-persons-search');
  static const matchesBanner = Key('missing-persons-matches');
  static const registerAction = Key('missing-person-register');

  static Key tile(String personId) => Key('missing-person-$personId');

  static Key matchCard(String personId) => Key('missing-match-$personId');

  // ---- registering ----------------------------------------------------------

  static const form = Key('missing-person-form');
  static const photo = Key('missing-person-photo');
  static const name = Key('missing-person-name');
  static const age = Key('missing-person-age');
  static const gender = Key('missing-person-gender');
  static const description = Key('missing-person-description');
  static const lastSeenLocation = Key('missing-person-last-seen');
  static const lastSeenDate = Key('missing-person-last-seen-date');
  static const submit = Key('missing-person-submit');

  // ---- one case -------------------------------------------------------------

  static const detail = Key('missing-person-detail');
  static const reportSighting = Key('missing-person-report-sighting');
  static const markFound = Key('missing-person-mark-found');

  static Key sighting(String sightingId) => Key('sighting-$sightingId');

  // ---- reporting a sighting -------------------------------------------------

  static const sightingSheet = Key('sighting-sheet');
  static const sightingPhoto = Key('sighting-photo');
  static const sightingLocation = Key('sighting-location');
  static const sightingDate = Key('sighting-date');
  static const sightingSubmit = Key('sighting-submit');
}
