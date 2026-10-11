import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../theme/app_dimensions.dart';
import '../../data/models/lawyer_models.dart';
import '../controllers/lawyer_providers.dart';
import '../widgets/lawyer_widgets.dart';

/// My Cases — lawyer_dashboard.html `<section id="my-cases">` (lines 396-463).
class MyCasesScreen extends ConsumerStatefulWidget {
  const MyCasesScreen({super.key});

  @override
  ConsumerState<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends ConsumerState<MyCasesScreen> {
  final _search = TextEditingController();
  final _claim = TextEditingController();
  final _claimFocus = FocusNode();

  bool _adding = false;
  LawyerMessage? _claimMessage;
  Timer? _reload;

  @override
  void dispose() {
    _reload?.cancel();
    _search.dispose();
    _claim.dispose();
    _claimFocus.dispose();
    super.dispose();
  }

  /// `claimCase()` (lines 1478-1511).
  Future<void> _claimCase() async {
    final firNo = _claim.text.trim();
    if (firNo.isEmpty) {
      setState(
        () => _claimMessage = LawyerMessage.error('Enter an FIR number.'),
      );
      return;
    }
    if (_adding) return;

    setState(() => _adding = true);
    try {
      await ref.read(lawyerRepositoryProvider).claim(firNo);
      if (!mounted) return;
      setState(
        () => _claimMessage = LawyerMessage.ok('Case added. Refreshing…'),
      );
      // `setTimeout(() => window.location.reload(), 700)`.
      _reload = Timer(const Duration(milliseconds: 700), () {
        if (mounted) reloadLawyerPortal(ref);
      });
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _claimMessage = LawyerMessage.error(failure.message));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _claimMessage =
            LawyerMessage.error('Something went wrong. Please try again.'),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Home's "Add a Case" lands here and focuses the box (line 356).
    ref.listen<int>(claimFocusRequestProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _claimFocus.requestFocus();
      });
    });

    final cases = ref.watch(lawyerCasesProvider);
    final query = _search.text.trim().toLowerCase();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const LawyerHeading('My Cases'),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search FIR no., client name…',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        LawyerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ADD A CASE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: LawyerColors.slate400,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _claim,
                focusNode: _claimFocus,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _claimCase(),
                decoration: const InputDecoration(
                  hintText: 'Enter FIR number (e.g. FIR0008)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _adding ? null : _claimCase,
                child: Text(_adding ? 'Adding…' : 'Add Case'),
              ),
              if (_claimMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                LawyerMessageText(_claimMessage),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        LawyerStatGrid(
          stats: cases.whenOrNull(data: LawyerCaseStats.of),
        ),
        const SizedBox(height: AppSpacing.xxl),
        ...cases.when(
          loading: () => const [LawyerLoading()],
          // The website cannot be in this state — its list arrives inside the
          // page — so this is the app's own: the server's reason, and a retry.
          error: (error, _) => [
            StateMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your cases',
              body: error is Failure
                  ? error.message
                  : const NetworkFailure().message,
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: OutlinedButton(
                onPressed: () => ref.invalidate(lawyerCasesProvider),
                child: const Text('Retry'),
              ),
            ),
          ],
          data: (list) {
            if (list.isEmpty) {
              return const [
                LawyerEmptyText(
                  'No cases yet. Add one above using an FIR number.',
                ),
              ];
            }
            return [
              for (final c in list)
                if (query.isEmpty || c.searchText.contains(query))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: CaseCard(lawyerCase: c),
                  ),
            ];
          },
        ),
      ],
    );
  }
}

/// A case card (lines 439-454). Tapping it opens the workspace.
class CaseCard extends ConsumerWidget {
  const CaseCard({super.key, required this.lawyerCase});

  final LawyerCase lawyerCase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = lawyerCase;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LawyerCard(
      onTap: () => openCaseWorkspace(ref, c.firNo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A Wrap, not the page's justify-between row: on a narrow phone a
          // long FIR number and "Court Proceedings" do not fit side by side,
          // and the pill moves under the number instead of overflowing.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                'FIR: ${c.jinja('fir_no')}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: dark ? LawyerColors.blue100 : LawyerColors.blue900,
                ),
              ),
              LawyerStatusPill(c.statusLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Client: ${c.jinja('complainant_name')}'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sections: ${c.jinja('act_sections')}',
            style: const TextStyle(color: LawyerColors.slate500),
          ),
          const Divider(height: AppSpacing.xxl),
          Row(
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                size: 14,
                color: LawyerColors.slate400,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Next Hearing: ${c.nextHearingLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: LawyerColors.slate400,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
