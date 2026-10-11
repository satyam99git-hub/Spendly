import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/feedback/form_banner.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/fir_draft.dart';
import '../controllers/fir_form_controller.dart';
import '../controllers/fir_form_state.dart';
import '../widgets/fir_field_controllers.dart';
import '../widgets/fir_field_keys.dart';
import '../widgets/steps/fir_complainant_step.dart';
import '../widgets/steps/fir_complaint_step.dart';
import '../widgets/steps/fir_occurrence_step.dart';
import '../widgets/steps/fir_registration_step.dart';
import '../widgets/steps/fir_review_step.dart';

/// Registering an FIR: FORM IF-1 across four steps and a review.
///
/// ---------------------------------------------------------------------------
/// WHY A WIZARD, AND WHY A REVIEW AT THE END
///
/// FORM IF-1 has twenty-seven entries. On one scroll that is a wall — an officer
/// loses their place in it, and the entries that matter most (the sections, the
/// narrative) sit below entries that are blank on most FIRs (the passport
/// block). Four steps give the form the shape the paper has, so an officer who
/// knows IF-1 knows where they are: registration, occurrence, complainant,
/// complaint.
///
/// The review is not ceremony. An FIR is a statutory record that the app cannot
/// edit once filed — the server has no update route, and correction happens on
/// the paper trail at the station. The last screen before that is the last
/// chance anyone gets, so it prints every entry including the blanks, with a
/// link back into each step.
///
/// Only seven of the twenty-five typed entries are required. The wizard checks
/// them per step, so a blank is raised on the page that can fix it rather than
/// four pages later. See [FirDraft.missingIn].
/// ---------------------------------------------------------------------------
///
/// The screen owns exactly one thing: the text controllers. The draft, which
/// step is showing, the validation and the submission all live in
/// [FirFormController].
class FirFormScreen extends ConsumerWidget {
  const FirFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(firFormControllerProvider.select((s) => s.ready));
    final epoch = ref.watch(firFormControllerProvider.select((s) => s.epoch));

    if (!ready) {
      // The saved draft has not been read back yet. Holding here is what lets
      // every text box below be seeded once, from a draft that is final.
      return const Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      );
    }

    // Keyed on the epoch so discarding a draft — or filing one and starting
    // another — rebuilds every controller from the new draft. Without it,
    // "discard" would clear the state and leave the officer looking at the text
    // they just threw away.
    return _FirFormView(key: ValueKey(epoch));
  }
}

class _FirFormView extends ConsumerStatefulWidget {
  const _FirFormView({super.key});

  @override
  ConsumerState<_FirFormView> createState() => _FirFormViewState();
}

class _FirFormViewState extends ConsumerState<_FirFormView> {
  /// Owned here rather than by the step widgets, which are unmounted on every
  /// Next. See [FirFieldControllers].
  late final FirFieldControllers _fields;

  @override
  void initState() {
    super.initState();
    _fields = FirFieldControllers(ref.read(firFormControllerProvider).draft);
  }

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  FirFormController get _controller =>
      ref.read(firFormControllerProvider.notifier);

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  /// Leaves without ceremony. The draft is already saved — there is nothing to
  /// warn about, and a confirmation dialog that protects nothing is a dialog
  /// people learn to dismiss without reading.
  void _leave() {
    // Flush rather than rely on the debounce: the officer may be leaving within
    // a second of the last keystroke, and the controller outlives this screen.
    _controller.flush();
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.homeName);
    }
  }

  /// Back a step, or out of the form when there is no step behind this one.
  ///
  /// One affordance for both, because that is what the device's own back gesture
  /// does and an officer should not have to learn that the arrow and the gesture
  /// disagree.
  void _back() {
    _dismissKeyboard();
    if (!_controller.back()) _leave();
  }

  void _next() {
    _dismissKeyboard();
    _controller.next();
  }

  Future<void> _handleSubmit() async {
    _dismissKeyboard();

    final filed = await _controller.submit();
    if (!mounted) return;

    if (!filed) {
      // Either the draft is incomplete — in which case the controller has moved
      // to the step that is wrong and flipped showErrors, so the message is now
      // beside the box that caused it — or the server refused, and the banner
      // above the form is already showing why.
      return;
    }

    // Replaces rather than pushes: the form must not be behind the receipt. Its
    // draft is now a record, and a back gesture onto a form whose FIR number the
    // server has already taken would be a dead end.
    context.goNamed(AppRoutes.firSuccessName);
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this draft?'),
        content: const Text(
          'Everything entered so far is deleted from this device. Nothing has '
          'been sent to the station, so there is no record to withdraw.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (discard != true || !mounted) return;
    await _controller.reset();
    if (!mounted) return;
    _leave();
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(firFormControllerProvider);
    final scheme = Theme.of(context).colorScheme;

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
        // Never pops directly. Back has to mean "previous step" while there is
        // one, or the gesture would throw away a half-filled form from step 4 —
        // and it must not fire at all mid-submission, when leaving would strand
        // a request whose outcome the officer needs to see.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || state.isSubmitting) return;
          _back();
        },
        child: Scaffold(
          backgroundColor: AppColors.navy,
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: _Header(
                  step: state.step,
                  busy: state.isSubmitting,
                  onBack: _back,
                  onDiscard: _confirmDiscard,
                ),
              ),
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
                        if (state.restoredFromStorage || state.failure != null)
                          _Notices(
                            state: state,
                            onDismissRestored: _controller.acknowledgeRestore,
                          ),
                        Expanded(child: _stepBody(state)),
                        _Footer(
                          step: state.step,
                          busy: state.isSubmitting,
                          onBack: _back,
                          onNext: _next,
                          onSubmit: _handleSubmit,
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

  Widget _stepBody(FirFormState state) {
    switch (state.step) {
      case FirFormStep.registration:
        return FirRegistrationStep(state: state, fields: _fields);
      case FirFormStep.occurrence:
        return FirOccurrenceStep(state: state, fields: _fields);
      case FirFormStep.complainant:
        return FirComplainantStep(state: state, fields: _fields);
      case FirFormStep.complaint:
        return FirComplaintStep(state: state, fields: _fields);
      case FirFormStep.review:
        return FirReviewStep(state: state);
    }
  }
}

/// Navy header: where the officer is, the way back, and the one draft action.
class _Header extends StatelessWidget {
  const _Header({
    required this.step,
    required this.busy,
    required this.onBack,
    required this.onDiscard,
  });

  final FirFormStep step;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: busy ? null : onBack,
                // An arrow on every step including the first, where it leaves
                // the form. A close icon that turns into an arrow after step 1
                // makes the officer read the button before pressing it.
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
                tooltip: step.isFirst ? 'Close' : 'Previous step',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'New FIR',
                      textAlign: TextAlign.center,
                      style: AppTypography.brand.copyWith(
                        fontSize: 17,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      step.isReview
                          ? 'Review'
                          : 'Step ${step.number} of '
                              '${FirFormStep.entrySteps.length} · ${step.title}',
                      textAlign: TextAlign.center,
                      style: AppTypography.footerFine.copyWith(
                        color: AppColors.onNavyMuted,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<void>(
                enabled: !busy,
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                tooltip: 'Draft options',
                itemBuilder: (menuContext) => [
                  PopupMenuItem<void>(
                    onTap: onDiscard,
                    child: const Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 19),
                        SizedBox(width: AppSpacing.md),
                        Text('Discard draft'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _StepBar(step: step),
        ],
      ),
    );
  }
}

/// Five segments, filled up to where the officer is.
///
/// A bar rather than numbered circles: the officer needs to know how much is
/// left, not which numbered page they are on, and five tappable circles on a
/// navy header at the top of a form invite a jump into a step whose earlier
/// entries have not been filled in.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final FirFormStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (final each in FirFormStep.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  decoration: BoxDecoration(
                    color: each.index <= step.index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The restored-draft notice and the server's refusal, above the step body.
///
/// Pinned above the scroll rather than inside it, because a submission failure
/// is raised from the review and the officer may be scrolled to the bottom of it
/// — a banner in the list would appear somewhere they are not looking.
class _Notices extends StatelessWidget {
  const _Notices({required this.state, required this.onDismissRestored});

  final FirFormState state;
  final VoidCallback onDismissRestored;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        0,
      ),
      child: Column(
        children: [
          if (state.restoredFromStorage)
            Row(
              children: [
                const Expanded(
                  child: FormBanner(
                    tone: FormBannerTone.success,
                    message: 'Picked up where you left off. This draft is saved '
                        'on this device only — it has not been sent to the '
                        'station.',
                  ),
                ),
                IconButton(
                  onPressed: onDismissRestored,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Dismiss',
                ),
              ],
            ),
          if (state.failure != null)
            FormBanner(message: state.failure!.message),
        ],
      ),
    );
  }
}

/// Back and Next, or Back and File, pinned below the scroll.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.step,
    required this.busy,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  final FirFormStep step;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

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
      child: Row(
        children: [
          // Absent on step 1, where there is nothing behind this page — the
          // header's arrow is the way out, and a "Back" that leaves the form
          // would read like a step backwards through it.
          if (!step.isFirst) ...[
            Expanded(
              child: SecondaryButton(
                key: FirFieldKeys.back,
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                enabled: !busy,
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            // Wider than Back, because it is the one that moves the work
            // forward.
            flex: 2,
            child: step.isReview
                ? PrimaryButton(
                    key: FirFieldKeys.submit,
                    label: 'File this FIR',
                    icon: Icons.assignment_turned_in_outlined,
                    isLoading: busy,
                    // Never disabled on an incomplete draft — pressing it and
                    // being taken to the entry that is missing is shorter than
                    // a greyed-out button and no explanation. See
                    // FirFormController.submit.
                    onPressed: onSubmit,
                  )
                : PrimaryButton(
                    key: FirFieldKeys.next,
                    label: 'Next',
                    icon: Icons.arrow_forward_rounded,
                    enabled: !busy,
                    onPressed: onNext,
                  ),
          ),
        ],
      ),
    );
  }
}
