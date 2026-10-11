import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../controllers/legal_providers.dart';

/// Picks the second section for a comparison: an act and a number.
///
/// A number typed rather than a list scrolled. The list is the right shape for
/// browsing and the wrong shape here — an officer comparing 378 with 379 knows
/// the number, and scrolling to it through 575 rows to make a comparison they
/// have already decided on is the slow way round. The library's own list is one
/// tap away for the times they do not.
///
/// Returns null when dismissed.
Future<({String act, String no})?> showSectionCompareSheet(
  BuildContext context, {
  required String initialAct,
}) {
  return showModalBottomSheet<({String act, String no})>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (_) => _CompareSheet(initialAct: initialAct),
  );
}

class _CompareSheet extends ConsumerStatefulWidget {
  const _CompareSheet({required this.initialAct});

  final String initialAct;

  @override
  ConsumerState<_CompareSheet> createState() => _CompareSheetState();
}

class _CompareSheetState extends ConsumerState<_CompareSheet> {
  final _number = TextEditingController();
  late String _act = widget.initialAct;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _submit() {
    final no = _number.text.trim();
    if (no.isEmpty) return;
    Navigator.of(context).pop((act: _act, no: no));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final acts = ref.watch(legalActsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compare with',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              acts.when(
                loading: () => const SizedBox(height: 40),
                error: (_, __) => const SizedBox(height: 40),
                data: (list) => Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final act in list)
                      ChoiceChip(
                        label: Text(act),
                        selected: _act == act,
                        onSelected: (_) => setState(() => _act = act),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Section number',
                controller: _number,
                hintText: 'e.g. 379',
                // The section tables key on an integer, so the number pad is
                // the right keyboard and a letter typed here would find nothing.
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Opened straight from the station database. A number with no '
                'section behind it says so rather than showing a blank.',
                style: AppTypography.error.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Compare',
                icon: Icons.compare_arrows_rounded,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
