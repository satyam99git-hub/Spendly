import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_routes.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../missing_persons/domain/entities/missing_person.dart';
import '../../../missing_persons/presentation/controllers/missing_person_providers.dart';
import '../../../missing_persons/presentation/widgets/person_photo.dart';
import '../controllers/citizen_section.dart';
import '../widgets/citizen_sighting_sheet.dart';

/// Missing Persons, as a citizen sees it — missing_persons_fragment.html's
/// header and Citizen Reports tab (lines 1-68, 226-250, 598-637).
///
/// A citizen gets the list and "Report Sighting", and nothing else: the Police
/// Dashboard and Confirmed Matches tabs refuse anyone who is not police
/// (lines 447-452), and the sightings and match scores behind them are
/// police-only on the server too.
///
/// The fragment's "Login Required" state has no counterpart here: every
/// citizen route is behind a session, which is what that state checks for.
class CitizenMissingPersonsScreen extends ConsumerWidget {
  const CitizenMissingPersonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The website fetches the list when the section is opened, not when the
    // page loads. The shell builds every section up front, so this one waits
    // until it is the one on screen before asking.
    final visible = ref.watch(
      citizenSectionProvider.select((s) => s == CitizenSection.missingPersons),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const _Header(),
        const SizedBox(height: AppSpacing.xl),
        const _HowItWorks(),
        const SizedBox(height: AppSpacing.xl),
        if (visible) const _List(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF), Color(0xFF1D4ED8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.face_retouching_natural, color: Colors.white),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Missing Persons',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'AI face recognition · Community sightings · Real-time matching',
            style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),
          // The role badge: "Citizen" (lines 31-37, 423-424).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: Color(0xFF4ADE80)),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Citizen',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "How it works" (lines 229-239), verbatim. The server records the sighting
/// for the police to see; it sends no notification (limitation L8).
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 13),
                    children: [
                      TextSpan(text: "If you've seen someone below, click "),
                      TextSpan(
                        text: 'Report Sighting',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: ' and upload a photo — our AI compares faces in '
                            'seconds and notifies the investigating officer.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.md),
          Text('Loading…'),
        ],
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(missingPersonsProvider);
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return people.when(
      loading: () => const _Loading(),
      // `list.innerHTML = '… Error loading data.'` (line 635).
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'Error loading data.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFEF4444)),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 56,
                  color: muted,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'All clear — no active cases',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  'Thank you for checking. Every visit matters.',
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final person in list) ...[
              CitizenMissingPersonCard(person: person),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        );
      },
    );
  }
}

/// One card of the citizen list (lines 609-629). Tapping it opens the same
/// information on a page of its own (parity spec P-17); the button reports a
/// sighting, as on the website.
class CitizenMissingPersonCard extends StatelessWidget {
  const CitizenMissingPersonCard({super.key, required this.person});

  final MissingPerson person;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);

    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          AppRoutes.citizenMissingPersonName,
          pathParameters: {'personId': person.personId},
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  PersonPhoto.whole(
                    path: person.photoPath,
                    height: 200,
                    radius: 0,
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'MISSING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  if (person.lastSeenDate.isNotEmpty)
                    Positioned(
                      bottom: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Last seen ${person.lastSeenDate}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (ageGenderLine(person).isNotEmpty)
                      Text(
                        ageGenderLine(person),
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    if (person.lastSeenLocation.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: Color(0xFFF87171),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              person.lastSeenLocation,
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (person.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        person.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => showCitizenSightingSheet(
                        context,
                        personId: person.personId,
                        personName: person.name,
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Report Sighting'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `(p.age ? 'Age: ' + p.age : '') + (p.gender ? ' · ' + p.gender : '')` —
/// including the website's leading " · " when only the gender is known.
String ageGenderLine(MissingPerson person) {
  final age = person.age.trim();
  final gender = person.gender.trim();
  return '${age.isNotEmpty ? 'Age: $age' : ''}'
      '${gender.isNotEmpty ? ' · $gender' : ''}';
}
