import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/form_dates.dart';
import '../../../../../shared/widgets/inputs/app_picker_field.dart';
import '../../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../../theme/app_dimensions.dart';
import '../../../domain/entities/fir_draft.dart';
import '../../controllers/fir_form_controller.dart';
import '../../controllers/fir_form_state.dart';
import '../fir_field_controllers.dart';
import '../fir_field_keys.dart';
import '../form_pickers.dart';
import 'fir_step_scaffold.dart';

/// Step 3 — FORM IF-1 entry 7: who is reporting this.
///
/// Only the name is required. Everything else here is a detail the station can
/// take later, and one of them — the passport block — is blank on almost every
/// real FIR in the country.
///
/// The passport group is kept, and kept last, for the case it exists for: a
/// complainant who is a foreign national. That is precisely the situation in
/// which nobody wants to discover the app cannot record it, and precisely the
/// situation in which an officer will not mind three extra boxes.
class FirComplainantStep extends ConsumerWidget {
  const FirComplainantStep({
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
    final errorFor = firErrorFor(state);
    final controller = ref.read(firFormControllerProvider.notifier);

    return FirStepScaffold(
      step: FirFormStep.complainant,
      children: [
        const FirGroupLabel('Who is reporting'),
        AppTextField(
          key: FirFieldKeys.complainantName,
          label: 'Complainant name',
          controller: fields.complainantName,
          hintText: 'Full name, as given',
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          errorText: errorFor('Complainant name'),
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(complainantName: value)),
        ),
        AppTextField(
          key: FirFieldKeys.fatherHusbandName,
          label: 'Father’s / husband’s name',
          controller: fields.fatherHusbandName,
          hintText: 'Optional',
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(fatherHusbandName: value)),
        ),
        AppPickerField(
          key: FirFieldKeys.dob,
          label: 'Date of birth',
          value: FormDates.displayDate(draft.dob),
          hintText: 'Optional',
          icon: Icons.cake_outlined,
          enabled: enabled,
          onClear: draft.dob.isEmpty
              ? null
              : () => controller.edit((d) => d.copyWith(dob: '')),
          onTap: () async {
            final picked = await pickWireDate(
              context,
              current: draft.dob,
              helpText: 'Complainant’s date of birth',
            );
            if (picked != null) {
              controller.edit((d) => d.copyWith(dob: picked));
            }
          },
        ),
        AppTextField(
          key: FirFieldKeys.nationality,
          label: 'Nationality',
          controller: fields.nationality,
          hintText: 'Optional',
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(nationality: value)),
        ),
        AppTextField(
          key: FirFieldKeys.occupation,
          label: 'Occupation',
          controller: fields.occupation,
          hintText: 'Optional',
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(occupation: value)),
        ),
        AppTextArea(
          key: FirFieldKeys.address,
          label: 'Address',
          controller: fields.address,
          hintText: 'Optional — where the complainant can be reached',
          enabled: enabled,
          minLines: 2,
          maxLines: 5,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(address: value)),
        ),

        const SizedBox(height: AppSpacing.md),

        const FirGroupLabel('Passport'),
        const FirOptionalNote(
          'Entry 7(f). Only for a complainant who is a foreign national — leave '
          'blank otherwise.',
        ),
        AppTextField(
          key: FirFieldKeys.passportNo,
          label: 'Passport number',
          controller: fields.passportNo,
          hintText: 'Optional',
          enabled: enabled,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(passportNo: value)),
        ),
        AppPickerField(
          key: FirFieldKeys.dateOfIssue,
          label: 'Date of issue',
          value: FormDates.displayDate(draft.dateOfIssue),
          hintText: 'Optional',
          icon: Icons.event_outlined,
          enabled: enabled,
          onClear: draft.dateOfIssue.isEmpty
              ? null
              : () => controller.edit((d) => d.copyWith(dateOfIssue: '')),
          onTap: () async {
            final picked = await pickWireDate(
              context,
              current: draft.dateOfIssue,
              helpText: 'Date the passport was issued',
            );
            if (picked != null) {
              controller.edit((d) => d.copyWith(dateOfIssue: picked));
            }
          },
        ),
        AppTextField(
          key: FirFieldKeys.placeOfIssue,
          label: 'Place of issue',
          controller: fields.placeOfIssue,
          hintText: 'Optional',
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(placeOfIssue: value)),
        ),
      ],
    );
  }
}
