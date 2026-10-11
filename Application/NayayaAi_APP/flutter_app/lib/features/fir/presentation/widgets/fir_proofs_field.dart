import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../../evidence/domain/entities/evidence_file.dart';
import '../../../evidence/presentation/controllers/evidence_providers.dart';
import '../../../evidence/presentation/widgets/evidence_source_sheet.dart';
import '../controllers/fir_form_controller.dart';

/// Files to be filed against the FIR the moment it has a number.
///
/// ---------------------------------------------------------------------------
/// WHY THE FILES CANNOT GO UP UNTIL THE FIR DOES
///
/// `POST /upload-evidence` checks `fir_exists(fir_no)` and refuses anything
/// else. There is no order of operations that gets a photograph into the locker
/// before the record it belongs to — so the officer picks here, the form holds
/// the files in memory, and `FirFormController.submit` sends them one at a time
/// once `/generate_fir` has answered with a number.
///
/// The website does exactly this: `selectedProofFiles` in `script.js`, uploaded
/// by `uploadProofsForFIR(data.fir_no)` in the line after the FIR is filed. The
/// app not having it was the reason an officer at a scene had to file the FIR,
/// remember the number, leave the form, open the locker, and type the number
/// back in before they could attach the photograph they had already taken.
/// ---------------------------------------------------------------------------
///
/// Nothing here is required, and nothing here can fail the filing — see
/// [FirProofOutcome].
class FirProofsField extends ConsumerWidget {
  const FirProofsField({
    super.key,
    required this.proofs,
    required this.enabled,
  });

  final List<EvidenceFile> proofs;
  final bool enabled;

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    FocusScope.of(context).unfocus();

    final source = await showEvidenceSourceSheet(context);
    if (source == null) return;

    final EvidenceFile? file;
    try {
      file = await ref.read(evidenceFilePickerProvider).pick(source);
    } catch (error) {
      if (!context.mounted) return;
      // A refused camera or a denied storage permission. Shown here and not
      // held in state: it is about the last tap, not about the draft, and it
      // must not still be on screen three entries later.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
      return;
    }

    // Dismissed the picker. Never an error.
    if (file == null) return;
    ref.read(firFormControllerProvider.notifier).attachProof(file);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photographs and documents',
          style: AppTypography.label.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          proofs.isEmpty
              ? 'Optional. Anything attached here is filed into the evidence '
                  'locker against this FIR as soon as it is registered.'
              : 'Filed into the locker against this FIR once it is registered. '
                  'Nothing is uploaded yet.',
          style: AppTypography.error.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.md),
        if (proofs.isNotEmpty) ...[
          for (final file in proofs)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ProofRow(
                file: file,
                onRemove: enabled
                    ? () => ref
                        .read(firFormControllerProvider.notifier)
                        .detachProof(file)
                    : null,
              ),
            ),
        ],
        SecondaryButton(
          key: FirProofKeys.attach,
          label: proofs.isEmpty ? 'Attach a file' : 'Attach another',
          icon: Icons.attach_file_rounded,
          enabled: enabled,
          onPressed: enabled ? () => _attach(context, ref) : null,
        ),
      ],
    );
  }
}

class _ProofRow extends StatelessWidget {
  const _ProofRow({required this.file, required this.onRemove});

  final EvidenceFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Container(
      key: FirProofKeys.row(file.name),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.05),
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 16, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.fieldValue.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  file.displaySize,
                  style: AppTypography.error.copyWith(color: muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Remove ${file.name}',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Widget keys for the proof attachments, so a test can name one file rather
/// than "the second row".
abstract final class FirProofKeys {
  const FirProofKeys._();

  static const attach = Key('fir-proof-attach');

  static Key row(String filename) => Key('fir-proof-$filename');
}
