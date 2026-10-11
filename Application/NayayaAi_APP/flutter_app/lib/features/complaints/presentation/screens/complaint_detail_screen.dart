import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../../fir/presentation/controllers/fir_form_controller.dart';
import '../../domain/entities/complaint.dart';
import '../../domain/entities/complaint_note.dart';
import '../controllers/complaint_action_controller.dart';
import '../controllers/complaint_fir_link_controller.dart';
import '../controllers/complaint_providers.dart';
import '../widgets/complaint_escalate_sheet.dart';
import '../widgets/complaint_category_chip.dart';
import '../widgets/complaint_keys.dart';
import '../widgets/complaint_respond_sheet.dart';
import '../widgets/complaint_status_chip.dart';

/// One complaint, and the three things an officer can do about it.
///
/// ---------------------------------------------------------------------------
/// RESPOND · ESCALATE · REGISTER AN FIR
///
/// All three write the same three columns — there is one PATCH and no other way
/// to change a complaint — but they are three different decisions and the screen
/// says so rather than offering a generic "Edit":
///
///   - **Respond** is the ordinary one: what was done, and where the complaint
///     stands now. It is the primary button.
///   - **Escalate** hands it to another desk. It marks the complaint under
///     review and records where it should go, and the sheet is plain that
///     nothing is actually sent, because the server has nowhere to send it.
///   - **Register an FIR** is the one that leaves this feature. It seeds the FIR
///     form from the complaint and links the two when the record is accepted —
///     see `ComplaintFirLinkController`, which is where the two-write problem is
///     explained.
///
/// Read-only otherwise. The citizen's own words, the phone number and the
/// tracking ID are theirs, not the station's, and nothing on this screen edits
/// them: the app has no route that could, and should not acquire one.
/// ---------------------------------------------------------------------------
class ComplaintDetailScreen extends ConsumerWidget {
  const ComplaintDetailScreen({super.key, required this.trackingId});

  /// From the route, so the screen can rebuild itself from its URL after a
  /// process death and always shows what the server holds now rather than what
  /// the inbox happened to have downloaded earlier.
  final String trackingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaint = ref.watch(complaintProvider(trackingId));

    return Scaffold(
      // Stated rather than inherited. The theme's scaffold background is navy —
      // the auth screens are built on it — so a page that does not paint its own
      // surface renders dark-text-on-navy. See AppTheme.
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(trackingId.toUpperCase())),
      body: SafeArea(
        top: false,
        child: complaint.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StateMessage(
            centred: true,
            icon: error is ValidationFailure
                ? Icons.help_outline_rounded
                : Icons.cloud_off_rounded,
            // A 404 here is an answer, not a fault: the tracking ID names no
            // complaint. Saying "something went wrong" to that sends an officer
            // looking for a problem with the app instead of at the ID.
            title: error is ValidationFailure
                ? 'No complaint with that tracking ID'
                : 'This complaint could not be loaded',
            body: error is Failure
                ? error.message
                : 'Something went wrong. Go back and try again.',
          ),
          data: (complaint) => _Body(complaint: complaint),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action =
        ref.watch(complaintActionControllerProvider(complaint.trackingId));

    // Shown once, then cleared, so a rebuild — a theme change, a keyboard, a
    // rotation — does not put the same snackbar up again. The same arrangement
    // as the FIR record screen's download notice.
    ref.listen(complaintActionControllerProvider(complaint.trackingId),
        (previous, next) {
      final notice = next.notice;
      if (notice == null || notice == previous?.notice) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(notice)));
      ref
          .read(complaintActionControllerProvider(complaint.trackingId).notifier)
          .clearNotice();
    });

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: ComplaintKeys.detail,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            children: [
              _Header(complaint: complaint),
              const SizedBox(height: AppSpacing.xxl),
              _Block(
                title: 'WHO FILED IT',
                entries: [
                  _Entry('Name', complaint.fullName),
                  _Entry('Phone', complaint.phone, selectable: true),
                ],
              ),
              _Block(
                title: 'THE INCIDENT',
                entries: [
                  _Entry('When', complaint.incidentDateDisplay),
                  _Entry('Where', complaint.location),
                ],
              ),
              _Narrative(text: complaint.incidentDescription),
              const SizedBox(height: AppSpacing.xxl),
              _Notes(notes: complaint.officerNotes),
              const SizedBox(height: AppSpacing.xxl),
              _Footer(complaint: complaint),
            ],
          ),
        ),
        _Actions(complaint: complaint, isSaving: action.isSaving),
      ],
    );
  }
}

/// The status, the tracking ID and when it arrived.
class _Header extends StatelessWidget {
  const _Header({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saffron = isDark ? AppColors.saffronDark : AppColors.saffron;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: saffron.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: saffron.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CITIZEN COMPLAINT',
            style: AppTypography.label.copyWith(
              color: muted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Selectable: this is the number the citizen was given, and it gets
          // read back to them over the phone or copied into a message.
          SelectableText(
            complaint.trackingId,
            style: AppTypography.fieldValue.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: saffron,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Wrapped rather than a Row: the category label runs to
          // "Kidnapping / missing person", and with a status pill and an FIR
          // number beside it there is no phone width where all three fit on one
          // line. Wrapping puts the third on its own line; a Row would ellipsis
          // the category down to "Kidnapping / mis…".
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ComplaintStatusChip(complaint: complaint),
              // The server's read of the narrative. On the detail screen it is
              // full-size and carries its icon, because this is the screen where
              // the officer decides whether to register an FIR and the chip is
              // the one thing on it arguing a position.
              if (complaint.hasCategory)
                ComplaintCategoryChip(complaint: complaint),
              if (complaint.hasFir)
                Text(
                  'FIR ${complaint.firNo}',
                  style: AppTypography.error.copyWith(color: muted),
                ),
            ],
          ),
          if (complaint.receivedAtDisplay.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: muted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Received ${complaint.receivedAtDisplay}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One labelled entry. [value] empty means the citizen did not fill it in.
class _Entry {
  const _Entry(this.label, this.value, {this.selectable = false});

  final String label;
  final String value;

  /// For the phone number, which gets dialled from a second handset or copied
  /// into a message rather than read out loud.
  final bool selectable;

  bool get isFilled => value.trim().isNotEmpty;
}

/// A group of entries, or nothing when every one of them is blank.
///
/// Blank entries are hidden rather than shown as dashes, the same call the FIR
/// viewer makes: `POST /api/complaint` requires only a name and a description,
/// so a complaint filed at two in the morning with no phone and no location is a
/// complete record of what the citizen chose to give, not a defective one.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.entries});

  final String title;
  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) {
    final filled = entries.where((e) => e.isFilled).toList();
    if (filled.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          height: 1.35,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.label.copyWith(
              color: muted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final entry in filled)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: AppTypography.label.copyWith(color: muted),
                  ),
                  const SizedBox(height: 2),
                  entry.selectable
                      ? SelectableText(entry.value, style: valueStyle)
                      : Text(entry.value, style: valueStyle),
                ],
              ),
            ),
          Divider(color: scheme.outline.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

/// The citizen's own account, set apart from the entries around it.
///
/// Selectable, and drawn with the same left accent rule the FIR viewer gives a
/// statement — for the same reason: this is the paragraph that gets quoted into
/// an FIR narrative or a case diary, and re-typing it from a screen is how a
/// transcription error enters a document that will be read in court.
class _Narrative extends StatelessWidget {
  const _Narrative({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final body = text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT THEY SAID HAPPENED',
          style: AppTypography.label.copyWith(
            color: muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            // Square, like the FIR viewer's statement block and for the same
            // reason: Flutter refuses a borderRadius on a border whose sides are
            // not one colour, and the accent rule is worth more than the corners.
            border: Border(
              left: BorderSide(color: scheme.primary, width: 3),
              top: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
              right: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
              bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
            ),
          ),
          child: body.isEmpty
              // The server requires a description at filing time, so an empty
              // one means the row was written by something else. Said plainly
              // rather than hidden, because it is the officer's cue that this
              // complaint cannot be acted on as it stands.
              ? Text(
                  'No description was filed with this complaint.',
                  style: AppTypography.error.copyWith(color: muted),
                )
              : SelectableText(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.5,
                      ),
                ),
        ),
      ],
    );
  }
}

/// The trail: every stamped entry the desk has added, oldest first.
///
/// Rendered as separate lines rather than one paragraph, because that is what it
/// is — `ComplaintNote` appends one signed entry per action, and running them
/// together would make three decisions taken a week apart read as one.
class _Notes extends StatelessWidget {
  const _Notes({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final entries = ComplaintNote.lines(notes);

    return Column(
      key: ComplaintKeys.notes,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT THE DESK HAS DONE',
          style: AppTypography.label.copyWith(
            color: muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (entries.isEmpty)
          Text(
            'Nothing has been recorded against this complaint yet.',
            style: AppTypography.error.copyWith(color: muted),
          )
        else
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SelectableText(
                      entry,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.85),
                            height: 1.45,
                          ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// What the server knows, and what this screen is not.
class _Footer extends StatelessWidget {
  const _Footer({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final lines = [
      if (complaint.wasUpdated) 'Last updated ${complaint.updatedAtDisplay}',
      'What the citizen filed is read-only. Only the status, the FIR number '
          'and the notes can be changed.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              line,
              style: AppTypography.error.copyWith(color: muted, height: 1.5),
            ),
          ),
      ],
    );
  }
}

/// Respond, escalate, register an FIR — and the way into an FIR already linked.
class _Actions extends ConsumerWidget {
  const _Actions({required this.complaint, required this.isSaving});

  final Complaint complaint;
  final bool isSaving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.md,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            key: ComplaintKeys.respondAction,
            label: 'Respond',
            icon: Icons.reply_rounded,
            enabled: !isSaving,
            onPressed: () => showComplaintRespondSheet(context, complaint),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  key: ComplaintKeys.escalateAction,
                  label: 'Escalate',
                  icon: Icons.north_east_rounded,
                  enabled: !isSaving,
                  onPressed: () =>
                      showComplaintEscalateSheet(context, complaint),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                // Once an FIR exists, "Register an FIR" is the wrong offer — the
                // record is filed and a second one would be a duplicate. The
                // button becomes the way to read it instead.
                child: complaint.hasFir
                    ? SecondaryButton(
                        key: ComplaintKeys.openFirAction,
                        label: 'Open FIR',
                        icon: Icons.description_outlined,
                        onPressed: () => context.pushNamed(
                          AppRoutes.firRecordName,
                          pathParameters: {'firNo': complaint.firNo},
                        ),
                      )
                    : SecondaryButton(
                        key: ComplaintKeys.convertAction,
                        label: 'Register FIR',
                        icon: Icons.note_add_outlined,
                        enabled: !isSaving,
                        onPressed: () => _convert(context, ref),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Seeds the FIR form from this complaint and goes to it.
  ///
  /// Asks first when the form already holds work. The FIR draft survives the
  /// screen being popped — an officer part-way through registering an unrelated
  /// FIR may have left it there minutes ago — and seeding replaces it wholesale,
  /// so this is the one moment anybody can put the question to them.
  Future<void> _convert(BuildContext context, WidgetRef ref) async {
    final draft = ref.read(firFormControllerProvider).draft;

    if (draft.hasEnteredSomething) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace the FIR you started?'),
          content: Text(
            'The FIR form already has entries in it'
            '${draft.firNo.trim().isEmpty ? '' : ' for ${draft.firNo.trim()}'}. '
            'Starting one from this complaint will discard them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard and continue'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }

    // The dialog above is an async gap: the officer could have backed out of
    // this screen while it was up. Seeding the form anyway would be harmless,
    // but navigating from a dead context is not.
    if (!context.mounted) return;

    ref.read(complaintFirLinkProvider.notifier).start(complaint);

    // `pushNamed`, so backing out of the FIR form returns to this complaint
    // rather than to the dashboard. The conversion is only abandoned when the
    // officer says so — see the link controller's `cancel`.
    //
    // Not awaited: the future completes when the FIR form is popped, which is
    // minutes away and is not this method's business. Whether an FIR was filed
    // in the meantime is answered by the link controller, not by this call.
    unawaited(context.pushNamed(AppRoutes.firNewName));
  }
}
