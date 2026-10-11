import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/form_banner.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/outcome_finding.dart';
import '../controllers/legal_query_controllers.dart';
import '../widgets/legal_keys.dart';

/// Describe what happened; get the sections it looks like, with what the
/// dataset says about each.
///
/// ---------------------------------------------------------------------------
/// THE ENDPOINT IS CALLED predict-outcome AND THIS SCREEN IS NOT CALLED THAT
///
/// There is no prediction. `case.csv` is a table of sections against their
/// punishments and their cognizable/bailable flags, and the handler scores each
/// row by how many of the situation's words it matches. No case history, no
/// model, no estimate of what any court will do.
///
/// The website presents the result under a purple "⚖️ Relevant Legal Sections
/// Found" heading, which is honest. An app screen headed "Predicted outcome"
/// would not be: an officer who reads "6 months to 3 years" off a handset and
/// repeats it to a complainant as what the accused will get has been misled by
/// this app. Hence the heading, the caveat under the box, and the match score
/// on every card — the last of which is the only honest measure of how much a
/// row is worth.
/// ---------------------------------------------------------------------------
class LawOutcomeScreen extends ConsumerStatefulWidget {
  const LawOutcomeScreen({super.key});

  @override
  ConsumerState<LawOutcomeScreen> createState() => _LawOutcomeScreenState();
}

class _LawOutcomeScreenState extends ConsumerState<LawOutcomeScreen> {
  final _situation = TextEditingController();

  @override
  void dispose() {
    _situation.dispose();
    super.dispose();
  }

  void _run() {
    FocusScope.of(context).unfocus();
    ref.read(outcomeControllerProvider.notifier).run(_situation.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(outcomeControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final findings = state.answer ?? const <OutcomeFinding>[];

    return Scaffold(
      key: LegalKeys.outcome,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Which sections apply'),
        backgroundColor: scheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          AppTextArea(
            key: LegalKeys.outcomeInput,
            label: 'What happened',
            controller: _situation,
            hintText: 'Two men took a phone from a woman near the bus stand '
                'and pushed her over.',
            enabled: !state.busy,
            minLines: 4,
            maxLines: 10,
            maxLength: 1000,
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            key: LegalKeys.outcomeSubmit,
            label: 'Find the sections',
            icon: Icons.travel_explore_rounded,
            isLoading: state.busy,
            onPressed: state.busy ? null : _run,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Matched on the words you use, against a table of sections and '
            'their punishments. It is a starting point for the charge, not a '
            'forecast of the sentence.',
            style: AppTypography.error.copyWith(color: muted),
          ),
          if (state.failure != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            FormBanner(message: state.failure!.message),
          ],
          if (state.hasAnswer) ...[
            const SizedBox(height: AppSpacing.xxl),
            if (findings.isEmpty)
              const StateMessage(
                icon: Icons.search_off_rounded,
                title: 'Nothing in the table matches',
                body: 'The search reads the words in your description. Try '
                    'naming the act itself — “theft”, “assault”, “cheating” — '
                    'or search the law library directly.',
                centred: true,
              )
            else ...[
              Text(
                'SECTIONS THAT LOOK RELEVANT',
                style: AppTypography.label
                    .copyWith(color: muted, letterSpacing: 1.2),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final finding in findings) ...[
                _FindingCard(finding: finding),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ] else if (!state.busy && state.failure == null) ...[
            const SizedBox(height: AppSpacing.xxxl),
            const StateMessage(
              icon: Icons.balance_rounded,
              title: 'Describe the incident',
              body: 'The more of what happened you write, the more of the '
                  'table the search has to match against.',
              centred: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// One matched section.
class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final OutcomeFinding finding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Container(
      key: LegalKeys.outcomeCard(finding.act, finding.section),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  finding.longLabel,
                  style: AppTypography.label.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // The score, stated. It is the only honest measure of how much
              // this row is worth, and hiding it would make the fifth match
              // look as solid as the first.
              Text(
                'match ${finding.score.toStringAsFixed(0)}',
                style: AppTypography.error.copyWith(color: muted),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            finding.title.isEmpty ? 'Untitled' : finding.title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (finding.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              finding.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: muted,
                    height: 1.4,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (finding.isCognizable != null)
                _Flag(
                  label: finding.isCognizable!
                      ? 'Cognizable'
                      : 'Non-cognizable',
                  // Cognizable is what lets an officer act without a warrant,
                  // so it is the flag that changes what happens next.
                  emphasis: finding.isCognizable!,
                ),
              if (finding.isBailable != null)
                _Flag(
                  label: finding.isBailable! ? 'Bailable' : 'Non-bailable',
                  emphasis: !finding.isBailable!,
                ),
              if (finding.bnsEquivalent.isNotEmpty)
                _Flag(label: finding.bnsEquivalent, emphasis: false),
            ],
          ),
          if (finding.punishment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Line(label: 'Punishment', value: finding.punishment),
          ],
          if (finding.sentencingRange.isNotEmpty)
            _Line(label: 'Range', value: finding.sentencingRange),
          if (finding.outcomeNote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              finding.outcomeNote,
              style: AppTypography.error.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.pushNamed(
                AppRoutes.lawSectionName,
                pathParameters: {
                  'act': finding.act,
                  'section': finding.section,
                },
              ),
              icon: const Icon(Icons.menu_book_outlined, size: 16),
              label: const Text('Read the section'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.label, required this.emphasis});

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour =
        emphasis ? scheme.error : scheme.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: emphasis ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: colour.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTypography.error.copyWith(
          color: colour,
          fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: AppTypography.error.copyWith(color: scheme.onSurface),
          children: [
            TextSpan(
              text: '$label — ',
              style: AppTypography.error.copyWith(color: muted),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
