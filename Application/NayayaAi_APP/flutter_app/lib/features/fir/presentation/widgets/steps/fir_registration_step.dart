import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/form_dates.dart';
import '../../../../../shared/widgets/inputs/app_picker_field.dart';
import '../../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../../theme/app_dimensions.dart';
import '../../../domain/entities/fir_draft.dart';
import '../../controllers/fir_form_controller.dart';
import '../../controllers/fir_form_state.dart';
import '../../controllers/fir_lookup_providers.dart';
import '../act_sections_field.dart';
import '../fir_field_controllers.dart';
import '../fir_field_keys.dart';
import '../fir_lookup_field.dart';
import '../form_pickers.dart';
import 'fir_step_scaffold.dart';

/// Step 1 — FORM IF-1 entries 1 to 3: which station is registering what, when,
/// and under which sections.
///
/// Every entry on this step is required, and that is not arbitrary. An FIR
/// without a number cannot be looked up, without a station cannot be traced, and
/// without sections is not a charge — the four that follow can all be filled in
/// afterwards from the register, and these cannot.
class FirRegistrationStep extends ConsumerWidget {
  const FirRegistrationStep({
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
      step: FirFormStep.registration,
      children: [
        const FirGroupLabel('The record'),
        AppTextField(
          key: FirFieldKeys.firNo,
          label: 'FIR number',
          controller: fields.firNo,
          hintText: 'As entered in the station register',
          enabled: enabled,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          errorText: errorFor('FIR number'),
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(firNo: value)),
        ),
        FirLookupField(
          key: FirFieldKeys.district,
          label: 'District / State',
          value: draft.district,
          options: ref.watch(firDistrictsProvider),
          hintText: 'Select a district',
          searchHint: 'Search districts',
          enabled: enabled,
          errorText: errorFor('District / State'),
          onRetry: () => ref.invalidate(firDistrictsProvider),
          onChanged: (value) {
            // Changing the district invalidates the station under it. Clearing
            // is the honest move: leaving "North Delhi PS" selected under
            // Maharashtra files an FIR against a station that does not exist.
            controller.edit(
              (d) => d.copyWith(
                district: value,
                policeStation: value == d.district ? null : '',
              ),
            );
          },
        ),
        FirLookupField(
          key: FirFieldKeys.policeStation,
          label: 'Police station',
          value: draft.policeStation,
          options: ref.watch(firPoliceStationsProvider(draft.district)),
          hintText: 'Select a police station',
          searchHint: 'Search stations',
          enabled: enabled && draft.district.trim().isNotEmpty,
          disabledHint: 'Choose a district first',
          errorText: errorFor('Police station'),
          onRetry: () =>
              ref.invalidate(firPoliceStationsProvider(draft.district)),
          onChanged: (value) =>
              controller.edit((d) => d.copyWith(policeStation: value)),
        ),
        AppPickerField(
          key: FirFieldKeys.firDate,
          label: 'FIR date',
          value: FormDates.displayDate(draft.firDate),
          hintText: 'Select a date',
          icon: Icons.event_outlined,
          enabled: enabled,
          errorText: errorFor('FIR date'),
          onTap: () async {
            final picked = await pickWireDate(
              context,
              current: draft.firDate,
              helpText: 'Date the FIR is registered',
            );
            // Null is a dismissal, not a clear.
            if (picked != null) {
              controller.edit((d) => d.copyWith(firDate: picked));
            }
          },
        ),
        // Entry 2 of the paper form. Shown rather than asked for, so an officer
        // can see the value that will be filed without being able to make it
        // disagree with the date above it — see FirDraft.year.
        if (draft.year.isNotEmpty)
          FirOptionalNote('Year ${draft.year}, taken from the FIR date.'),
        const SizedBox(height: AppSpacing.md),
        const FirGroupLabel('Acts and sections'),
        ActSectionsField(
          key: FirFieldKeys.sections,
          sections: draft.sections,
          enabled: enabled,
          errorText: errorFor('Acts and sections'),
          onChanged: (sections) =>
              controller.edit((d) => d.copyWith(sections: sections)),
        ),
      ],
    );
  }
}
