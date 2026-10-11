import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/form_banner.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/act_section.dart';
import '../../domain/entities/section_suggestion.dart';
import '../controllers/section_suggestion_controller.dart';
import 'fir_field_keys.dart';

/// Opens the suggestion sheet and returns the sections the officer accepted.
///
/// Returns an empty list when they closed it without taking any, so the caller
/// can treat "took nothing" and "dismissed" the same way — because they are the
/// same thing.
Future<List<ActSection>> showSuggestSectionsSheet({
  required BuildContext context,
  required String narrative,
  required List<ActSection> alreadyAdded,
}) async {
  final taken = await showModalBottomSheet<List<ActSection>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (_) => _SuggestSectionsSheet(
      narrative: narrative,
      alreadyAdded: alreadyAdded,
    ),
  );
  return taken ?? const [];
}

/// The suggestions, each with the reason the server gave for it.
///
/// ---------------------------------------------------------------------------
/// WHY EVERY ROW CARRIES A REASON AND A CONFIDENCE
///
/// The server has been choosing sections from the narrative since before this
/// sheet existed — `/generate_fir` runs a keyword matcher whenever the sections
/// field arrives empty, and files the record under whatever it finds. What it
/// has never done is *say so*. The officer learns which sections were chosen by
/// reading them off the receipt, after the FIR is registered, with no way to
/// disagree.
///
/// So this sheet is not "AI picks the sections". It is the same choice, made
/// visible and made rejectable, one screen earlier. Nothing here is applied
/// until the officer taps Add, nothing is pre-selected, and closing the sheet
/// files exactly what it would have filed before.
///
/// The reason is what makes rejecting possible. A list of bare section numbers
/// can only be accepted or ignored wholesale; a list that says *why* each one is
/// there can be argued with line by line, which is the only form of review worth
/// having on a charge.
/// ---------------------------------------------------------------------------
class _SuggestSectionsSheet extends ConsumerStatefulWidget {
  const _SuggestSectionsSheet({
    required this.narrative,
    required this.alreadyAdded,
  });

  final String narrative;
  final List<ActSection> alreadyAdded;

  @override
  ConsumerState<_SuggestSectionsSheet> createState() =>
      _SuggestSectionsSheetState();
}

class _SuggestSectionsSheetState extends ConsumerState<_SuggestSectionsSheet> {
  final _selected = <ActSection>{};

  @override
  void initState() {
    super.initState();
    // Asked on open rather than behind a second tap: opening this sheet is the
    // request. Re-asked every time, because the narrative may have been edited
    // since — the controller holds the previous answer only so the sheet has
    // something to render while this one is in flight.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(sectionSuggestionControllerProvider.notifier)
          .ask(widget.narrative);
    });
  }

  bool _isAdded(SectionSuggestion suggestion) =>
      widget.alreadyAdded.contains(suggestion.asSection);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sectionSuggestionControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.94,
      minChildSize: 0.4,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              key: FirFieldKeys.suggestSheet,
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xl,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              children: _body(context, state),
            ),
          ),
          if (_selected.isNotEmpty)
            _AddBar(
              count: _selected.length,
              onAdd: () => Navigator.of(context).pop(_selected.toList()),
            ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, SectionSuggestionState state) {
    final scheme = Theme.of(context).colorScheme;

    if (state.busy) {
      return const [
        SizedBox(height: AppSpacing.xxxl),
        Center(child: CircularProgressIndicator()),
        SizedBox(height: AppSpacing.xl),
        Center(child: Text('Reading the narrative…')),
      ];
    }

    if (state.failure != null) {
      return [
        const _Heading(),
        const SizedBox(height: AppSpacing.lg),
        FormBanner(message: state.failure!.message),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Filing is not blocked by this. Enter the sections yourself, or '
          'leave them blank and the server will still work them out when the '
          'FIR is filed.',
          style: AppTypography.error.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ];
    }

    final result = state.result;
    if (result == null) return const [SizedBox.shrink()];

    if (result.isEmpty) {
      return [
        const _Heading(),
        const SizedBox(height: AppSpacing.xxl),
        StateMessage(
          icon: Icons.search_off_rounded,
          title: result.message.isNotEmpty
              ? 'Not enough to go on yet'
              : 'No sections matched',
          body: result.message.isNotEmpty
              ? result.message
              : 'Nothing in this narrative matched a section the server could '
                  'verify. Enter the sections yourself, or leave them blank '
                  'and the server will work them out at filing.',
          centred: true,
        ),
      ];
    }

    return [
      const _Heading(),
      const SizedBox(height: AppSpacing.md),
      // Said before the list, not after it. An officer who reads the caveat
      // under twelve section cards has already decided what to do.
      Text(
        'Suggestions, not charges. Nothing is added until you tap Add, and '
        'nothing here is filed on its own.',
        style: AppTypography.error.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      if (result.isFallback) ...[
        const SizedBox(height: AppSpacing.md),
        const _Advisory(
          icon: Icons.cloud_off_rounded,
          text: 'The assistant was unreachable, so these came from keyword '
              'matching on the narrative. It matches words, not meaning — '
              'read them closely.',
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      for (final suggestion in result.suggestions) ...[
        _SuggestionCard(
          suggestion: suggestion,
          added: _isAdded(suggestion),
          selected: _selected.contains(suggestion.asSection),
          onToggle: () => setState(() {
            final section = suggestion.asSection;
            if (!_selected.remove(section)) _selected.add(section);
          }),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (result.note.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xs),
        // Deliberately not a card and not selectable. The server could not
        // verify this one against its section tables, so it must not sit in the
        // list looking as solid as the ones it could.
        _Advisory(icon: Icons.info_outline_rounded, text: result.note),
      ],
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Suggested sections',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }
}

/// A line the officer should read but cannot act on by tapping.
class _Advisory extends StatelessWidget {
  const _Advisory({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.error.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.added,
    required this.selected,
    required this.onToggle,
  });

  final SectionSuggestion suggestion;
  final bool added;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = selected || added;

    return InkWell(
      key: FirFieldKeys.suggestion(suggestion.act, suggestion.section),
      // An already-added section is shown, not hidden: an officer who added it
      // by hand a minute ago should see that the server agrees, which is worth
      // more than the row of space that removing it would save.
      onTap: added ? null : onToggle,
      borderRadius: AppRadius.controlBorder,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: on ? scheme.primary.withValues(alpha: 0.06) : scheme.surface,
          borderRadius: AppRadius.controlBorder,
          border: Border.all(
            color: on ? scheme.primary : scheme.outlineVariant,
            width: on ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              added
                  ? Icons.check_circle_rounded
                  : selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
              size: 22,
              color: on
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${suggestion.act} Section ${suggestion.section}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                        ),
                      ),
                      _ConfidenceChip(confidence: suggestion.confidence),
                    ],
                  ),
                  if (suggestion.title.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      suggestion.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.8),
                          ),
                    ),
                  ],
                  if (suggestion.reason.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      suggestion.reason,
                      style: AppTypography.error.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (added) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Already on this FIR',
                      style: AppTypography.error.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence});

  final SuggestionConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = switch (confidence) {
      SuggestionConfidence.high => scheme.primary,
      SuggestionConfidence.medium => scheme.tertiary,
      SuggestionConfidence.low => scheme.onSurface.withValues(alpha: 0.55),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        confidence.label,
        style: AppTypography.error.copyWith(
          color: colour,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Pinned below the list, because the officer decides after reading the last
/// card and a button above the fold is a button they scroll back for.
class _AddBar extends StatelessWidget {
  const _AddBar({required this.count, required this.onAdd});

  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.md,
        AppSpacing.xxl,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: PrimaryButton(
        key: FirFieldKeys.suggestAdd,
        label: count == 1 ? 'Add 1 section' : 'Add $count sections',
        icon: Icons.add_rounded,
        onPressed: onAdd,
      ),
    );
  }
}
