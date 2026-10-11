import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/form_dates.dart';
import '../../../../shared/widgets/inputs/app_picker_field.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../evidence/data/datasources/evidence_file_picker.dart';
import '../../../evidence/domain/entities/evidence_file.dart';
import '../../../evidence/presentation/controllers/evidence_providers.dart';
import '../../../fir/presentation/widgets/form_pickers.dart';
import '../../../missing_persons/domain/entities/sighting.dart';
import '../../../missing_persons/presentation/controllers/missing_person_providers.dart';
import '../../../missing_persons/presentation/widgets/person_photo.dart';
import 'citizen_widgets.dart';

/// The website's "Report Sighting" modal (missing_persons_fragment.html:
/// 279-339, `mpSubmitSighting()` 781-834), as a bottom sheet.
///
/// Its own widget rather than the police console's `ReportSightingSheet`: the
/// two say different things to different people, and the police one is left
/// exactly as it is.
Future<void> showCitizenSightingSheet(
  BuildContext context, {
  required String personId,
  required String personName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (_) =>
        CitizenSightingSheet(personId: personId, personName: personName),
  );
}

class CitizenSightingSheet extends ConsumerStatefulWidget {
  const CitizenSightingSheet({
    super.key,
    required this.personId,
    required this.personName,
  });

  final String personId;
  final String personName;

  @override
  ConsumerState<CitizenSightingSheet> createState() =>
      _CitizenSightingSheetState();
}

class _CitizenSightingSheetState extends ConsumerState<CitizenSightingSheet> {
  final _location = TextEditingController();

  /// Defaults to today, as `mpOpenSightingModal` fills the date box.
  String _date = FormDates.toWireDate(DateTime.now());
  EvidenceFile? _photo;
  bool _busy = false;

  /// The result panel: a match, a recorded sighting, or an error.
  SightingResult? _result;
  String? _error;
  Timer? _closeTimer;

  /// `accept="image/jpeg,image/png,image/webp,image/gif"`, and the server's own
  /// list (missing_person.py:60-62).
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp'};

  @override
  void dispose() {
    _closeTimer?.cancel();
    _location.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    FocusScope.of(context).unfocus();
    final source = await showModalBottomSheet<EvidenceSource>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(EvidenceSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a photo'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(EvidenceSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final EvidenceFile? file;
    try {
      file = await ref.read(evidenceFilePickerProvider).pick(source);
    } catch (_) {
      return;
    }
    if (file == null || !mounted) return;

    final name = file.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    if (!_imageExtensions.contains(ext)) {
      // The server would refuse it with these words; saying so before the
      // upload saves the round trip.
      setState(() => _error = 'Only image files accepted.');
      return;
    }
    setState(() {
      _photo = file;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await pickWireDate(
      context,
      current: _date,
      helpText: 'Date',
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    // The website's three checks, in its order (lines 788-790).
    if (_location.text.trim().isEmpty) {
      return showCitizenAlert(context, 'Please enter a location.');
    }
    if (_date.isEmpty) {
      return showCitizenAlert(context, 'Please select a date.');
    }
    final photo = _photo;
    if (photo == null) {
      return showCitizenAlert(context, 'Please upload a photo.');
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      final result =
          await ref.read(missingPersonRepositoryProvider).reportSighting(
                personId: widget.personId,
                photoPath: photo.path,
                photoName: photo.name,
                location: _location.text,
                sightingDate: _date,
              );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
      });
      // A match closes the modal after two seconds and reloads the list
      // (lines 816-818). A recorded non-match leaves it open.
      if (result.isMatch) {
        _closeTimer = Timer(const Duration(seconds: 2), () {
          ref.invalidate(missingPersonsProvider);
          if (mounted) Navigator.of(context).pop();
        });
      }
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure is NetworkFailure
            ? 'Network error — please try again.'
            : (failure.message.isEmpty
                ? 'An error occurred.'
                : failure.message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = _photo;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Sighting',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'For: ${widget.personName}',
                        style: TextStyle(color: scheme.primary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cancel',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Location *',
              controller: _location,
              hintText: 'Where did you see this person?',
              enabled: !_busy,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppPickerField(
              label: 'Date *',
              value: _date.isEmpty ? '' : FormDates.displayDate(_date),
              icon: Icons.calendar_today_outlined,
              enabled: !_busy,
              onTap: _pickDate,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('PHOTO *', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _busy ? null : _choosePhoto,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: scheme.outline.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    if (photo != null)
                      PersonPhoto.localWhole(localFile: photo.path, height: 220)
                    else
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 32,
                        color: scheme.onSurface.withValues(alpha: 0.3),
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(photo?.name ?? 'Click to upload photo'),
                    Text(
                      'JPG · PNG · WEBP',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _ResultPanel(result: _result!),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _Panel(
                background: const Color(0xFFFEF2F2),
                border: const Color(0xFFEF4444),
                foreground: const Color(0xFF991B1B),
                children: [Text(_error!)],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: CitizenButton(
                    label: 'Submit Sighting',
                    busyLabel: 'Analysing face…',
                    busy: _busy,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The green or yellow result box (lines 804-815).
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});

  final SightingResult result;

  @override
  Widget build(BuildContext context) {
    final match = result.isMatch;
    return _Panel(
      background: match ? const Color(0xFFF0FDF4) : const Color(0xFFFEFCE8),
      border: match ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
      foreground: match ? const Color(0xFF166534) : const Color(0xFF854D0E),
      children: [
        Text(
          match ? '✓ Match Confirmed!' : 'Sighting Recorded',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: AppSpacing.xs),
        // `Math.round((face_match_score || 0) * 100)`.
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Confidence: '),
              TextSpan(
                text: '${result.matchPercent.round()}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        if (result.details.isNotEmpty)
          Text(result.details, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          match
              ? 'This sighting is now logged in Confirmed Matches.'
              : 'Thank you for reporting. Every sighting helps.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: match ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.background,
    required this.border,
    required this.foreground,
    required this.children,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: border, width: 4)),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
