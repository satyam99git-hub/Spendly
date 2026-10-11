import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/form_dates.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/fir_record.dart';
import '../controllers/fir_download_controller.dart';
import '../controllers/fir_history_providers.dart';
import '../widgets/fir_history_keys.dart';

/// One FIR, as police records hold it, in FORM IF-1 order.
///
/// ---------------------------------------------------------------------------
/// WHY THE APP RENDERS THE RECORD INSTEAD OF OPENING THE SERVER'S PAGE
///
/// The server has `/fir/view/<fir_no>`, which renders the same document as HTML.
/// Opening that in a browser would have been a two-line feature.
///
/// It is not what an officer needs. That page is desktop-width and unstyled for
/// a phone, it leaves the app (so back-navigation lands somewhere else), it
/// cannot show the entries in the app's own typography, and it prints every
/// column including the eighteen a short-format FIR leaves blank — a wall of
/// empty labels that reads like a defective record rather than a complete one.
///
/// Rendering from the JSON also means the viewer is the same shape as the rest
/// of the app: failures arrive as [Failure]s with a sentence, a missing record
/// says so, and nothing depends on a browser being installed.
/// ---------------------------------------------------------------------------
///
/// **Read-only, and permanently so from the app's side.** The server has no
/// route that updates an FIR — `/generate_fir` only inserts, and rejects a
/// number it already holds. A record is corrected at the station, on the paper
/// trail, which is what the law expects of a statutory document.
class FirRecordScreen extends ConsumerWidget {
  const FirRecordScreen({super.key, required this.firNo});

  /// From the route, so the screen can rebuild itself from its URL after a
  /// process death and so it always shows what the server holds now rather than
  /// what the history list happened to have downloaded earlier.
  final String firNo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(firRecordProvider(firNo));

    return Scaffold(
      // Stated rather than inherited. The theme's scaffold background is navy —
      // the auth screens are built on it — so a page that does not paint its own
      // surface renders dark-text-on-navy. See AppTheme.
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(FirRecord.label(firNo))),
      body: SafeArea(
        top: false,
        child: record.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StateMessage(
            centred: true,
            icon: error is ValidationFailure
                ? Icons.help_outline_rounded
                : Icons.cloud_off_rounded,
            // A 404 here is not a fault, it is an answer: the number names no
            // record. Saying "something went wrong" to that sends an officer
            // looking for a problem with the app instead of at the number.
            title: error is ValidationFailure
                ? 'No such FIR in police records'
                : 'This FIR could not be loaded',
            body: error is Failure
                ? error.message
                : 'Something went wrong. Go back and try again.',
          ),
          data: (record) => _Body(record: record),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.record});

  final FirRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final download = ref.watch(firDownloadControllerProvider(record.firNo));

    // Shown once, then cleared, so a rebuild — a theme change, a keyboard, a
    // rotation — does not put the same snackbar up again.
    ref.listen(firDownloadControllerProvider(record.firNo), (previous, next) {
      final notice = next.notice;
      if (notice == null || notice == previous?.notice) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(notice)));
      ref
          .read(firDownloadControllerProvider(record.firNo).notifier)
          .clearNotice();
    });

    return Column(
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
              _Header(record: record),
              const SizedBox(height: AppSpacing.xxl),
              _Block(
                title: 'REGISTRATION',
                entries: [
                  _Entry('District / State', record.district),
                  _Entry('Police station', record.policeStation),
                  _Entry('FIR date', record.firDateDisplay),
                  _Entry('Year', record.year),
                  _Entry('General diary reference', record.gdrEntryNo),
                  _Entry('Type of information', record.typeOfInformation),
                ],
              ),
              _Block(
                title: 'OCCURRENCE',
                entries: [
                  _Entry('Day', record.occurrenceDay),
                  _Entry(
                    'Date',
                    FormDates.displayDate(record.occurrenceDate),
                  ),
                  _Entry(
                    'Time',
                    FormDates.displayTime(record.occurrenceTime),
                  ),
                  _Entry('Place', record.placeOfOccurrence),
                  _Entry(
                    'Information received on',
                    FormDates.displayDate(record.infoReceivedDate),
                  ),
                  _Entry(
                    'Information received at',
                    FormDates.displayTime(record.infoReceivedTime),
                  ),
                ],
              ),
              _Block(
                title: 'COMPLAINANT / INFORMANT',
                entries: [
                  _Entry('Name', record.complainantName),
                  _Entry('Father / husband', record.fatherHusbandName),
                  _Entry('Date of birth', FormDates.displayDate(record.dob)),
                  _Entry('Nationality', record.nationality),
                  _Entry('Occupation', record.occupation),
                  _Entry('Address', record.address),
                  _Entry('Passport number', record.passportNo),
                  _Entry(
                    'Passport issued on',
                    FormDates.displayDate(record.dateOfIssue),
                  ),
                  _Entry('Passport issued at', record.placeOfIssue),
                ],
              ),
              _Block(
                title: 'THE COMPLAINT',
                entries: [
                  _Entry('Details of the accused', record.detailsOfAccused),
                  _Entry('Property particulars', record.propertyParticulars),
                  _Entry(
                    'Reasons for delay in reporting',
                    record.reasonsForDelay,
                  ),
                ],
              ),
              _Narrative(statement: record.statement),
              const SizedBox(height: AppSpacing.xxl),
              _RecordFooter(record: record),
            ],
          ),
        ),
        _DownloadBar(
          isDownloading: download.isDownloading,
          onDownload: () => ref
              .read(firDownloadControllerProvider(record.firNo).notifier)
              .download(),
        ),
      ],
    );
  }
}

/// The FIR number, its sections and when it was recorded.
class _Header extends StatelessWidget {
  const _Header({required this.record});

  final FirRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saffron = isDark ? AppColors.saffronDark : AppColors.saffron;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final sections = record.sectionList;

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
            'FORM IF-1 · FIRST INFORMATION REPORT',
            style: AppTypography.label.copyWith(
              color: muted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Selectable for the same reason as on the receipt: this number gets
          // read off the screen and written into a register or a message.
          SelectableText(
            record.firNo,
            style: AppTypography.fieldValue.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: saffron,
            ),
          ),
          if (sections.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Filed under',
              style: AppTypography.label.copyWith(color: muted),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              record.actSections,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.35,
                  ),
            ),
          ],
          if (record.filedAtDisplay.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: muted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Recorded ${record.filedAtDisplay}',
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

/// One labelled entry of the form. [value] empty means it was never filled in.
class _Entry {
  const _Entry(this.label, this.value);

  final String label;
  final String value;

  bool get isFilled => value.trim().isNotEmpty;
}

/// A group of entries, or nothing at all when every one of them is blank.
///
/// **Blank entries are hidden, not shown as dashes.** A short-format FIR leaves
/// eighteen of the twenty-seven empty, and a viewer that printed all of them
/// would put a screen of empty labels in front of an officer — which reads as a
/// record filed badly rather than as a record filed briefly. What was recorded
/// is what is shown; the footer says so once, at the bottom, rather than
/// nineteen times.
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
                  Text(
                    entry.value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          Divider(color: scheme.outline.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

/// The narrative, set apart from the entries around it.
///
/// Selectable, and the only part of the record that is: a statement gets quoted
/// into a case diary or a charge sheet, and re-typing it from a screen is how a
/// transcription error enters a document that will be read in court.
class _Narrative extends StatelessWidget {
  const _Narrative({required this.statement});

  final String statement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final text = statement.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT HAPPENED',
          style: AppTypography.label.copyWith(
            color: muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          key: FirHistoryKeys.narrative,
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            // Square, unlike every other block on this screen, because a rounded
            // box cannot carry the accent rule: Flutter refuses a borderRadius
            // on a border whose sides are not one colour. The rule is worth more
            // than the corners — it is what marks the complainant's own words
            // apart from the entries an officer filled in around them, and it is
            // how the website renders the same paragraph.
            border: Border(
              left: BorderSide(color: scheme.primary, width: 3),
              top: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
              right: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
              bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
            ),
          ),
          child: text.isEmpty
              // Not hidden like the other blanks. Every other entry can be
              // reconstructed from the station register; a statutory record with
              // no narrative is one an officer needs to know about.
              ? Text(
                  'No statement was recorded with this FIR.',
                  style: AppTypography.error.copyWith(color: muted),
                )
              : SelectableText(
                  text,
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

/// What the server knows about the record, and what this screen is not.
class _RecordFooter extends StatelessWidget {
  const _RecordFooter({required this.record});

  final FirRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final lines = [
      if (record.status.isNotEmpty) 'Status — ${record.status}',
      if (record.firId.isNotEmpty) 'Record ID — ${record.firId}',
      if (record.hasPdf) 'PDF — ${record.pdfLabel}',
      'Entries left blank at the station are not shown.',
      'Read-only. An FIR is corrected at the station, not in the app.',
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

/// The one action the screen has.
///
/// Always offered, even when the record names no PDF. Whether the file is
/// still there is not a question the record can answer — the column is a claim
/// written at filing time, and the object behind it lives in a Supabase bucket
/// the app never talks to — so the button asks, and a 404 comes back as a
/// sentence explaining that rather than as a button that was never there and
/// never said why.
class _DownloadBar extends StatelessWidget {
  const _DownloadBar({
    required this.isDownloading,
    required this.onDownload,
  });

  final bool isDownloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
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
      child: PrimaryButton(
        key: FirHistoryKeys.download,
        label: 'Download the PDF',
        icon: Icons.picture_as_pdf_outlined,
        isLoading: isDownloading,
        onPressed: onDownload,
      ),
    );
  }
}
