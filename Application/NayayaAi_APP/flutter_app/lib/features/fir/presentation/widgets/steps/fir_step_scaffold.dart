import 'package:flutter/material.dart';

import '../../../../../theme/app_dimensions.dart';
import '../../../../../theme/app_typography.dart';
import '../../../domain/entities/fir_draft.dart';
import '../../controllers/fir_form_state.dart';
import '../fir_field_keys.dart';

/// The scrolling body every step of the wizard is built into.
///
/// Shared so the four steps cannot drift into four different paddings, and keyed
/// on the step so moving between them rebuilds the [ListView] rather than
/// carrying the previous page's scroll offset onto the next — which on a short
/// step lands the officer halfway down a page they have not read.
class FirStepScaffold extends StatelessWidget {
  const FirStepScaffold({
    super.key,
    required this.step,
    required this.children,
  });

  final FirFormStep step;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: FirFieldKeys.step(step),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      children: children,
    );
  }
}

/// A heading over a run of related entries within a step.
class FirGroupLabel extends StatelessWidget {
  const FirGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.label.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// A line under a group explaining that everything in it may be left blank.
///
/// Worth the space. Eighteen of the twenty-five entries are optional, and an
/// officer at a counter faced with a passport block and no guidance will either
/// stall on it or invent a value — both worse than an empty column. Saying so
/// once per group is what keeps the full form fillable in the time a complainant
/// is standing there.
class FirOptionalNote extends StatelessWidget {
  const FirOptionalNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.error.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The message a required-but-blank entry shows, or null.
///
/// Silent until [FirFormState.showErrors] — that is, until a Next or a Submit
/// has actually been refused. A form that flags every required box the moment it
/// opens looks broken and teaches people to ignore red.
///
/// Matched against [FirDraft.missing] by the entry's on-screen label, which is
/// the same string the draft reports. Keeping one vocabulary means a label
/// changed here without changing the draft shows no error at all, rather than
/// showing one against the wrong box.
String? Function(String label) firErrorFor(FirFormState state) {
  return (label) =>
      state.showErrors && state.draft.missing.contains(label) ? 'Required' : null;
}
