import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/fir_number.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/form_banner.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
// The locker's one cross-feature import — see the class doc.
import '../../../fir/presentation/widgets/fir_picker_sheet.dart';
import '../../domain/entities/evidence_category.dart';
import '../../domain/entities/evidence_file.dart';
import '../controllers/evidence_upload_controller.dart';
import '../widgets/evidence_source_sheet.dart';
import '../widgets/evidence_keys.dart';
import '../widgets/evidence_tile.dart';

/// Filing one file against one FIR.
///
/// A pushed route rather than a sheet, because picking a file leaves the app
/// entirely — the camera, the gallery, the system file browser — and a bottom
/// sheet that has to survive three process-death-prone excursions is a sheet
/// that eventually comes back empty.
///
/// The FIR number is **typed or picked**, and typing stays the primary path.
///
/// It was typed only, until F9 gave the app a way to list records at all. Both
/// exist now because they are for two different moments: an officer at the
/// counter has the number in front of them — it is what the complainant was
/// given — and making them wait for every FIR in the station to download before
/// they can enter four characters would be a picker charging rent. An officer
/// filing a photo taken three days ago, on a case they can name but not number,
/// has nothing to type; the sheet is for them.
///
/// So the field is a text box with a *Choose from history* affordance in it,
/// the sheet loads only when opened, and a sheet that fails to load leaves the
/// typed path exactly as it was. The server checks the number either way, which
/// remains a better check than anything the app can do — see
/// `docs/features/04-fir-history.md`.
///
/// **The one cross-feature import in the locker.** Evidence is filed *against*
/// an FIR, so the dependency runs this way and only this way: the FIR feature
/// knows nothing about a locker.
class EvidenceAddScreen extends ConsumerStatefulWidget {
  const EvidenceAddScreen({super.key});

  @override
  ConsumerState<EvidenceAddScreen> createState() => _EvidenceAddScreenState();
}

class _EvidenceAddScreenState extends ConsumerState<EvidenceAddScreen> {
  final _firNo = TextEditingController();

  @override
  void dispose() {
    _firNo.dispose();
    super.dispose();
  }

  EvidenceUploadController get _controller =>
      ref.read(evidenceUploadControllerProvider.notifier);

  /// Opens the FIR history in a sheet and takes what comes back.
  ///
  /// The controller and the text box are both updated, in that order, because
  /// the box is what the officer sees and the controller is what gets uploaded —
  /// a picked number that reached only one of them is the kind of divergence
  /// that files evidence against whatever was typed before.
  Future<void> _chooseFir() async {
    FocusScope.of(context).unfocus();

    final picked = await showFirPicker(context);
    // Null is a dismissal, not a clear. See showFirPicker.
    if (picked == null || !mounted) return;

    _controller.setFirNo(picked);
    _firNo.value = TextEditingValue(
      text: picked,
      selection: TextSelection.collapsed(offset: picked.length),
    );
  }

  Future<void> _choose() async {
    FocusScope.of(context).unfocus();

    final source = await showEvidenceSourceSheet(context);

    if (source == null) return;
    await _controller.pick(source);
  }

  Future<void> _upload() async {
    FocusScope.of(context).unfocus();
    final done = await _controller.upload();
    if (!done || !mounted) return;

    final item = ref.read(evidenceUploadControllerProvider).uploaded!;

    // Back to the list, with the confirmation there rather than on a screen of
    // its own. One file is not an event that deserves a receipt page — but the
    // officer does need to see the name the server actually stored, which
    // `secure_filename` may have rewritten.
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item.filename} filed against ${FirNumber.label(item.firNo)}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(evidenceUploadControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final enabled = !state.isUploading;

    String? errorFor(String label) =>
        state.showErrors && state.missing.contains(label) ? 'Required' : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
      child: PopScope(
        // Leaving mid-upload would strand a request whose outcome decides
        // whether the file is in the locker.
        canPop: enabled,
        child: Scaffold(
          // Stated rather than inherited. The theme's scaffold background is
          // navy — the auth screens are built on it — so a page that does not
          // paint its own surface renders its labels as dark text on navy. This
          // screen shipped that way in F10 and was found by a render of it while
          // the FIR picker was being added.
          backgroundColor: scheme.surface,
          appBar: AppBar(
            title: const Text('Add evidence'),
            leading: IconButton(
              onPressed: enabled ? context.pop : null,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      AppSpacing.xl,
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                    ),
                    children: [
                      if (state.failure != null) ...[
                        FormBanner(message: state.failure!.message),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      AppTextField(
                        key: EvidenceKeys.addFirNo,
                        label: 'FIR number',
                        controller: _firNo,
                        hintText: 'The FIR this belongs to',
                        enabled: enabled,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        errorText: errorFor('FIR number'),
                        onChanged: _controller.setFirNo,
                        // Inside the field rather than beside it: it fills this
                        // box and nothing else, and a separate button would read
                        // as a second way to add evidence.
                        suffix: IconButton(
                          key: EvidenceKeys.addFirPicker,
                          onPressed: enabled ? _chooseFir : null,
                          icon: const Icon(Icons.history_rounded, size: 20),
                          tooltip: 'Choose from FIR history',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _FileField(
                        file: state.file,
                        enabled: enabled,
                        errorText: errorFor('File'),
                        onChoose: _choose,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const _Note(
                        text: 'The FIR must already be registered. Evidence '
                            'cannot be attached while an FIR is being written.',
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.md,
                    AppSpacing.xxl,
                    AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: PrimaryButton(
                    key: EvidenceKeys.addSubmit,
                    label: 'Upload to locker',
                    icon: Icons.cloud_upload_outlined,
                    isLoading: state.isUploading,
                    onPressed: _upload,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The chosen file, or the affordance to choose one.
///
/// Shaped like the form's other fields — same label, same reserved error slot —
/// so a required entry that happens to be a file does not look like a different
/// kind of thing from a required entry that happens to be text.
class _FileField extends StatelessWidget {
  const _FileField({
    required this.file,
    required this.enabled,
    required this.onChoose,
    this.errorText,
  });

  final EvidenceFile? file;
  final bool enabled;
  final VoidCallback onChoose;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = errorText != null;
    final chosen = file;

    return Column(
      key: EvidenceKeys.addFile,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'File',
          style: AppTypography.label.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (chosen == null)
          SizedBox(
            height: AppSizes.controlHeight,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: enabled ? onChoose : null,
              icon: Icon(
                Icons.attach_file_rounded,
                size: 18,
                color: hasError ? scheme.error : scheme.primary,
              ),
              label: Text(
                // Not "Choose a file": that is one of the three things the
                // sheet then offers, and two controls with the same words on
                // consecutive screens read as one that failed to do anything.
                'Attach a file',
                style: AppTypography.button.copyWith(
                  color: hasError ? scheme.error : scheme.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: hasError ? scheme.error : scheme.outlineVariant,
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.07),
              borderRadius: AppRadius.controlBorder,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  EvidenceTile.iconFor(
                    EvidenceCategory.fromExtension(chosen.name),
                  ),
                  size: 22,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chosen.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                      ),
                      Text(
                        chosen.displaySize,
                        style: AppTypography.error.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: enabled ? onChoose : null,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 18,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    errorText!,
                    style: AppTypography.error.copyWith(color: scheme.error),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 15, color: muted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.error.copyWith(color: muted, height: 1.35),
          ),
        ),
      ],
    );
  }
}
