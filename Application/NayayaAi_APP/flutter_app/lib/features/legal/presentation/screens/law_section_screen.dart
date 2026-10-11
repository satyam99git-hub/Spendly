import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/legal_section.dart';
import '../controllers/legal_providers.dart';
import '../widgets/legal_keys.dart';
import '../widgets/section_compare_sheet.dart';

/// One section in full, with the option to hold a second one beside it.
///
/// ---------------------------------------------------------------------------
/// WHY COMPARISON IS ON THIS SCREEN AND NOT A TOOL OF ITS OWN
///
/// The website has a comparison panel with two pickers, and an officer arrives
/// at it having already decided which two sections they want. That is not how
/// the question comes up. It comes up while reading one section — "is this 378
/// or 379?", "does the CRPC say the same thing?" — with the first section
/// already on screen.
///
/// So the second one is chosen from here, against the first, and the two are
/// stacked rather than columned: two columns of legal text on a 390-point
/// screen is two columns nobody can read. Stacked and labelled, an officer
/// scrolls between them, which is what comparing two paragraphs actually is.
/// ---------------------------------------------------------------------------
class LawSectionScreen extends ConsumerStatefulWidget {
  const LawSectionScreen({
    super.key,
    required this.act,
    required this.section,
  });

  final String act;
  final String section;

  @override
  ConsumerState<LawSectionScreen> createState() => _LawSectionScreenState();
}

class _LawSectionScreenState extends ConsumerState<LawSectionScreen> {
  /// The section being held beside this one, if any. Held in the screen rather
  /// than a provider: it is a comparison the officer is making right now, and
  /// it should not survive leaving the screen.
  ({String act, String no})? _against;

  Future<void> _compare() async {
    final picked = await showSectionCompareSheet(
      context,
      // Defaults to this section's own act, which is the usual comparison —
      // 378 against 379 — while leaving the picker free to change it.
      initialAct: widget.act,
    );
    if (picked == null || !mounted) return;
    setState(() => _against = picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = ref.watch(
      legalSectionProvider((act: widget.act, no: widget.section)),
    );

    return Scaffold(
      key: LegalKeys.sectionDetail,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text('${widget.act} ${widget.section}'),
        backgroundColor: scheme.surface,
      ),
      body: primary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.menu_book_outlined,
          title: 'That section could not be opened',
          body: '$error',
          centred: true,
        ),
        data: (section) => ListView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          children: [
            _SectionBody(section: section),
            const SizedBox(height: AppSpacing.xxl),
            SecondaryButton(
              key: LegalKeys.compareAction,
              label: _against == null
                  ? 'Compare with another section'
                  : 'Compare with a different section',
              icon: Icons.compare_arrows_rounded,
              onPressed: _compare,
            ),
            if (_against != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              _Comparison(
                key: LegalKeys.comparePanel,
                against: _against!,
                onClear: () => setState(() => _against = null),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The heading, the title and the text of one section.
class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section, this.dimmed = false});

  final LegalSection section;

  /// Drawn back a little, for the second section in a comparison — so the one
  /// the officer navigated to stays the subject of the screen.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.longLabel,
          style: AppTypography.label.copyWith(
            color: dimmed ? muted : scheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          section.title.isEmpty ? 'Untitled' : section.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Selectable, because the reason an officer opens a section on a
        // handset is often to copy a phrase of it into an FIR narrative.
        SelectableText(
          section.description.isEmpty
              ? 'The station database holds no text for this section.'
              : section.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: section.description.isEmpty ? muted : scheme.onSurface,
                height: 1.5,
                fontStyle: section.description.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
        ),
      ],
    );
  }
}

/// The second section, under a rule.
class _Comparison extends ConsumerWidget {
  const _Comparison({
    super.key,
    required this.against,
    required this.onClear,
  });

  final ({String act, String no}) against;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final other = ref.watch(legalSectionProvider(against));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                'COMPARED WITH',
                style: AppTypography.label.copyWith(
                  color: muted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Stop comparing',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        other.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => StateMessage(
            icon: Icons.menu_book_outlined,
            title: '${against.act} ${against.no} could not be opened',
            body: '$error',
          ),
          data: (section) => _SectionBody(section: section, dimmed: true),
        ),
      ],
    );
  }
}
