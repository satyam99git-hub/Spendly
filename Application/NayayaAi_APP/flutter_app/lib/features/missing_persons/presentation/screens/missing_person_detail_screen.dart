import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/missing_person.dart';
import '../../domain/entities/sighting.dart';
import '../controllers/missing_person_form_controller.dart';
import '../controllers/missing_person_providers.dart';
import '../widgets/missing_person_keys.dart';
import '../widgets/person_photo.dart';
import '../widgets/report_sighting_sheet.dart';

/// One case: who is missing, and everyone who says they have seen them.
class MissingPersonDetailScreen extends ConsumerWidget {
  const MissingPersonDetailScreen({super.key, required this.personId});

  final String personId;

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final result = await showReportSightingSheet(context, personId: personId);
    if (result == null || !context.mounted) return;

    // The server's own sentence, which already names the confidence.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message.isEmpty
              ? 'Sighting recorded. ${result.matchLabel} match.'
              : result.message,
        ),
      ),
    );
  }

  /// Marks the case Found, after asking.
  ///
  /// Confirmed because it cannot be undone from this app: `/get_missing_persons`
  /// only returns cases still marked Missing, and no endpoint returns one that
  /// is not — so a case closed by a mis-tap is a case that has left the app for
  /// good. The dialog says exactly that rather than "are you sure?".
  Future<void> _markFound(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as found?'),
        content: const Text(
          'The case leaves the register and its sightings stop being listed. '
          'Nothing in the app can reopen it — that has to be done on the '
          'website.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mark as found'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final done = await ref
        .read(missingPersonStatusControllerProvider.notifier)
        .setStatus(personId, MissingPersonStatus.found);

    if (!context.mounted) return;

    if (done) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as found.')),
      );
      return;
    }

    final failure = ref.read(missingPersonStatusControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$failure')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final person = ref.watch(missingPersonProvider(personId));
    final busy = ref.watch(missingPersonStatusControllerProvider).isLoading;

    return Scaffold(
      key: MissingPersonKeys.detail,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Missing person'),
        backgroundColor: scheme.surface,
      ),
      body: person.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.cloud_off_rounded,
          title: 'The case could not be loaded',
          body: '$error',
          centred: true,
        ),
        data: (found) {
          if (found == null) {
            // Every case in the register is in the list this resolves out of,
            // so a miss means it has been marked Found or Closed since the list
            // was read — by a colleague, or by this officer on another device.
            return const StateMessage(
              icon: Icons.person_off_outlined,
              title: 'This case is no longer open',
              body: 'It has been marked found or closed. Cases that are not '
                  'open are not readable from the app.',
              centred: true,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              _Header(person: found),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                key: MissingPersonKeys.reportSighting,
                label: 'Report a sighting',
                icon: Icons.add_a_photo_outlined,
                onPressed: () => _report(context, ref),
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                key: MissingPersonKeys.markFound,
                label: 'Mark as found',
                icon: Icons.check_circle_outline_rounded,
                enabled: !busy,
                onPressed: busy ? null : () => _markFound(context, ref),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              _Sightings(personId: personId),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.person});

  final MissingPerson person;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The whole photograph, not a square crop of it. The picture people
        // take of a missing person is full-body and portrait, and a centre crop
        // cut the head off — on the one screen where the face is the point.
        PersonPhoto.whole(path: person.photoPath),
        const SizedBox(height: AppSpacing.lg),
        Text(
          person.name.isEmpty ? 'No name recorded' : person.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
        ),
        if (person.ageAndGender.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            person.ageAndGender,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: muted,
                ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (person.lastSeenLocation.isNotEmpty)
          _Line(label: 'Last seen at', value: person.lastSeenLocation),
        if (person.lastSeenDate.isNotEmpty)
          _Line(label: 'Last seen on', value: person.lastSeenDate),
        if (person.description.isNotEmpty)
          _Line(label: 'Description', value: person.description),
        _Line(
          label: 'Registered',
          value: person.reportedOnDisplay.isEmpty
              ? 'Date not recorded'
              : person.reportedOnDisplay,
        ),
        // Selectable: it is what a colleague on the website will ask for.
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: SelectableText(
            person.personId,
            style: AppTypography.error.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.45),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.label.copyWith(color: muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

/// Everyone who says they have seen this person, newest first.
///
/// Police-only server-side, so this is the one part of the screen that can 403
/// while the rest of it renders. It says so where it stands rather than taking
/// the screen down: the details above are still worth reading, and a citizen
/// reporting a sighting has no business seeing the other reports anyway.
class _Sightings extends ConsumerWidget {
  const _Sightings({required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final sightings = ref.watch(sightingsProvider(personId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SIGHTINGS',
          style: AppTypography.label.copyWith(color: muted, letterSpacing: 1.2),
        ),
        const SizedBox(height: AppSpacing.md),
        sightings.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(
            '$error',
            style: AppTypography.error.copyWith(color: muted),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'None reported yet.',
                style: AppTypography.error.copyWith(color: muted),
              );
            }
            return Column(
              children: [
                for (final sighting in list) ...[
                  _SightingTile(sighting: sighting),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SightingTile extends StatelessWidget {
  const _SightingTile({required this.sighting});

  final Sighting sighting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    // Confirmed by the server's own comparison, at its own tolerance. Not
    // re-derived from the score here — see [Sighting.isConfirmed].
    final colour = sighting.isConfirmed
        ? scheme.error
        : scheme.onSurface.withValues(alpha: 0.2);

    return Container(
      key: MissingPersonKeys.sighting(sighting.sightingId),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: sighting.isConfirmed
            ? scheme.error.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: colour.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonPhoto(path: sighting.photoPath, size: 56),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${sighting.matchLabel} match',
                      style: AppTypography.fieldValue.copyWith(
                        color: sighting.isConfirmed
                            ? scheme.error
                            : scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (sighting.isConfirmed) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.verified_rounded, size: 14, color: scheme.error),
                    ],
                  ],
                ),
                if (sighting.location.isNotEmpty)
                  Text(
                    sighting.location,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                  ),
                Text(
                  [
                    if (sighting.sightingDate.isNotEmpty) sighting.sightingDate,
                    if (sighting.reportedAtDisplay.isNotEmpty)
                      'filed ${sighting.reportedAtDisplay}',
                  ].join(' · '),
                  style: AppTypography.error.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
