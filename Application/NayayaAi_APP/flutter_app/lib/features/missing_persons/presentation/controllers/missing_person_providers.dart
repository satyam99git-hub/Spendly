import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/missing_person_remote_data_source.dart';
import '../../data/repositories/missing_person_repository_impl.dart';
import '../../domain/entities/confirmed_match.dart';
import '../../domain/entities/missing_person.dart';
import '../../domain/entities/sighting.dart';
import '../../domain/repositories/missing_person_repository.dart';

final missingPersonRemoteDataSourceProvider =
    Provider<MissingPersonRemoteDataSource>(
  (ref) => MissingPersonRemoteDataSource(ref.watch(dioClientProvider).dio),
);

final missingPersonRepositoryProvider = Provider<MissingPersonRepository>(
  (ref) => MissingPersonRepositoryImpl(
    remote: ref.watch(missingPersonRemoteDataSourceProvider),
  ),
);

/// Every open case.
///
/// Not `autoDispose`: the list is the screen an officer returns to after
/// looking at each of three sightings, and refetching it on every return would
/// lose their scroll position to a spinner. Invalidated explicitly after a
/// registration or a status change, which are the only things that alter it
/// from this device.
final missingPersonsProvider = FutureProvider<List<MissingPerson>>(
  (ref) => ref.watch(missingPersonRepositoryProvider).all(),
);

/// The confirmed face matches across every open case.
///
/// Its own provider rather than a slice of [missingPersonsProvider], because it
/// is a different endpoint answering a different question — "who has been
/// found?" rather than "who is missing?" — and it is police-only where the list
/// is not.
final confirmedMatchesProvider = FutureProvider<List<ConfirmedMatch>>(
  (ref) => ref.watch(missingPersonRepositoryProvider).confirmedMatches(),
);

/// One case's sightings, keyed by person.
///
/// `autoDispose`: an officer works through a case and leaves it, and holding
/// every sighting of every case they have opened this shift buys nothing.
final sightingsProvider =
    FutureProvider.autoDispose.family<List<Sighting>, String>(
  (ref, personId) =>
      ref.watch(missingPersonRepositoryProvider).sightings(personId),
);

/// One case, resolved out of the list already in memory.
///
/// There is no endpoint that returns a single missing person — see
/// `ApiEndpoints.missingPersons` — so the detail screen either finds its case
/// in the list or fetches the whole list to find it. The same arrangement the
/// complaint detail screen uses, and for the same reason.
final missingPersonProvider =
    FutureProvider.autoDispose.family<MissingPerson?, String>(
  (ref, personId) async {
    final all = await ref.watch(missingPersonsProvider.future);
    for (final person in all) {
      if (person.personId == personId) return person;
    }
    return null;
  },
);
