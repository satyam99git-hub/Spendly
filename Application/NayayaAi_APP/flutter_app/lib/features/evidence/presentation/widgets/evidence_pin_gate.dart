import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/password_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../controllers/evidence_lock_controller.dart';
import 'evidence_keys.dart';

/// The PIN screen in front of the locker.
///
/// Occupies the Evidence tab rather than pushing a route, so there is no back
/// gesture that lands *behind* the gate and no route an officer can be deep-
/// linked past it to. The locker's list is simply not built until the state says
/// unlocked.
///
/// What it is and is not protecting is argued in [EvidenceLockController]. In
/// short: a phone left on a desk, not an attacker — and the screen says as much,
/// because a gate that overstates itself is one people trust with more than it
/// can hold.
class EvidencePinGate extends ConsumerStatefulWidget {
  const EvidencePinGate({super.key});

  @override
  ConsumerState<EvidencePinGate> createState() => _EvidencePinGateState();
}

class _EvidencePinGateState extends ConsumerState<EvidencePinGate> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Sends the PIN to the server and reacts to what it says.
  ///
  /// Awaited rather than fired: the check is a round trip now, and the box must
  /// not be cleared until there is an answer to clear it for.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final opened = await ref
        .read(evidenceLockControllerProvider.notifier)
        .unlock(_controller.text);

    if (opened || !mounted) return;

    // Clear and re-focus on a rejected PIN. Leaving the rejected value in the
    // box means the next attempt starts by selecting-all and deleting, which on
    // a phone is three fiddly taps before the officer can begin.
    //
    // Only when the server actually rejected it. A PIN that could not be sent
    // is still the officer's best guess, and retyping it after the signal comes
    // back is work the gate has no reason to ask for.
    if (ref.read(evidenceLockControllerProvider).failedAttempts > _seenFailures) {
      _seenFailures = ref.read(evidenceLockControllerProvider).failedAttempts;
      _controller.clear();
    }
    _focus.requestFocus();
  }

  /// Rejections already reacted to, so a failure to *reach* the server can be
  /// told apart from a PIN the server turned down.
  int _seenFailures = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(evidenceLockControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxFormWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Aligned rather than plain: the column stretches its children
                // so the PIN box and the button fill the width, and a bare
                // Container would be stretched with them into a banner.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: AppSizes.iconChip + 12,
                    height: AppSizes.iconChip + 12,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: scheme.primary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Evidence locker',
                  style: AppTypography.display.copyWith(
                    fontSize: 24,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Enter the locker PIN issued to this station.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: muted,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                PasswordField(
                  key: EvidenceKeys.pinField,
                  label: 'Locker PIN',
                  controller: _controller,
                  focusNode: _focus,
                  hintText: 'Station PIN',
                  errorText: state.error,
                  // Not the account password — see PasswordField.autofillHints.
                  autofillHints: null,
                  onChanged: (_) =>
                      ref.read(evidenceLockControllerProvider.notifier)
                          .clearError(),
                  enabled: !state.verifying,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  key: EvidenceKeys.pinSubmit,
                  label: 'Unlock',
                  icon: Icons.lock_open_rounded,
                  // The check is a round trip to the server. Without this the
                  // button looks inert while it runs, which on a slow station
                  // link is a button an officer taps four more times.
                  isLoading: state.verifying,
                  onPressed: state.verifying ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: muted),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        // Deliberately not "keeps evidence secure". The server
                        // serves these files without a session check, so this
                        // gate keeps an unattended handset shut and nothing
                        // more — and an officer relying on it should know that.
                        'This PIN keeps the locker closed on an unattended '
                        'handset. It is not a substitute for signing out.',
                        style: AppTypography.error.copyWith(
                          color: muted,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
