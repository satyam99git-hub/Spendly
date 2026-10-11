import 'package:flutter/material.dart';

import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/legal_reference.dart';
import '../widgets/legal_keys.dart';

/// What a term means, and what the 2023 codes renumbered it to.
///
/// ---------------------------------------------------------------------------
/// ONE SEARCH BOX, NOT TWO
///
/// The website's console has these as two separate panels with a search box
/// each — a glossary and an amendment lookup. That is a fine shape for a sidebar
/// with room for both open at once. On a handset it makes the officer choose
/// which box to type into before they have been told which one has their answer.
///
/// They are the same act: *look something up*. So there is one box, and the
/// results come back in whichever of the two lists matched — "302" finds the BNS
/// renumbering, "bail" finds the definition, "arrest" finds both. Nobody has to
/// know in advance which table their question belongs to.
///
/// Neither list comes from the server. Both are hardcoded in the website's
/// `index.html` and transcribed into [legalGlossary] and [lawAmendments], which
/// says so at length — including that they can drift.
/// ---------------------------------------------------------------------------
class LawReferenceScreen extends StatefulWidget {
  const LawReferenceScreen({super.key});

  @override
  State<LawReferenceScreen> createState() => _LawReferenceScreenState();
}

class _LawReferenceScreenState extends State<LawReferenceScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final needle = _query.trim().toLowerCase();

    final amendments =
        lawAmendments.where((a) => a.matches(needle)).toList();
    final terms = legalGlossary.where((t) => t.matches(needle)).toList();

    return Scaffold(
      key: LegalKeys.reference,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Terms and the new codes'),
        backgroundColor: scheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxxl,
        ),
        children: [
          AppTextField(
            key: LegalKeys.referenceSearch,
            label: 'Look up',
            controller: _search,
            hintText: 'A term, or an old section — “bail”, “302”, “CrPC 154”',
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Held in the app, not fetched. The station database still numbers '
            'everything by the IPC and CrPC; a charge sheet written now cites '
            'the BNS and BNSS.',
            style: AppTypography.error.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.xxl),

          if (amendments.isEmpty && terms.isEmpty)
            StateMessage(
              icon: Icons.search_off_rounded,
              title: 'Nothing matches “${_query.trim()}”',
              body: 'Thirteen renumbered sections and twenty-three terms. Try '
                  'a section number on its own, or a word from the definition.',
              centred: true,
            ),

          // Renumbering first when anything matched it. An officer typing a
          // number wants the new section, and a definition of "bail" above it
          // would be an answer to a question they did not ask.
          if (amendments.isNotEmpty) ...[
            Text(
              'RENUMBERED IN 2023',
              style: AppTypography.label
                  .copyWith(color: muted, letterSpacing: 1.2),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final amendment in amendments) ...[
              _AmendmentRow(amendment: amendment),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],

          if (terms.isNotEmpty) ...[
            Text(
              'WHAT IT MEANS',
              style: AppTypography.label
                  .copyWith(color: muted, letterSpacing: 1.2),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final term in terms) ...[
              _TermRow(term: term),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ],
      ),
    );
  }
}

/// One old section and its replacement, with an arrow between them.
class _AmendmentRow extends StatelessWidget {
  const _AmendmentRow({required this.amendment});

  final LawAmendment amendment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Container(
      key: LegalKeys.amendmentRow(amendment.oldSection),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.04),
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrapped, because "IPC 120B → BNS Section 61" does not fit one line
          // on a narrow handset and an ellipsis in the middle of a section
          // number is worse than a second line.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              Text(
                amendment.oldLabel,
                style: AppTypography.fieldValue.copyWith(
                  color: muted,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: muted,
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 14, color: muted),
              Text(
                amendment.newSection,
                style: AppTypography.fieldValue.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            amendment.note,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({required this.term});

  final LegalTerm term;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      key: LegalKeys.glossaryRow(term.term),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          term.term,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
        ),
        const SizedBox(height: 2),
        // Selectable, for the same reason the section text is: an officer looks
        // a term up to put it into a note.
        SelectableText(
          term.definition,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.78),
                height: 1.4,
              ),
        ),
      ],
    );
  }
}
