import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fir_form_controller.dart';

/// The three reference lists the form's pickers are built from.
///
/// All `keepAlive` by default (a plain [FutureProvider] is), which is what makes
/// leaving the form and coming back free: the district list is fetched
/// once for as long as the app is running, not on every visit to step one.
///
/// None of them has a bundled fallback. A hard-coded copy of the server's 31
/// districts would go stale the first time a state was added, and — worse — it
/// would let an officer pick a station the server has never heard of and only
/// find out at submission. When a lookup fails the field says so and offers the
/// entry as free text instead, which is honest about what the app knows.

/// `GET /api/districts`. The server sorts them.
final firDistrictsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(firRepositoryProvider).districts(),
);

/// `GET /api/police-stations/<district>`, one cached list per district.
///
/// `.family` rather than a single provider holding the selected district: an
/// officer who picks Delhi, changes to Maharashtra and changes back should not
/// pay for the same request twice, and each district's answer is independent of
/// which one happens to be selected.
final firPoliceStationsProvider =
    FutureProvider.family<List<String>, String>((ref, district) {
  if (district.trim().isEmpty) return Future.value(const <String>[]);
  return ref.watch(firRepositoryProvider).policeStations(district);
});

/// `GET /api/acts` — the eight act codes.
final firActsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(firRepositoryProvider).acts(),
);
