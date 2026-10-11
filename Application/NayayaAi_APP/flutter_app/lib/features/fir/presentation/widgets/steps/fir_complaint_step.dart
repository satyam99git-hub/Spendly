import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../../theme/app_dimensions.dart';
import '../../../../../theme/app_typography.dart';
import '../../../domain/entities/fir_draft.dart';
import '../../controllers/fir_form_controller.dart';
import '../../controllers/fir_form_state.dart';
import '../fir_field_controllers.dart';
import '../fir_proofs_field.dart';
import '../fir_field_keys.dart';
import '../suggest_sections_sheet.dart';
import 'fir_step_scaffold.dart';

/// Step 4 — FORM IF-1 entries 8 to 12: the accused, the delay, the property,
/// and the narrative.
///
/// The narrative is last and is the only required entry, because it is the one
/// the whole record is built around: every other column can be reconstructed
/// from the register, and nobody can reconstruct what the complainant said.
///
/// It is also the largest box on the form, which is deliberate. A statement read
/// through a three-line window is a statement nobody proof-reads, and this one
/// gets quoted into a charge sheet.
///
/// Attachments sit below it, for the same reason the website puts its proof
/// picker at the bottom of the same form: an officer at a scene has taken the
/// photograph before they finish typing what it is of.
class FirComplaintStep extends ConsumerWidget {
  const FirComplaintStep({
    super.key,
    required this.state,
    required this.fields,
  });

  final FirFormState state;
  final FirFieldControllers fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = !state.isSubmitting;
    final errorFor = firErrorFor(state);
    final controller = ref.read(firFormControllerProvider.notifier);

    return FirStepScaffold(
      step: FirFormStep.complaint,
      children: [
        const FirGroupLabel('The offence'),
        const FirOptionalNote(
          'These three may be left blank. What happened, below, may not.',
        ),
        AppTextArea(
          key: FirFieldKeys.detailsOfAccused,
          label: 'Details of the accused',
          controller: fields.detailsOfAccused,
          hintText: 'Names, descriptions, or “unknown”',
          enabled: enabled,
          minLines: 2,
          maxLines: 6,
          maxLength: 2000,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(detailsOfAccused: value)),
        ),
        AppTextArea(
          key: FirFieldKeys.propertyParticulars,
          label: 'Particulars of property',
          controller: fields.propertyParticulars,
          hintText: 'What was taken or involved, with values',
          enabled: enabled,
          minLines: 2,
          maxLines: 6,
          maxLength: 2000,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(propertyParticulars: value)),
        ),
        AppTextArea(
          key: FirFieldKeys.reasonsForDelay,
          label: 'Reasons for delay in reporting',
          controller: fields.reasonsForDelay,
          // Read closely in court when the gap between occurrence and
          // registration is long, which is why the form asks rather than leaving
          // the gap unexplained.
          hintText: 'Only if the report came later than the offence',
          enabled: enabled,
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(reasonsForDelay: value)),
        ),

        const SizedBox(height: AppSpacing.md),

        const FirGroupLabel('What happened'),
        AppTextArea(
          key: FirFieldKeys.statement,
          label: 'What happened',
          controller: fields.statement,
          hintText: 'The complaint in the complainant’s own words, as far as '
              'possible.',
          helperText: 'This becomes the FIR narrative.',
          enabled: enabled,
          minLines: 6,
          maxLines: 16,
          // The server imposes no limit. This one exists so a pasted document
          // cannot become a narrative no PDF page can render.
          maxLength: 5000,
          errorText: errorFor('What happened'),
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(statement: value)),
        ),

        // Directly under the narrative, and nowhere else.
        //
        // The sections field itself lives on step 1, which is where an officer
        // looking for sections would go and look -- and step 1 is exactly where
        // the narrative has not been written yet, so a button there would have
        // nothing to read. The suggestion can only exist once the statement
        // does, so it is offered at the moment the statement is finished. Step
        // 1's note points forward to it.
        _SuggestSectionsButton(state: state, enabled: enabled),

        const SizedBox(height: AppSpacing.md),

        // Last on the last entry step, which is where the officer is when they
        // have the photograph in their hand and the narrative typed. The files
        // go up after the record is written -- see [FirProofsField].
        const FirGroupLabel('Attachments'),
        FirProofsField(proofs: state.proofs, enabled: enabled),
      ],
    );
  }
}

/// Opens the suggestion sheet, and folds whatever the officer accepted into the
/// draft's sections.
///
/// Disabled until the narrative is long enough to say anything about. A button
/// that is tappable and always answers "write a little more first" teaches the
/// officer that it does not work.
class _SuggestSectionsButton extends ConsumerWidget {
  const _SuggestSectionsButton({required this.state, required this.enabled});

  final FirFormState state;
  final bool enabled;

  /// The server declines anything shorter, so the button waits for the same
  /// length rather than offering a round trip that cannot succeed.
  static const _minimumNarrative = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final narrative = state.draft.statement.trim();
    final ready = enabled && narrative.length >= _minimumNarrative;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: AppSizes.controlHeight,
            width: double.infinity,
            child: OutlinedButton.icon(
              key: FirFieldKeys.suggestOpen,
              onPressed: ready ? () => _open(context, ref) : null,
              icon: Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: ready ? scheme.primary : scheme.onSurface.withValues(alpha: 0.35),
              ),
              label: Text(
                'Suggest acts and sections',
                style: AppTypography.button.copyWith(
                  color: ready
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ready
                ? 'Reads what you have written and proposes sections, with a '
                    'reason for each. You choose which to keep.'
                : 'Available once the narrative above is a little longer.',
            style: AppTypography.error.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final draft = ref.read(firFormControllerProvider).draft;

    final accepted = await showSuggestSectionsSheet(
      context: context,
      narrative: draft.statement,
      alreadyAdded: draft.sections,
    );
    if (accepted.isEmpty) return;

    // Re-read rather than closing over the draft from before the sheet: the
    // sheet is on screen for as long as the officer needs to read it, and a
    // restored autosave can land underneath it.
    final controller = ref.read(firFormControllerProvider.notifier);
    final existing = ref.read(firFormControllerProvider).draft.sections;
    final merged = [
      ...existing,
      ...accepted.where((section) => !existing.contains(section)),
    ];
    controller.edit((d) => d.copyWith(sections: merged));
  }
}
