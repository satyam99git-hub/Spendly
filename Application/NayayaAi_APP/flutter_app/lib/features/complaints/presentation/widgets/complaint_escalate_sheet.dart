import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/form_banner.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../theme/app_dimensions.dart';
import '../../domain/entities/complaint.dart';
import '../../domain/entities/escalation_desk.dart';
import '../controllers/complaint_action_controller.dart';
import 'complaint_keys.dart';
import 'sheet_scaffold.dart';

/// Sending a complaint to another desk, and saying why.
///
/// ---------------------------------------------------------------------------
/// WHAT THIS ACTUALLY DOES, SAID PLAINLY
///
/// It writes a note and moves the complaint to Under Review. Nothing is routed,
/// nothing is queued, and nobody is notified — `citizen_complaints` has no
/// assignee column and the server has no notification of any kind. Whoever reads
/// the inbox is the routing.
///
/// The sheet says so, in its subtitle, above the button. An escalation control
/// that let an officer believe a message had left the building would be worse
/// than not having one: the complaint would sit unread by exactly the person it
/// was escalated to, with the escalating officer confident it had been handed
/// over. Being honest about it costs one sentence and is the difference between
/// a useful record and a false one.
///
/// The reason is required for the same reason the note exists at all: an
/// escalation with no reason gives the next desk a complaint and no idea why
/// they have it.
/// ---------------------------------------------------------------------------
Future<void> showComplaintEscalateSheet(
  BuildContext context,
  Complaint complaint,
) {
  return showComplaintSheet<void>(
    context,
    builder: (_) => _EscalateSheet(complaint: complaint),
  );
}

class _EscalateSheet extends ConsumerStatefulWidget {
  const _EscalateSheet({required this.complaint});

  final Complaint complaint;

  @override
  ConsumerState<_EscalateSheet> createState() => _EscalateSheetState();
}

class _EscalateSheetState extends ConsumerState<_EscalateSheet> {
  final _reason = TextEditingController();

  /// Nothing is pre-selected.
  ///
  /// A default desk would be sent to by every officer in a hurry, which turns a
  /// routing decision into whichever option happened to be first in the list.
  EscalationDesk? _desk;

  bool _showErrors = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _hasReason => _reason.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final desk = _desk;
    if (desk == null || !_hasReason) {
      setState(() => _showErrors = true);
      return;
    }

    final saved = await ref
        .read(
          complaintActionControllerProvider(widget.complaint.trackingId)
              .notifier,
        )
        .escalate(widget.complaint, desk: desk, reason: _reason.text);

    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final action = ref.watch(
      complaintActionControllerProvider(widget.complaint.trackingId),
    );

    return ComplaintSheetScaffold(
      sheetKey: ComplaintKeys.escalateSheet,
      title: 'Escalate',
      subtitle: 'Recorded on the complaint and marked under review. '
          'Nothing is sent — whoever works the inbox will see it.',
      children: [
            if (action.failure != null) ...[
              FormBanner(message: action.failure!.message),
              const SizedBox(height: AppSpacing.lg),
            ],
            for (final desk in EscalationDesk.values)
              ComplaintChoiceTile(
                key: ComplaintKeys.escalateDesk(desk.name),
                title: desk.label,
                subtitle: desk.description,
                selected: _desk == desk,
                onTap: action.isSaving
                    ? () {}
                    : () => setState(() => _desk = desk),
              ),
            if (_showErrors && _desk == null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose where this is going.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextArea(
              key: ComplaintKeys.escalateReason,
              label: 'Why',
              controller: _reason,
              hintText: 'What makes this one for that desk',
              helperText: 'The next officer reads this and nothing else.',
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              enabled: !action.isSaving,
              errorText: _showErrors && !_hasReason
                  ? 'An escalation needs a reason.'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              key: ComplaintKeys.escalateSubmit,
              label: 'Escalate',
              icon: Icons.north_east_rounded,
              isLoading: action.isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }
}
