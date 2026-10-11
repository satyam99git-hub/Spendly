import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/form_dates.dart';
import '../../../../../theme/app_dimensions.dart';
import '../../../../../theme/app_typography.dart';
import '../../../domain/entities/fir_draft.dart';
import '../../controllers/fir_form_controller.dart';
import '../../controllers/fir_form_state.dart';
import '../fir_field_keys.dart';
import 'fir_step_scaffold.dart';

/// The last look before a statutory record is created.
///
/// ---------------------------------------------------------------------------
/// WHY THE REVIEW SHOWS BLANKS AND THE RECORD VIEWER HIDES THEM
///
/// `FirRecordScreen` hides every entry that was left empty, because a filed FIR
/// with nineteen empty labels reads as a record filed badly rather than one
/// filed briefly.
///
/// This screen does the opposite: it prints every entry, blanks included, marked
/// "Not recorded". The two are answering different questions. The viewer is
/// asked "what does this record say"; the review is asked "is there anything I
/// meant to fill in and did not" — and a review that quietly omitted the empty
/// boxes could not answer that at all. This is the last moment anything can be
/// added, so nothing is hidden.
/// ---------------------------------------------------------------------------
///
/// Every group carries an Edit link back to the step that owns it, so a wrong
/// entry is three taps from being right rather than four Backs.
class FirReviewStep extends ConsumerWidget {
  const FirReviewStep({super.key, required this.state});

  final FirFormState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = state.draft;
    final controller = ref.read(firFormControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final missing = draft.missing;

    return FirStepScaffold(
      step: FirFormStep.review,
      children: [
        Text(
          'Check this before filing. Once the station has it, an FIR is '
          'corrected on the paper trail, not in the app.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Named rather than counted. "3 entries missing" sends an officer
        // hunting; naming them sends them to the box.
        if (missing.isNotEmpty) ...[
          _MissingNotice(missing: missing),
          const SizedBox(height: AppSpacing.xl),
        ],

        _ReviewGroup(
          step: FirFormStep.registration,
          onEdit: () => controller.goTo(FirFormStep.registration),
          entries: [
            _Entry('FIR number', draft.firNo),
            _Entry('District / State', draft.district),
            _Entry('Police station', draft.policeStation),
            _Entry('FIR date', FormDates.displayDate(draft.firDate)),
            _Entry('Year', draft.year, derived: true),
            _Entry('Acts and sections', draft.actSectionsWire),
          ],
        ),
        _ReviewGroup(
          step: FirFormStep.occurrence,
          onEdit: () => controller.goTo(FirFormStep.occurrence),
          entries: [
            _Entry('Day', draft.occurrenceDay, derived: true),
            _Entry(
              'Date of occurrence',
              FormDates.displayDate(draft.occurrenceDate),
            ),
            _Entry(
              'Time of occurrence',
              FormDates.displayTime(draft.occurrenceTime),
            ),
            _Entry('Place of occurrence', draft.placeOfOccurrence),
            _Entry(
              'Information received on',
              FormDates.displayDate(draft.infoReceivedDate),
            ),
            _Entry(
              'Information received at',
              FormDates.displayTime(draft.infoReceivedTime),
            ),
            _Entry('General diary reference', draft.gdrEntryNo),
            _Entry('Type of information', draft.typeOfInformation),
          ],
        ),
        _ReviewGroup(
          step: FirFormStep.complainant,
          onEdit: () => controller.goTo(FirFormStep.complainant),
          entries: [
            _Entry('Complainant name', draft.complainantName),
            _Entry('Father’s / husband’s name', draft.fatherHusbandName),
            _Entry('Date of birth', FormDates.displayDate(draft.dob)),
            _Entry('Nationality', draft.nationality),
            _Entry('Occupation', draft.occupation),
            _Entry('Address', draft.address),
            _Entry('Passport number', draft.passportNo),
            _Entry('Date of issue', FormDates.displayDate(draft.dateOfIssue)),
            _Entry('Place of issue', draft.placeOfIssue),
          ],
        ),
        _ReviewGroup(
          step: FirFormStep.complaint,
          onEdit: () => controller.goTo(FirFormStep.complaint),
          entries: [
            _Entry('Details of the accused', draft.detailsOfAccused),
            _Entry('Particulars of property', draft.propertyParticulars),
            _Entry('Reasons for delay', draft.reasonsForDelay),
            _Entry('What happened', draft.statement),
          ],
        ),
      ],
    );
  }
}

/// What is still missing, by name, with the step each one lives on.
class _MissingNotice extends StatelessWidget {
  const _MissingNotice({required this.missing});

  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 19, color: scheme.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  missing.length == 1
                      ? 'One entry still has to be filled in'
                      : '${missing.length} entries still have to be filled in',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  missing.join(' · '),
                  style: AppTypography.error.copyWith(
                    color: scheme.error,
                    height: 1.4,
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

/// One step's entries, under its title, with a link back into it.
class _ReviewGroup extends StatelessWidget {
  const _ReviewGroup({
    required this.step,
    required this.entries,
    required this.onEdit,
  });

  final FirFormStep step;
  final List<_Entry> entries;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${step.number}. ${step.title}'.toUpperCase(),
                  style: AppTypography.label.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              TextButton.icon(
                key: FirFieldKeys.reviewEdit(step),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.label,
                        style: AppTypography.label.copyWith(color: muted),
                      ),
                      if (entry.derived) ...[
                        const SizedBox(width: AppSpacing.sm),
                        // Marked so an officer looking for the box that sets it
                        // does not go hunting through the step for one that is
                        // not there.
                        Text(
                          'auto',
                          style: AppTypography.error.copyWith(
                            color: muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.isFilled ? entry.value : 'Not recorded',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: entry.isFilled
                              ? scheme.onSurface
                              : scheme.onSurface.withValues(alpha: 0.4),
                          height: 1.35,
                          fontStyle: entry.isFilled
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                  ),
                ],
              ),
            ),
          Divider(color: scheme.outline.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

/// One labelled entry on the review.
class _Entry {
  const _Entry(this.label, this.value, {this.derived = false});

  final String label;
  final String value;

  /// Computed from another entry rather than typed — [FirDraft.year] and
  /// [FirDraft.occurrenceDay].
  final bool derived;

  bool get isFilled => value.trim().isNotEmpty;
}
