import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/features/missing_persons/data/models/missing_person_models.dart';
import 'package:nayaya_app/features/missing_persons/domain/entities/missing_person.dart';

/// The missing-persons register below the widgets.
///
/// The thing worth pinning here is the match score. The server sends it two
/// ways — a raw 0-1 figure on a sighting, an already-multiplied percentage on a
/// confirmed match — and a client that read either as the other would report a
/// 72% match as 0.72% or as 7,200%.
void main() {
  group('a registered person', () {
    Map<String, dynamic> aRow() => {
          'person_id': 'MP_FD888AA63529',
          'name': 'satyam gupta',
          // INTEGER column, nullable.
          'age': 18,
          'gender': 'Male',
          'description': 'green shirt',
          'photo_url': '/static/uploads/missing_persons/MP_FD888AA63529.jpg',
          'last_seen_location': 'nalasopara',
          'last_seen_date': '2026-07-16',
          'created_at': '2026-07-17 05:54:59',
          'status': 'Missing',
        };

    test('reads the row the register sends', () {
      final person = MissingPersonResponse.fromJson(aRow());

      expect(person.personId, 'MP_FD888AA63529');
      expect(person.name, 'satyam gupta');
      expect(person.status, MissingPersonStatus.missing);
      expect(person.reportedAt, DateTime.utc(2026, 7, 17, 5, 54, 59));
    });

    // Printed, never arithmetic — and the column is nullable, so `0` would be
    // a lie about a missing child rather than a missing value.
    test('a numeric age is read as text and a missing one stays empty', () {
      expect(MissingPersonResponse.fromJson(aRow()).age, '18');
      expect(
        MissingPersonResponse.fromJson({...aRow(), 'age': null}).age,
        isEmpty,
      );
    });

    test('the photo path joins onto the base URL without doubling the slash',
        () {
      final person = MissingPersonResponse.fromJson(aRow());

      expect(
        person.photoUrl('http://10.0.2.2:5000'),
        'http://10.0.2.2:5000/static/uploads/missing_persons/'
        'MP_FD888AA63529.jpg',
      );
      // A base with its own trailing slash must not produce `…5000//static`.
      expect(
        person.photoUrl('http://10.0.2.2:5000/'),
        'http://10.0.2.2:5000/static/uploads/missing_persons/'
        'MP_FD888AA63529.jpg',
      );
    });

    test('a record with no photograph says so rather than building a URL', () {
      final person =
          MissingPersonResponse.fromJson({...aRow(), 'photo_url': null});

      expect(person.hasPhoto, isFalse);
      expect(person.photoUrl('http://10.0.2.2:5000'), isEmpty);
    });

    test('age and gender print together, or whichever half was recorded', () {
      expect(MissingPersonResponse.fromJson(aRow()).ageAndGender, '18 · Male');
      expect(
        MissingPersonResponse.fromJson({...aRow(), 'gender': ''}).ageAndGender,
        '18',
      );
    });

    test('the search reads the name, the place and the description', () {
      final person = MissingPersonResponse.fromJson(aRow());

      expect(person.matches('nalasopara'), isTrue);
      expect(person.matches('green'), isTrue);
      expect(person.matches('satyam'), isTrue);
      expect(person.matches('bandra'), isFalse);
      expect(person.matches(''), isTrue);
    });
  });

  group('the status', () {
    test('the three the server validates against', () {
      expect(
        MissingPersonStatus.values.map((s) => s.wireValue),
        ['Missing', 'Found', 'Closed'],
      );
    });

    test('only Missing is open, which is what the register returns', () {
      expect(MissingPersonStatus.missing.isOpen, isTrue);
      expect(MissingPersonStatus.found.isOpen, isFalse);
      expect(MissingPersonStatus.closed.isOpen, isFalse);
    });

    test('an unknown value parses to null and is shown as written', () {
      expect(MissingPersonStatus.fromWire('Vanished'), isNull);
      final person = MissingPersonResponse.fromJson({
        'person_id': 'MP_X',
        'status': 'Vanished',
      });
      expect(person.statusLabel, 'Vanished');
    });
  });

  group('a sighting', () {
    // /get_sightings sends the raw comparison score.
    test('the raw 0-1 score is scaled to a percentage', () {
      final sighting = SightingResponse.fromJson({
        'sighting_id': 'SG_1',
        'photo_url': '/static/uploads/sightings/SG_1.jpg',
        'location': 'Nalasopara station',
        'sighting_date': '2026-08-20',
        'face_match_score': 0.724,
        'is_confirmed': true,
        'uploaded_at': '2026-08-20 11:00:00',
      });

      expect(sighting.matchPercent, closeTo(72.4, 0.01));
      expect(sighting.matchLabel, '72%');
      expect(sighting.isConfirmed, isTrue);
    });

    // SQLite has no boolean; the column is 0/1.
    test('is_confirmed is read from 0/1 as well as from a boolean', () {
      bool read(Object? value) => SightingResponse.fromJson({
            'sighting_id': 'SG_1',
            'is_confirmed': value,
          }).isConfirmed;

      expect(read(1), isTrue);
      expect(read(0), isFalse);
      expect(read(true), isTrue);
      expect(read(null), isFalse);
    });
  });

  group('a confirmed match', () {
    Map<String, dynamic> aMatch() => {
          'person_id': 'MP_1',
          'name': 'satyam gupta',
          'missing_person_photo': '/static/uploads/missing_persons/MP_1.jpg',
          'confidence': 72.4,
          'location': 'Nalasopara station',
          'sighting_date': '2026-08-20',
          'uploaded_at': '2026-08-20 11:00:00',
          'sighting_photo': '/static/uploads/sightings/SG_1.jpg',
          'sightings': [
            {
              'photo': '/static/uploads/sightings/SG_1.jpg',
              'location': 'Nalasopara station',
              'date': '2026-08-20',
              // ALREADY a percentage here — the handler multiplies by 100.
              'score': 72.4,
            },
            {
              'photo': '/static/uploads/sightings/SG_2.jpg',
              'location': 'Virar market',
              'date': '2026-08-21',
              'score': 61.2,
            },
          ],
        };

    test('groups every sighting under the person, strongest first', () {
      final match = ConfirmedMatchResponse.fromJson(aMatch());

      expect(match.sightings, hasLength(2));
      expect(match.best!.location, 'Nalasopara station');
      expect(match.otherCount, 1);
    });

    // The bug this guards: multiplying an already-multiplied score gives 7,240%.
    test('a grouped score is not multiplied a second time', () {
      final match = ConfirmedMatchResponse.fromJson(aMatch());

      expect(match.best!.matchPercent, closeTo(72.4, 0.01));
      expect(match.best!.matchLabel, '72%');
    });

    test('every grouped sighting is confirmed by definition', () {
      final match = ConfirmedMatchResponse.fromJson(aMatch());

      expect(match.sightings.every((s) => s.isConfirmed), isTrue);
    });

    // The handler's own "backward compat with frontend fallback" copy.
    test('the flat copy is used when the array is missing', () {
      final match =
          ConfirmedMatchResponse.fromJson(aMatch()..remove('sightings'));

      expect(match.sightings, hasLength(1));
      expect(match.best!.photoPath, '/static/uploads/sightings/SG_1.jpg');
      expect(match.best!.matchPercent, closeTo(72.4, 0.01));
      expect(match.otherCount, 0);
    });

    test('the registered photograph joins onto the base URL', () {
      final match = ConfirmedMatchResponse.fromJson(aMatch());

      expect(
        match.photoUrl('http://10.0.2.2:5000'),
        'http://10.0.2.2:5000/static/uploads/missing_persons/MP_1.jpg',
      );
    });
  });
}
