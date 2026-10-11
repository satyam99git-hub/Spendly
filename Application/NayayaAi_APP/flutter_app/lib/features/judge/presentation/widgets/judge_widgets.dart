import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../lawyer/presentation/widgets/lawyer_widgets.dart';

/// Pieces shared by the judge screens. The cards, headings and empty lines are
/// the Lawyer Portal's (`lawyer_widgets.dart`), reused unchanged: both pages
/// are built from the same Tailwind palette, and the app should not grow two
/// copies of one card.

/// `STATUS_PILL` / `URGENCY_PILL` (judge_dashboard.html:571-580); anything
/// else gets the slate pill.
class JudgePill extends StatelessWidget {
  const JudgePill(this.value, {super.key});

  final String value;

  static const _styles = {
    'scheduled': (Color(0xFFDBEAFE), Color(0xFF1E40AF)),
    'adjourned': (Color(0xFFFEF9C3), Color(0xFF854D0E)),
    'completed': (Color(0xFFDCFCE7), Color(0xFF166534)),
    'cancelled': (Color(0xFFF1F5F9), Color(0xFF475569)),
    'urgent': (Color(0xFFFEE2E2), Color(0xFFB91C1C)),
    'normal': (Color(0xFFE0E7FF), Color(0xFF4338CA)),
  };

  @override
  Widget build(BuildContext context) {
    final style =
        _styles[value] ?? (const Color(0xFFF1F5F9), LawyerColors.slate600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: style.$2,
        ),
      ),
    );
  }
}

/// The urgent row's tint (`.row-urgent { background: #fff7ed }`, JD:44-46).
const judgeUrgentTint = Color(0xFFFFF7ED);

/// A failed load, said plainly with a way to try again. The page itself shows
/// nothing in these places (analysis OQ-J6); a phone that hangs on "Loading…"
/// with no retry is worse than one that says what happened.
///
/// When the server no longer recognises the session as a judge's, the way
/// forward is signing in again, not retrying.
class JudgeErrorView extends ConsumerWidget {
  const JudgeErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = error;
    final message = failure is Failure
        ? failure.message
        : 'Something went wrong. Please try again.';
    final expired = failure is AuthFailure && failure.sessionExpired;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: LawyerColors.red600, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          if (expired)
            FilledButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              child: const Text('Sign in again'),
            )
          else
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// A heading for a block inside a card (`text-xs font-bold uppercase`).
class JudgeBlockHeading extends StatelessWidget {
  const JudgeBlockHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: LawyerColors.slate500,
        ),
      );
}

/// A failure's message, or a plain sentence for anything else.
String judgeMessageOf(Object error) => error is Failure
    ? error.message
    : 'Something went wrong. Please try again.';
