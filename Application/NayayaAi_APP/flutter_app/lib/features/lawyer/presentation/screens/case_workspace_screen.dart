import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../theme/app_dimensions.dart';
import '../../domain/entities/lawyer_content.dart';
import '../controllers/lawyer_providers.dart';
import '../widgets/lawyer_widgets.dart';
import '../widgets/workspace_tabs.dart';

/// Case Workspace — lawyer_dashboard.html `<section id="case-workspace">`
/// (lines 546-748).
///
/// A section of the portal, not a page of its own, exactly as on the website:
/// it is empty until a case is opened from My Cases, Home's deadlines or the
/// Drafts list, and it keeps showing that case while the lawyer visits other
/// sections.
class CaseWorkspaceScreen extends ConsumerWidget {
  const CaseWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(workspaceTargetProvider);
    if (target == null) return const _NoCaseSelected();

    // A new `openId` is a fresh `openCaseWorkspace`: the page switches back to
    // Overview and clears the summary and draft it was showing (lines
    // 848-852), so everything under here starts over.
    return KeyedSubtree(
      key: ValueKey(target.openId),
      child: _Workspace(firNo: target.firNo),
    );
  }
}

/// `#cw-empty` (lines 550-554).
class _NoCaseSelected extends ConsumerWidget {
  const _NoCaseSelected();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.work_outline_rounded,
              size: 40,
              color: LawyerColors.blue100,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Select a case from ',
                  style: TextStyle(color: LawyerColors.slate400),
                ),
                InkWell(
                  onTap: () => showLawyerSection(ref, LawyerSection.myCases),
                  child: const Text(
                    'My Cases',
                    style: TextStyle(
                      color: LawyerColors.blue600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  ' to open its workspace.',
                  style: TextStyle(color: LawyerColors.slate400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Workspace extends ConsumerStatefulWidget {
  const _Workspace({required this.firNo});

  final String firNo;

  @override
  ConsumerState<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends ConsumerState<_Workspace> {
  /// Set by a successful status change; the pill shows it from then on
  /// (lines 925-926).
  String? _statusShown;
  LawyerMessage? _statusMessage;
  Timer? _hideStatusMessage;

  @override
  void dispose() {
    _hideStatusMessage?.cancel();
    super.dispose();
  }

  /// `cwUpdateStatus()` (lines 903-937).
  Future<void> _updateStatus(String status) async {
    try {
      await ref
          .read(lawyerRepositoryProvider)
          .updateStatus(widget.firNo, status);
      if (!mounted) return;
      setState(() {
        _statusShown = status;
        _statusMessage = LawyerMessage.ok('✓ Updated');
      });
      _hideStatusMessage?.cancel();
      _hideStatusMessage = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _statusMessage = null);
      });
      // The case's card and Home's counts read the same row.
      ref.invalidate(lawyerCasesProvider);
    } on Failure catch (failure) {
      if (mounted) {
        setState(() => _statusMessage = LawyerMessage.error(failure.message));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _statusMessage = LawyerMessage.error('Something went wrong.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(caseDetailProvider(widget.firNo)).valueOrNull;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xxl,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      showLawyerSection(ref, LawyerSection.myCases),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('My Cases'),
                  style: TextButton.styleFrom(
                    foregroundColor: LawyerColors.slate500,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FIR: ${widget.firNo}',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: dark
                              ? LawyerColors.blue100
                              : LawyerColors.blue900,
                        ),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Client: ${detail.field('complainant_name')}',
                          style: const TextStyle(color: LawyerColors.slate500),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_statusShown != null || detail != null)
                            LawyerStatusPill(
                              _statusShown ?? detail!.statusLabel,
                            ),
                          _StatusSelect(onSelected: _updateStatus),
                          if (_statusMessage != null)
                            LawyerMessageText(_statusMessage, fontSize: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'AI Summary'),
              Tab(text: 'Documents'),
              Tab(text: 'Hearings'),
              Tab(text: 'Deadlines'),
              Tab(text: 'Drafts'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                OverviewTab(firNo: widget.firNo),
                SummaryTab(firNo: widget.firNo),
                DocumentsTab(firNo: widget.firNo),
                HearingsTab(firNo: widget.firNo),
                DeadlinesTab(firNo: widget.firNo),
                DraftsTab(firNo: widget.firNo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Change status…" select (lines 573-580). It always reads "Change
/// status…": the page resets it after every change.
class _StatusSelect extends StatelessWidget {
  const _StatusSelect({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final status in LawyerContent.caseStatuses)
          PopupMenuItem(value: status, child: Text(status)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 2,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Change status…',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: LawyerColors.slate600,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
