import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/feedback/form_banner.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../../evidence/presentation/controllers/evidence_providers.dart';
import '../../../evidence/presentation/widgets/evidence_source_sheet.dart';
import '../../domain/repositories/missing_person_repository.dart';
import '../controllers/missing_person_form_controller.dart';
import '../widgets/missing_person_keys.dart';
import '../widgets/person_photo.dart';

/// Registering a missing person: one photograph and what is known.
///
/// ---------------------------------------------------------------------------
/// THE PHOTOGRAPH IS THE FORM
///
/// Every other field is optional server-side, and even the name is checked only
/// for being non-empty. The photograph is what the feature is: it is what every
/// sighting is compared against, and the server runs a face detector over it
/// and **refuses the whole registration** when it finds no face, deleting the
/// upload on the way out.
///
/// So it is first, it is large, and the refusal is shown in the server's own
/// words. "No face detected in the photo. Please upload a clear frontal image."
/// tells an officer photographing a printed poster exactly what to do next;
/// "Registration failed" sends them to ring the station.
/// ---------------------------------------------------------------------------
class MissingPersonFormScreen extends ConsumerStatefulWidget {
  const MissingPersonFormScreen({super.key});

  @override
  ConsumerState<MissingPersonFormScreen> createState() =>
      _MissingPersonFormScreenState();
}

class _MissingPersonFormScreenState
    extends ConsumerState<MissingPersonFormScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _gender = TextEditingController();
  final _description = TextEditingController();
  final _lastSeen = TextEditingController();
  final _lastSeenDate = TextEditingController();

  /// Shown under the name box once Register has been refused for a blank one.
  /// False until then, so a form does not open in red.
  bool _showErrors = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _age,
      _gender,
      _description,
      _lastSeen,
      _lastSeenDate,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    FocusScope.of(context).unfocus();

    final source = await showEvidenceSourceSheet(context);
    if (source == null || !mounted) return;

    try {
      final file = await ref.read(evidenceFilePickerProvider).pick(source);
      if (file == null || !mounted) return;
      ref.read(missingPersonFormControllerProvider.notifier).setPhoto(file);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_name.text.trim().isEmpty) {
      setState(() => _showErrors = true);
      return;
    }

    final id =
        await ref.read(missingPersonFormControllerProvider.notifier).submit(
              (path, name) => MissingPersonDraft(
                name: _name.text,
                photoPath: path,
                photoName: name,
                age: _age.text,
                gender: _gender.text,
                description: _description.text,
                lastSeenLocation: _lastSeen.text,
                lastSeenDate: _lastSeenDate.text,
              ),
            );

    if (id == null || !mounted) return;

    // Back to the register, with the confirmation there. One case is not an
    // event that deserves a receipt page, but the officer does need the ID the
    // server minted — it is what a colleague will quote back to them.
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_name.text.trim()} registered as $id.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(missingPersonFormControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final busy = state.busy;

    return Scaffold(
      key: MissingPersonKeys.form,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Register a missing person'),
        backgroundColor: scheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          if (state.failure != null) ...[
            FormBanner(message: state.failure!.message),
            const SizedBox(height: AppSpacing.xxl),
          ],
          Center(
            child: Column(
              children: [
                // Shown from disk. The officer has to see the photograph they
                // are about to register: the server judges it, and its refusal
                // ("no face detected") only makes sense against a picture they
                // can see.
                if (state.photo case final photo?)
                  PersonPhoto.localWhole(
                    key: MissingPersonKeys.photo,
                    localFile: photo.path,
                  )
                else
                  const PersonPhoto.whole(
                    key: MissingPersonKeys.photo,
                    path: '',
                    height: 220,
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  state.photo?.name ?? 'No photograph chosen',
                  textAlign: TextAlign.center,
                  style: AppTypography.error.copyWith(
                    color: state.hasPhoto ? scheme.onSurface : muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: state.hasPhoto
                      ? 'Choose a different photograph'
                      : 'Choose a photograph',
                  icon: Icons.photo_camera_outlined,
                  enabled: !busy,
                  onPressed: busy ? null : _choosePhoto,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A clear, front-facing photograph of one person. Every sighting '
            'reported is compared against it, and the server refuses a picture '
            'it cannot find a face in.',
            style: AppTypography.error.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppTextField(
            key: MissingPersonKeys.name,
            label: 'Full name',
            controller: _name,
            hintText: 'As the family gave it',
            enabled: !busy,
            textCapitalization: TextCapitalization.words,
            errorText: _showErrors && _name.text.trim().isEmpty
                ? 'Required'
                : null,
            onChanged: (_) {
              if (_showErrors) setState(() {});
            },
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  key: MissingPersonKeys.age,
                  label: 'Age',
                  controller: _age,
                  hintText: 'Years',
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  key: MissingPersonKeys.gender,
                  label: 'Gender',
                  controller: _gender,
                  hintText: 'As recorded',
                  enabled: !busy,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          AppTextField(
            key: MissingPersonKeys.lastSeenLocation,
            label: 'Last seen at',
            controller: _lastSeen,
            hintText: 'Place, area or landmark',
            enabled: !busy,
          ),
          AppTextField(
            key: MissingPersonKeys.lastSeenDate,
            label: 'Last seen on',
            controller: _lastSeenDate,
            hintText: 'yyyy-mm-dd',
            enabled: !busy,
          ),
          AppTextArea(
            key: MissingPersonKeys.description,
            label: 'Description',
            controller: _description,
            hintText: 'Height, build, what they were wearing, anything else '
                'that would help someone recognise them',
            enabled: !busy,
            minLines: 3,
            maxLines: 8,
            maxLength: 1000,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            key: MissingPersonKeys.submit,
            label: 'Register',
            icon: Icons.person_add_alt_1_outlined,
            isLoading: busy,
            // Disabled without a photograph rather than refused on press: the
            // button has a reason it cannot be used and the note above states
            // it, which is the one case where greying out says more than
            // pressing would.
            enabled: state.hasPhoto,
            onPressed: busy || !state.hasPhoto ? null : _submit,
          ),
        ],
      ),
    );
  }
}
