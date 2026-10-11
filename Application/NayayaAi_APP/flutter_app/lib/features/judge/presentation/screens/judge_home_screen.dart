import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../lawyer/presentation/widgets/lawyer_widgets.dart';
import '../../data/models/judge_models.dart';
import '../../domain/entities/judge_content.dart';
import '../controllers/judge_providers.dart';
import '../widgets/judge_widgets.dart';

/// Home — judge_dashboard.html `<section id="home-page">` (JD:102-192).
///
/// The stats and the upcoming list come from the same reply as the Docket
/// table, filters included, because the page fills all three from one
/// `loadDocket()` (JD:589-593).
class JudgeHomeScreen extends ConsumerWidget {
  const JudgeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docket = ref.watch(judgeDocketProvider);
    final entries = docket.valueOrNull;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _Hero(),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Stats(stats: entries == null ? null : DocketStats.of(entries)),
              const SizedBox(height: AppSpacing.xxxl),
              const _SectionTitle(Icons.bolt_rounded, 'Quick Actions'),
              const SizedBox(height: AppSpacing.md),
              const _QuickActions(),
              const SizedBox(height: AppSpacing.xxxl),
              const _SectionTitle(
                Icons.schedule_rounded,
                JudgeContent.upcomingHeading,
              ),
              const SizedBox(height: AppSpacing.md),
              LawyerCard(
                padding: EdgeInsets.zero,
                child: docket.when(
                  // The page's initial "Loading…" (JD:188).
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: LawyerEmptyText('Loading…'),
                  ),
                  error: (e, _) => JudgeErrorView(
                    error: e,
                    onRetry: () => refreshDocket(ref),
                  ),
                  data: (list) => _UpcomingList(upcomingHearings(list)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Color(0xFFDBEAFE)),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    JudgeContent.heroBadge,
                    style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text.rich(
            TextSpan(
              text: 'Welcome back, ',
              children: [
                TextSpan(
                  text: JudgeContent.displayName,
                  style: TextStyle(color: Color(0xFF93C5FD)),
                ),
                TextSpan(text: '.'),
              ],
            ),
            style: TextStyle(
              fontFamily: 'serif',
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            JudgeContent.heroSubtitle,
            style: TextStyle(
              color: Color(0xFFDBEAFE),
              fontSize: 16,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: LawyerColors.blue900,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => showJudgeSection(ref, JudgeSection.docket),
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text(JudgeContent.viewDocket),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  /// Null until the docket has loaded; the page shows `0` until then.
  final DocketStats? stats;

  @override
  Widget build(BuildContext context) {
    String n(int Function(DocketStats) pick) {
      final s = stats;
      return s == null ? '0' : '${pick(s)}';
    }

    final cards = [
      LawyerStatCard(
        value: n((s) => s.total),
        label: 'Total Hearings',
        color: LawyerColors.blue900,
      ),
      LawyerStatCard(
        value: n((s) => s.urgent),
        label: 'Urgent',
        color: const Color(0xFFF97316),
      ),
      LawyerStatCard(
        value: n((s) => s.scheduled),
        label: 'Scheduled',
        color: LawyerColors.blue600,
      ),
      LawyerStatCard(
        value: n((s) => s.thisWeek),
        label: 'Hearings This Week',
        color: LawyerColors.green600,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: LawyerColors.blue600),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? LawyerColors.blue100
                    : LawyerColors.blue900,
              ),
            ),
          ),
        ],
      );
}

/// The three quick-action cards (JD:148-179).
class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget action(
      IconData icon,
      Color tint,
      String title,
      String subtitle,
      VoidCallback onTap,
    ) =>
        LawyerCard(
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: LawyerColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        action(
          Icons.folder_open_outlined,
          LawyerColors.blue600,
          'View Docket',
          'See all scheduled hearings',
          () => showJudgeSection(ref, JudgeSection.docket),
        ),
        const SizedBox(height: AppSpacing.md),
        action(
          Icons.add_circle_outline,
          LawyerColors.green600,
          'Add a Hearing',
          'Schedule a new case hearing',
          () {
            // `showPage('docket'); setTimeout(() => addEntryBtn.click(), 50)`
            showJudgeSection(ref, JudgeSection.docket);
            ref.read(newHearingRequestProvider.notifier).state++;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        action(
          Icons.gavel_rounded,
          LawyerColors.purple600,
          'Law Library',
          'Browse acts & research precedents',
          () => showJudgeSection(ref, JudgeSection.library),
        ),
      ],
    );
  }
}

/// `renderUpcomingHearings` (JD:596-621): not tappable.
class _UpcomingList extends StatelessWidget {
  const _UpcomingList(this.entries);

  final List<DocketEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const LawyerEmptyText(JudgeContent.upcomingEmpty);
    }
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entries[i].caseId,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: LawyerColors.blue700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        jsOrText(entries[i].raw['case_type'], 'General'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: LawyerColors.slate400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entries[i].hearingDate,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    JudgePill(entries[i].urgency),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
