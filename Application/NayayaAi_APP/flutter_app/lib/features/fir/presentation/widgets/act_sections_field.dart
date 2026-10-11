import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/act_section.dart';
import '../controllers/fir_lookup_providers.dart';
import 'fir_lookup_field.dart';

/// The "Act(s) and Section(s)" entry, as a list of chips plus an Add button.
///
/// The website types this as one free-text line. On a phone that means an
/// officer hand-typing `IPC Section 379, CRPC Section 41` — with a comma, the
/// word "Section", and the right spacing — into a column that F9's search and
/// F12's cross-references both read back. One stray keystroke there is a record
/// that will not be found by the query that needs it, and nobody notices for
/// months. So the pairs are built one at a time and the app owns the join.
///
/// **Optional**, exactly as the website's field is. `/generate_fir` reads an
/// empty `act_sections` as an instruction to work them out from the narrative
/// itself. The note under the label says so, because a field that looks required
/// and is not is a field officers stop to look things up for.
///
/// Adding happens in a sheet rather than in a staging row on the page. A staging
/// row holds text that is not in the draft yet, which is a value that can be
/// lost by tapping Next — and losing a section an officer believed they had
/// entered is exactly the class of silent error this widget exists to remove.
class ActSectionsField extends StatelessWidget {
  const ActSectionsField({
    super.key,
    required this.sections,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final List<ActSection> sections;
  final ValueChanged<List<ActSection>> onChanged;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acts and sections',
          style: AppTypography.label.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Left blank, the server reads the narrative and files the record under
        // the sections it suggests. Saying so is the difference between an
        // officer who does not know the sections leaving the field empty and
        // one who abandons the form to go and look them up.
        Text(
          sections.isEmpty
              ? 'Leave blank and the server will work them out from the '
                  'narrative when the FIR is filed. To see what it would '
                  'choose, and why, use “Suggest acts and sections” under the '
                  'narrative on the last step.'
              : 'Filed exactly as listed. Remove them all to have the server '
                  'work the sections out from the narrative instead.',
          style: AppTypography.error.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (sections.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final section in sections)
                _SectionChip(
                  section: section,
                  onRemoved: enabled
                      ? () => onChanged(
                            sections.where((s) => s != section).toList(),
                          )
                      : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _AddButton(
          hasAny: sections.isNotEmpty,
          hasError: hasError,
          onPressed: enabled ? () => _add(context) : null,
        ),
        SizedBox(
          height: 18,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    errorText!,
                    style: AppTypography.error.copyWith(color: scheme.error),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final added = await showModalBottomSheet<ActSection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      // The act just used is offered again: charges cluster within one act far
      // more often than they span several, so the second section is usually the
      // same act as the first.
      builder: (_) => _AddSectionSheet(initialAct: sections.lastOrNull?.act),
    );

    if (added == null) return;
    // Silently ignore a repeat rather than reporting it. Charging the same
    // section twice is a slip, not an error worth a message.
    if (sections.contains(added)) return;
    onChanged([...sections, added]);
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({required this.section, this.onRemoved});

  final ActSection section;
  final VoidCallback? onRemoved;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Chip(
      label: Text(section.wire),
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
      backgroundColor: scheme.primary.withValues(alpha: 0.10),
      side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
      onDeleted: onRemoved,
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      deleteIconColor: scheme.primary,
      deleteButtonTooltipMessage: 'Remove ${section.wire}',
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.hasAny,
    required this.hasError,
    this.onPressed,
  });

  final bool hasAny;
  final bool hasError;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = hasError ? scheme.error : scheme.primary;

    return SizedBox(
      height: AppSizes.controlHeight,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.add_rounded, size: 18, color: colour),
        label: Text(
          hasAny ? 'Add another section' : 'Add an act and section',
          style: AppTypography.button.copyWith(color: colour),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: hasError ? scheme.error : scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

/// Builds one act-and-section pair.
class _AddSectionSheet extends ConsumerStatefulWidget {
  const _AddSectionSheet({this.initialAct});

  final String? initialAct;

  @override
  ConsumerState<_AddSectionSheet> createState() => _AddSectionSheetState();
}

class _AddSectionSheetState extends ConsumerState<_AddSectionSheet> {
  final _sectionController = TextEditingController();
  final _sectionFocus = FocusNode();
  late String _act = widget.initialAct ?? '';

  @override
  void dispose() {
    _sectionController.dispose();
    _sectionFocus.dispose();
    super.dispose();
  }

  bool get _canAdd =>
      _act.trim().isNotEmpty && _sectionController.text.trim().isNotEmpty;

  void _submit() {
    if (!_canAdd) return;
    Navigator.of(context).pop(
      ActSection(act: _act.trim(), section: _sectionController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final acts = ref.watch(firActsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Add act and section',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FirLookupField(
              label: 'Act',
              value: _act,
              options: acts,
              hintText: 'Select an act',
              sheetTitle: 'Act',
              onRetry: () => ref.invalidate(firActsProvider),
              onChanged: (value) {
                setState(() => _act = value);
                _sectionFocus.requestFocus();
              },
            ),
            AppTextField(
              label: 'Section',
              controller: _sectionController,
              focusNode: _sectionFocus,
              hintText: 'e.g. 379, or 376(2)',
              // Sub-clauses and letters are part of a section number, so this is
              // a text entry with a numeric-first keyboard, not a number field.
              keyboardType: const TextInputType.numberWithOptions(
                signed: false,
                decimal: false,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z()/\- ]')),
                LengthLimitingTextInputFormatter(20),
              ],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'Add section',
              icon: Icons.add_rounded,
              enabled: _canAdd,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
