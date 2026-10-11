import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../missing_persons/presentation/controllers/missing_person_providers.dart';

/// The citizen page's seven sections, in the sidebar's order
/// (citizen_dashboard.html:177-213). Each label is the sidebar's.
enum CitizenSection {
  home('Home', Icons.dashboard_outlined),
  fileComplaint('File a Complaint', Icons.note_add_outlined),
  trackComplaint('Track Complaint', Icons.search_rounded),
  caseStatus('My Case Status', Icons.balance_rounded),
  knowRights('Know Your Rights', Icons.shield_outlined),
  missingPersons('Missing Persons', Icons.person_search_outlined),
  emergency('Emergency Contacts', Icons.phone_in_talk_outlined);

  const CitizenSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Which section is on screen. The website opens on Home
/// (`showSection('home')`, citizen_dashboard.html:808).
final citizenSectionProvider = StateProvider.autoDispose<CitizenSection>(
  (ref) => CitizenSection.home,
);

/// `showSection(id)` — switches section and, for Missing Persons, reloads the
/// list, because the website refetches it every time that section is shown
/// (citizen_dashboard.html:777).
void showCitizenSection(WidgetRef ref, CitizenSection section) {
  if (section == CitizenSection.missingPersons) {
    ref.invalidate(missingPersonsProvider);
  }
  ref.read(citizenSectionProvider.notifier).state = section;
}
