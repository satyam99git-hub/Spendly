import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../missing_persons/presentation/controllers/missing_person_providers.dart';
import '../../../missing_persons/presentation/widgets/person_photo.dart';
import '../widgets/citizen_sighting_sheet.dart';
import '../widgets/citizen_widgets.dart';
import 'citizen_missing_persons_screen.dart';

/// One missing person, on a page of its own (parity spec P-17).
///
/// The website has no such page — a citizen sees everything about a person on
/// the card. This is that card with room to breathe on a phone: the whole
/// photograph and the whole description, which the card clamps to two lines.
/// It adds no information the card does not carry — no sightings, no scores,
/// no case number — and one action, the card's own "Report Sighting".
class CitizenMissingPersonDetailScreen extends ConsumerWidget {
  const CitizenMissingPersonDetailScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(missingPersonProvider(personId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Missing Persons'),
      ),
      body: person.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const StateMessage(
          icon: Icons.error_outline_rounded,
          title: 'Error loading data.',
          body: '',
          centred: true,
        ),
        data: (p) {
          // Found, closed, or never listed: the list the website shows no
          // longer has them, so neither does this page.
          if (p == null) {
            return const StateMessage(
              icon: Icons.check_circle_outline_rounded,
              title: 'All clear — no active cases',
              body: 'Thank you for checking. Every visit matters.',
              centred: true,
            );
          }
          final muted = scheme.onSurface.withValues(alpha: 0.6);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              PersonPhoto.whole(path: p.photoPath, height: 320),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      ),
                    ),
                  ),
                  if (p.lastSeenDate.isNotEmpty)
                    Text(
                      'Last seen ${p.lastSeenDate}',
                      style: TextStyle(color: muted),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                p.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (ageGenderLine(p).isNotEmpty)
                Text(ageGenderLine(p), style: TextStyle(color: muted)),
              if (p.lastSeenLocation.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: Color(0xFFF87171),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(p.lastSeenLocation)),
                  ],
                ),
              ],
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  p.description,
                  style: TextStyle(color: muted, height: 1.4),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              CitizenButton(
                label: 'Report Sighting',
                icon: Icons.visibility_outlined,
                onPressed: () => showCitizenSightingSheet(
                  context,
                  personId: p.personId,
                  personName: p.name,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
