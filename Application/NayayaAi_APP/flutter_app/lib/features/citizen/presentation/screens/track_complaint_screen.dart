import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/server_time.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../complaints/domain/entities/complaint.dart';
import '../controllers/complaint_controllers.dart';
import '../widgets/citizen_widgets.dart';

/// Track Complaint — citizen_dashboard.html `<section id="track-complaint">`
/// (lines 466-527) and `trackComplaint()` (lines 868-930).
///
/// Shows exactly what the website shows of a tracked complaint and nothing it
/// leaves out: the endpoint also returns the description, the category and the
/// update time, and the website displays none of them.
class TrackComplaintScreen extends ConsumerStatefulWidget {
  const TrackComplaintScreen({super.key});

  @override
  ConsumerState<TrackComplaintScreen> createState() =>
      _TrackComplaintScreenState();
}

class _TrackComplaintScreenState extends ConsumerState<TrackComplaintScreen> {
  final _id = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    FocusScope.of(context).unfocus();
    final alert = await ref
        .read(trackComplaintControllerProvider.notifier)
        .track(_id.text);
    if (alert != null && mounted) await showCitizenAlert(context, alert);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackComplaintControllerProvider);
    final complaint = state.complaint;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const CitizenSectionHeader(
          title: 'Track Your Complaint',
          subtitle: 'Enter your tracking ID to see the current status.',
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _id,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontFamily: 'monospace'),
                // `oninput="this.value=this.value.toUpperCase()"`.
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (_, next) => next.copyWith(text: next.text.toUpperCase()),
                  ),
                ],
                decoration: const InputDecoration(
                  hintText: 'e.g. CMP-A1B2C3D4',
                ),
                onSubmitted: (_) => _track(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              height: AppSizes.controlHeight,
              child: FilledButton(
                onPressed: state.busy ? null : _track,
                child: state.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('Track'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (complaint != null) _Result(complaint: complaint),
        if (state.error != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: Color(0xFFB91C1C),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.complaint});

  final Complaint complaint;

  /// `new Date(created_at).toLocaleDateString('en-IN', {day: 'numeric',
  /// month: 'long', year: 'numeric'})` — "9 August 2026".
  static String filedOn(String raw) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final at = ServerTime.parse(raw)?.toLocal();
    if (at == null) return raw;
    return '${at.day} ${months[at.month - 1]} ${at.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget field(String label, Widget value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CitizenFieldLabel(label),
            const SizedBox(height: 2),
            value,
          ],
        );

    String orNotSpecified(String value) =>
        value.isEmpty ? 'Not specified' : value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: field(
                'Tracking ID',
                SelectableText(
                  complaint.trackingId,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
            CitizenStatusPill(complaint.statusRaw),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          runSpacing: AppSpacing.md,
          children: [
            _Half(field('Name', Text(complaint.fullName))),
            _Half(
              field(
                'Incident Date',
                Text(orNotSpecified(complaint.incidentDate)),
              ),
            ),
            _Half(field('Location', Text(orNotSpecified(complaint.location)))),
            _Half(field('Filed On', Text(filedOn(complaint.createdAt)))),
            // Only when there is one (lines 892-899).
            if (complaint.firNo.isNotEmpty)
              field(
                'FIR Number',
                Text(
                  complaint.firNo,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            if (complaint.officerNotes.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: field(
                  'Officer Notes',
                  Text(
                    complaint.officerNotes,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CitizenFieldLabel('Status Timeline'),
              const SizedBox(height: AppSpacing.lg),
              ComplaintTimeline(status: complaint.statusRaw),
            ],
          ),
        ),
      ],
    );
  }
}

/// Half the row — the website's two-column result grid.
class _Half extends StatelessWidget {
  const _Half(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth / 2,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}
