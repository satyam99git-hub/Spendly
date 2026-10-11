import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/fir_receipt.dart';
import '../../../../core/utils/fir_number.dart';
import '../../domain/entities/fir_proof_outcome.dart';
import '../controllers/fir_form_controller.dart';

/// The FIR is on record.
///
/// The FIR number is the whole screen. It is what the complainant is told, what
/// evidence is filed against, what the PDF is named after and what every later
/// lookup starts from — and it is the one thing an officer standing at a desk
/// needs to be able to read off a phone and write down without tapping anything.
/// Hence the size, the saffron, and [SelectableText] so it can be copied rather
/// than transcribed.
///
/// There is no "download the PDF" here. The server generated one and the app
/// knows its filename, but fetching and viewing it belongs to FIR History (F9),
/// and a button that opens nothing would be worse than its absence.
class FirSuccessScreen extends ConsumerWidget {
  const FirSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt =
        ref.watch(firFormControllerProvider.select((s) => s.receipt));
    final proofs =
        ref.watch(firFormControllerProvider.select((s) => s.proofOutcome));
    final scheme = Theme.of(context).colorScheme;

    // Reachable for one frame between the reset below and the route changing.
    // The router keeps this screen unreachable otherwise — see app_router.
    if (receipt == null) {
      return const Scaffold(backgroundColor: AppColors.navy);
    }

    Future<void> finish(String routeName) async {
      // Reset first, then navigate. The filed FIR must not be the starting
      // point of the next one, and doing it in this order means the form is
      // never built against a draft that is already a record.
      await ref.read(firFormControllerProvider.notifier).reset();
      if (!context.mounted) return;
      context.goNamed(routeName);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
      child: PopScope(
        // Back must not return to the form. Its FIR number is taken and its
        // Submit would now fail with "already exists" — a dead end that looks
        // like the app losing the record that was just filed.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          finish(AppRoutes.homeName);
        },
        child: Scaffold(
          backgroundColor: AppColors.navy,
          body: Column(
            children: [
              const SafeArea(bottom: false, child: _Crest()),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: AppRadius.sheetTop,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Expanded(
                          child: _Body(receipt: receipt, proofs: proofs),
                        ),
                        _Actions(
                          onFileAnother: () => finish(AppRoutes.firNewName),
                          onDone: () => finish(AppRoutes.homeName),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Crest extends StatelessWidget {
  const _Crest();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Icon(
        Icons.verified_outlined,
        size: 52,
        color: Colors.white,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.receipt, required this.proofs});

  final FirReceipt receipt;

  /// What happened to the files attached while the form was being written, or
  /// null when none were. See [FirProofOutcome].
  final FirProofOutcome? proofs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saffron = isDark ? AppColors.saffronDark : AppColors.saffron;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    // Copied to a local so the null check below promotes; a field cannot.
    final attachments = proofs;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxFormWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'FIR registered',
                textAlign: TextAlign.center,
                style: AppTypography.display.copyWith(
                  fontSize: 26,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                receipt.message.isEmpty
                    // The server's own line when it sends one; it is already
                    // written for a person.
                    ? 'The FIR has been saved to police records.'
                    : receipt.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: muted,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xl,
                  horizontal: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: saffron.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: saffron.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    Text(
                      'FIR NUMBER',
                      style: AppTypography.label.copyWith(
                        color: muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(
                      receipt.firNo.isEmpty ? '—' : receipt.firNo,
                      textAlign: TextAlign.center,
                      style: AppTypography.fieldValue.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: saffron,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Give this number to the complainant.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (receipt.actSections.isNotEmpty)
                _Detail(
                  icon: Icons.gavel_rounded,
                  label: 'Filed under',
                  value: receipt.actSections,
                ),
              if (receipt.hasPdf)
                _Detail(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF generated at the station',
                  value: receipt.pdfLabel,
                ),
              if (receipt.createdAt.isNotEmpty)
                _Detail(
                  icon: Icons.schedule_rounded,
                  label: 'Recorded at (UTC)',
                  value: receipt.createdAt,
                ),
              // What became of the files attached while the form was being
              // written. On the receipt rather than in a snackbar because a
              // photograph that did not go up is something the officer has to
              // act on, and a snackbar is gone before they have read the FIR
              // number they came here for.
              if (attachments != null && !attachments.isEmpty)
                _Proofs(outcome: attachments, firNo: receipt.firNo),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: muted),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.label.copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onFileAnother, required this.onDone});

  final VoidCallback onFileAnother;
  final VoidCallback onDone;

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
      child: Column(
        children: [
          PrimaryButton(
            label: 'Done',
            icon: Icons.home_outlined,
            onPressed: onDone,
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: 'File another FIR',
            icon: Icons.note_add_outlined,
            onPressed: onFileAnother,
          ),
        ],
      ),
    );
  }
}

/// The attachments, on the receipt.
///
/// Shown only when files were attached. It has three shapes because there are
/// three outcomes and they are not variations on one message:
///
///   - **all filed** — a line and the stored names, which `secure_filename` may
///     have rewritten, so they are read back from the server rather than echoed;
///   - **some failed** — the same, plus what did not go up and why;
///   - **none filed** — only the failures, and an explicit reminder that the
///     FIR itself is registered, because a screen of red under an FIR number is
///     otherwise read as the filing having gone wrong.
class _Proofs extends StatelessWidget {
  const _Proofs({required this.outcome, required this.firNo});

  final FirProofOutcome outcome;

  /// The FIR the files belong to. Passed in rather than read off a filed item,
  /// because the case that needs it most is the one where nothing was filed.
  final String firNo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              outcome.hasFailures
                  ? Icons.report_problem_outlined
                  : Icons.attach_file_rounded,
              size: 18,
              color: outcome.hasFailures ? scheme.error : muted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATTACHMENTS',
                  style: AppTypography.label.copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  outcome.summary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.35,
                      ),
                ),
                for (final item in outcome.filed)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      '· ${item.filename}',
                      style: AppTypography.error.copyWith(color: muted),
                    ),
                  ),
                for (final failure in outcome.failed)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      '· ${failure.name} — ${failure.reason}',
                      style: AppTypography.error.copyWith(color: scheme.error),
                    ),
                  ),
                if (outcome.hasFailures) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'They are still on this handset. Add them from the '
                    'evidence locker against ${FirNumber.label(firNo)}.',
                    style: AppTypography.error.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
