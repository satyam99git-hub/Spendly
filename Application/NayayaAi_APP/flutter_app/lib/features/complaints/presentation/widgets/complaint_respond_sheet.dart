import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/form_banner.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/complaint.dart';
import '../../domain/entities/complaint_status.dart';
import '../controllers/complaint_action_controller.dart';
import 'complaint_keys.dart';
import 'sheet_scaffold.dart';

/// Writing a reply to a complaint, and saying where it has got to.
///
/// ---------------------------------------------------------------------------
/// WHY THE NOTE AND THE STATUS ARE ONE SHEET
///
/// They are one decision. An officer does not think "I will change this to Under
/// Review" and separately "I will write down why" — they think "I have rung the
/// complainant, here is what she said, it is with me now". Two controls in two
/// places would let either half be saved without the other, which is how a
/// status ends up changing with nothing in the trail to explain it.
///
/// It is also one server call: the PATCH writes all three columns at once, so
/// splitting the sheet would mean two round trips, the second of which can fail
/// and leave the complaint half-updated.
/// ---------------------------------------------------------------------------
Future<void> showComplaintRespondSheet(
  BuildContext context,
  Complaint complaint,
) {
  return showComplaintSheet<void>(
    context,
    builder: (_) => _RespondSheet(complaint: complaint),
  );
}

class _RespondSheet extends ConsumerStatefulWidget {
  const _RespondSheet({required this.complaint});

  final Complaint complaint;

  @override
  ConsumerState<_RespondSheet> createState() => _RespondSheetState();
}

class _RespondSheetState extends ConsumerState<_RespondSheet> {
  final _note = TextEditingController();
  late final _firNo = TextEditingController(text: widget.complaint.firNo);

  /// Starts on whatever the complaint already is, so writing a note without
  /// meaning to move the complaint does not move it.
  ///
  /// A complaint whose stored status the app cannot read starts at "Under
  /// review". That is the one thing certainly true at that moment — an officer
  /// is looking at it — and the sheet cannot offer to leave the value alone,
  /// because the server would reject it.
  late ComplaintStatus _status =
      widget.complaint.status ?? ComplaintStatus.underReview;

  /// False until the first refused Save, like every other form in this app. A
  /// sheet that opens with a red message under an empty box looks broken, and
  /// teaches people to ignore red.
  bool _showErrors = false;

  @override
  void dispose() {
    _note.dispose();
    _firNo.dispose();
    super.dispose();
  }

  /// Marking a complaint "FIR filed" with no number records that something
  /// happened and destroys the only pointer to what.
  bool get _needsFirNo =>
      _status == ComplaintStatus.firFiled && _firNo.text.trim().isEmpty;

  /// Nothing to save: same status, same FIR number, no note.
  ///
  /// Refused rather than sent, because an empty write still stamps `updated_at`
  /// — so an untouched complaint would start reading as answered in the inbox,
  /// which is precisely the signal triage runs on.
  bool get _isEmptyChange =>
      _note.text.trim().isEmpty &&
      _status == widget.complaint.status &&
      _firNo.text.trim() == widget.complaint.firNo.trim();

  Future<void> _save() async {
    if (_needsFirNo || _isEmptyChange) {
      setState(() => _showErrors = true);
      return;
    }

    final saved = await ref
        .read(
          complaintActionControllerProvider(widget.complaint.trackingId)
              .notifier,
        )
        .respond(
          widget.complaint,
          note: _note.text,
          status: _status,
          firNo: _firNo.text,
        );

    // Left open on failure, showing the banner the controller set: the officer's
    // typing is still in the boxes, and closing the sheet would throw it away
    // along with the only explanation of what went wrong.
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final action = ref.watch(
      complaintActionControllerProvider(widget.complaint.trackingId),
    );

    return ComplaintSheetScaffold(
      sheetKey: ComplaintKeys.respondSheet,
      title: 'Respond',
      subtitle: 'Signed as you and timestamped, on the end of this '
          'complaint’s trail. Nothing already written is lost.',
      children: [
        if (action.failure != null) ...[
          FormBanner(message: action.failure!.message),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          'WHERE IT STANDS NOW',
          style: AppTypography.label.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.55),
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Chips rather than four explained rows: the four statuses are a single
        // axis and the line under them explains whichever is chosen, which keeps
        // the note box — the part an officer actually came here to fill in —
        // above the fold on a handset.
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final status in ComplaintStatus.values)
                ChoiceChip(
                  key: ComplaintKeys.respondStatus(status.name),
                  label: Text(status.label),
                  selected: _status == status,
                  onSelected: action.isSaving
                      ? null
                      : (_) => setState(() => _status = status),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _status.description,
          style: AppTypography.error.copyWith(color: muted, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Only where it means something. An FIR-number box under a complaint
        // that is still pending invites a number to be recorded for a record
        // that does not exist yet.
        if (_status == ComplaintStatus.firFiled) ...[
          AppTextField(
            key: ComplaintKeys.respondFirNo,
            label: 'FIR number',
            controller: _firNo,
            hintText: 'The FIR this complaint became',
            enabled: !action.isSaving,
            errorText: _showErrors && _needsFirNo
                ? 'Enter the FIR number, or choose another status.'
                : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppTextArea(
          key: ComplaintKeys.respondNote,
          label: 'What you did',
          controller: _note,
          hintText: 'Rang the complainant, recorded a statement, advised…',
          helperText: 'Added to the trail, under everything already there.',
          minLines: 3,
          maxLines: 8,
          // Long enough for a real account of a call, short enough that a pasted
          // document cannot become a note nobody will read.
          maxLength: 2000,
          enabled: !action.isSaving,
          errorText: _showErrors && _isEmptyChange
              ? 'Write something, or move the complaint on.'
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          key: ComplaintKeys.respondSubmit,
          label: 'Save response',
          icon: Icons.check_rounded,
          isLoading: action.isSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}
