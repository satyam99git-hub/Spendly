import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_dimensions.dart';
import '../../data/models/case_client_status.dart';
import '../controllers/rights_and_case_controllers.dart';
import '../widgets/citizen_widgets.dart';

/// My Case Status — citizen_dashboard.html `<section id="case-status">`
/// (lines 529-567) and `checkCaseStatus()` (lines 1073-1110).
///
/// What a lawyer has shared about an FIR, looked up by its number. The server
/// answers anyone who has the number and the lawyer's permission (limitation
/// L6); there is nothing about the FIR it will tell a citizen beyond these four
/// values.
class CaseStatusScreen extends ConsumerStatefulWidget {
  const CaseStatusScreen({super.key});

  @override
  ConsumerState<CaseStatusScreen> createState() => _CaseStatusScreenState();
}

class _CaseStatusScreenState extends ConsumerState<CaseStatusScreen> {
  final _fir = TextEditingController();

  @override
  void dispose() {
    _fir.dispose();
    super.dispose();
  }

  void _check() {
    FocusScope.of(context).unfocus();
    ref.read(caseStatusControllerProvider.notifier).check(_fir.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(caseStatusControllerProvider);
    final status = state.status;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const CitizenSectionHeader(
          title: 'My Case Status',
          subtitle:
              'Enter your FIR number to see the status your lawyer has shared.',
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _fir,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(hintText: 'e.g. FIR0009'),
                onSubmitted: (_) => _check(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              height: AppSizes.controlHeight,
              child: FilledButton(
                onPressed: state.busy ? null : _check,
                child: state.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('Check'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (status != null) _Result(status: status),
        if (state.error != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              state.error!,
              style: const TextStyle(color: Color(0xFF92400E)),
            ),
          ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.status});

  final CaseClientStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updated = formatRelativeTime(status.clientNoteUpdatedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                status.firNo,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ),
            CitizenStatusPill(status.statusLabel),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CitizenFieldLabel('Next Hearing'),
              const SizedBox(height: 2),
              Text(status.hearingLabel),
            ],
          ),
        ),
        // Only when the lawyer wrote one (lines 1096-1103).
        if (status.hasNote) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'NOTE FROM YOUR LAWYER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                    if (updated.isNotEmpty)
                      Text(
                        updated,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  status.clientNote,
                  style: const TextStyle(color: Color(0xFF1E40AF)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
