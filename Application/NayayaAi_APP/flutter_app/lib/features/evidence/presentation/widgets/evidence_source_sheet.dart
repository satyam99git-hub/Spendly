import 'package:flutter/material.dart';

import '../../../../theme/app_dimensions.dart';
import '../../data/datasources/evidence_file_picker.dart';

/// Asks where a file is coming from, and returns the answer.
///
/// Three explicit acts rather than one "attach" button — see [EvidenceSource]
/// for why. Shared between the evidence locker's Add screen and the FIR form's
/// proof attachments, which are two places an officer picks a file and must not
/// be two different pickers: one of them would grow a fourth source, or lose
/// the camera, and nobody would notice until an officer at a scene could not
/// find the button they use every day.
///
/// Returns null when the sheet was dismissed. A dismissal is never an error.
Future<EvidenceSource?> showEvidenceSourceSheet(BuildContext context) {
  return showModalBottomSheet<EvidenceSource>(
    context: context,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (_) => const _SourceSheet(),
  );
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    const icons = {
      EvidenceSource.camera: Icons.photo_camera_outlined,
      EvidenceSource.gallery: Icons.photo_library_outlined,
      EvidenceSource.files: Icons.folder_open_outlined,
    };

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final source in EvidenceSource.values)
            ListTile(
              leading: Icon(icons[source], color: scheme.primary),
              title: Text(source.label),
              onTap: () => Navigator.of(context).pop(source),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
