import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/feedback/form_banner.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../../evidence/domain/entities/evidence_file.dart';
import '../../../evidence/presentation/controllers/evidence_providers.dart';
import '../../../evidence/presentation/widgets/evidence_source_sheet.dart';
import '../../domain/entities/sighting.dart';
import '../controllers/missing_person_providers.dart';
import 'missing_person_keys.dart';
import 'person_photo.dart';

/// Reports a sighting: a photograph, where, and when.
///
/// Returns the server's verdict, or null when the sheet was dismissed without
/// filing one.
///
/// A sheet rather than a screen because the case has to stay behind it. The
/// officer is looking at the registered photograph while deciding whether the
/// person in front of them is the same one, and pushing a full screen would
/// take away the thing they are comparing against.
Future<SightingResult?> showReportSightingSheet(
  BuildContext context, {
  required String personId,
}) {
  return showModalBottomSheet<SightingResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (_) => _ReportSightingSheet(personId: personId),
  );
}

class _ReportSightingSheet extends ConsumerStatefulWidget {
  const _ReportSightingSheet({required this.personId});

  final String personId;

  @override
  ConsumerState<_ReportSightingSheet> createState() =>
      _ReportSightingSheetState();
}

class _ReportSightingSheetState extends ConsumerState<_ReportSightingSheet> {
  final _location = TextEditingController();
  final _date = TextEditingController();

  EvidenceFile? _photo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _location.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    FocusScope.of(context).unfocus();

    final source = await showEvidenceSourceSheet(context);
    if (source == null || !mounted) return;

    try {
      final file = await ref.read(evidenceFilePickerProvider).pick(source);
      if (file == null || !mounted) return;
      setState(() {
        _photo = file;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  Future<void> _submit() async {
    final photo = _photo;
    if (photo == null || _busy) return;

    if (_location.text.trim().isEmpty) {
      setState(() => _error = 'Where they were seen is required.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result =
          await ref.read(missingPersonRepositoryProvider).reportSighting(
                personId: widget.personId,
                photoPath: photo.path,
                photoName: photo.name,
                location: _location.text,
                sightingDate: _date.text,
              );

      // The case's sightings and, if the comparison confirmed it, the matches
      // banner on the register both now disagree with the server.
      ref
        ..invalidate(sightingsProvider(widget.personId))
        ..invalidate(confirmedMatchesProvider);

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // The server's own sentence. "No face detected in your photo. Please
        // upload a clearer image." is the whole instruction.
        _error = ErrorMapper.map(error, context: 'report_sighting').message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final photo = _photo;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          key: MissingPersonKeys.sightingSheet,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report a sighting',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The photograph is compared against the registered one on the '
                'server. It is recorded either way — a near miss is still worth '
                'an officer looking at.',
                style: AppTypography.error.copyWith(color: muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_error != null) ...[
                FormBanner(message: _error!),
                const SizedBox(height: AppSpacing.lg),
              ],
              Center(
                child: Column(
                  children: [
                    if (photo != null)
                      PersonPhoto.localWhole(
                        key: MissingPersonKeys.sightingPhoto,
                        localFile: photo.path,
                        height: 180,
                      )
                    else
                      const PersonPhoto.whole(
                        key: MissingPersonKeys.sightingPhoto,
                        path: '',
                        height: 180,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(
                      label: photo == null
                          ? 'Add the photograph'
                          : 'Choose a different photograph',
                      icon: Icons.photo_camera_outlined,
                      enabled: !_busy,
                      onPressed: _busy ? null : _choosePhoto,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: MissingPersonKeys.sightingLocation,
                label: 'Where',
                controller: _location,
                hintText: 'Place, area or landmark',
                enabled: !_busy,
              ),
              AppTextField(
                key: MissingPersonKeys.sightingDate,
                label: 'When',
                controller: _date,
                hintText: 'yyyy-mm-dd — today if left blank',
                enabled: !_busy,
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                key: MissingPersonKeys.sightingSubmit,
                label: 'File the sighting',
                icon: Icons.send_rounded,
                isLoading: _busy,
                enabled: photo != null,
                onPressed: _busy || photo == null ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
