import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/form_dates.dart';
import '../../../../../shared/widgets/inputs/app_picker_field.dart';
import '../../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../../theme/app_dimensions.dart';
import '../../../domain/entities/fir_draft.dart';
import '../../controllers/fir_form_controller.dart';
import '../../controllers/fir_form_state.dart';
import '../fir_field_controllers.dart';
import '../fir_field_keys.dart';
import '../form_pickers.dart';
import 'fir_step_scaffold.dart';

/// Step 2 — FORM IF-1 entries 4 to 7: when the offence happened, when the
/// station heard about it, and where.
///
/// Nothing here is required. An informant who walks in at midnight unsure which
/// day the theft happened is still entitled to have the complaint registered —
/// the offence does not stop being cognisable because a column is blank, and a
/// form that insisted would collect a guess recorded as fact in a document read
/// in court.
///
/// The three date-and-time pairs are deliberately separate entries rather than
/// one "when": the gap between occurrence, information received and registration
/// is exactly what [FirDraft.reasonsForDelay] on step 4 exists to explain, and
/// collapsing them would erase the question.
class FirOccurrenceStep extends ConsumerWidget {
  const FirOccurrenceStep({
    super.key,
    required this.state,
    required this.fields,
  });

  final FirFormState state;
  final FirFieldControllers fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = state.draft;
    final enabled = !state.isSubmitting;
    final controller = ref.read(firFormControllerProvider.notifier);

    return FirStepScaffold(
      step: FirFormStep.occurrence,
      children: [
        const FirGroupLabel('When it happened'),
        const FirOptionalNote(
          'Everything on this page may be left blank. Fill in what the '
          'complainant is sure of.',
        ),
        AppPickerField(
          key: FirFieldKeys.occurrenceDate,
          label: 'Date of occurrence',
          value: FormDates.displayDate(draft.occurrenceDate),
          hintText: 'Not stated',
          icon: Icons.event_outlined,
          enabled: enabled,
          // Clearable, unlike the FIR date: this one is genuinely allowed to be
          // empty, so an officer who picked the wrong day needs a way back to
          // "not stated" rather than being stuck with a wrong fact.
          onClear: draft.occurrenceDate.isEmpty
              ? null
              : () => controller.edit((d) => d.copyWith(occurrenceDate: '')),
          onTap: () async {
            final picked = await pickWireDate(
              context,
              current: draft.occurrenceDate,
              helpText: 'Date the offence took place',
            );
            if (picked != null) {
              controller.edit((d) => d.copyWith(occurrenceDate: picked));
            }
          },
        ),
        // Entry 4 of the paper form asks for the day and the date separately.
        // They cannot disagree, so only one is typed — see FirDraft.occurrenceDay.
        if (draft.occurrenceDay.isNotEmpty)
          FirOptionalNote(
            '${draft.occurrenceDay}, taken from the date of occurrence.',
          ),
        AppPickerField(
          key: FirFieldKeys.occurrenceTime,
          label: 'Time of occurrence',
          value: FormDates.displayTime(draft.occurrenceTime),
          hintText: 'Not stated',
          icon: Icons.schedule_outlined,
          enabled: enabled,
          onClear: draft.occurrenceTime.isEmpty
              ? null
              : () => controller.edit((d) => d.copyWith(occurrenceTime: '')),
          onTap: () async {
            final picked = await pickWireTime(
              context,
              current: draft.occurrenceTime,
              helpText: 'Time the offence took place',
            );
            if (picked != null) {
              controller.edit((d) => d.copyWith(occurrenceTime: picked));
            }
          },
        ),
        AppTextField(
          key: FirFieldKeys.placeOfOccurrence,
          label: 'Place of occurrence',
          controller: fields.placeOfOccurrence,
          hintText: 'Where it happened',
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(placeOfOccurrence: value)),
        ),

        const SizedBox(height: AppSpacing.md),

        const FirGroupLabel('When the station heard'),
        AppPickerField(
          key: FirFieldKeys.infoReceivedDate,
          label: 'Information received on',
          value: FormDates.displayDate(draft.infoReceivedDate),
          hintText: 'Not stated',
          icon: Icons.event_outlined,
          enabled: enabled,
          onClear: draft.infoReceivedDate.isEmpty
              ? null
              : () => controller.edit((d) => d.copyWith(infoReceivedDate: '')),
          onTap: () async {
            final picked = await pickWireDate(
              context,
              current: draft.infoReceivedDate,
              helpText: 'Date the information reached the station',
            );
            if (picked != null) {
              controller.edit((d) => d.copyWith(infoReceivedDate: picked));
            }
          },
        ),
        AppPickerField(
          key: FirFieldKeys.infoReceivedTime,
          label: 'Information received at',
          value: FormDates.displayTime(draft.infoReceivedTime),
          hintText: 'Not stated',
          icon: Icons.schedule_outlined,
          enabled: enabled,
          onClear: draft.infoReceivedTime.isEmpty
              ? null
              : () => controller.edit((d) => d.copyWith(infoReceivedTime: '')),
          onTap: () async {
            final picked = await pickWireTime(
              context,
              current: draft.infoReceivedTime,
              helpText: 'Time the information reached the station',
            );
            if (picked != null) {
              controller.edit((d) => d.copyWith(infoReceivedTime: picked));
            }
          },
        ),
        AppTextField(
          key: FirFieldKeys.gdrEntryNo,
          label: 'General diary reference',
          controller: fields.gdrEntryNo,
          hintText: 'Entry number and time',
          enabled: enabled,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(gdrEntryNo: value)),
        ),
        AppTextField(
          key: FirFieldKeys.typeOfInformation,
          label: 'Type of information',
          controller: fields.typeOfInformation,
          // Free text rather than a picker: the printed form has no fixed list
          // and stations use their own wording.
          hintText: 'Written, oral, telephonic…',
          enabled: enabled,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(typeOfInformation: value)),
        ),
      ],
    );
  }
}
