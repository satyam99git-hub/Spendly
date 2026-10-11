import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_dimensions.dart';
import '../../data/models/lawyer_models.dart';
import '../../domain/entities/lawyer_content.dart';
import '../controllers/lawyer_providers.dart';
import '../widgets/lawyer_widgets.dart';
import 'lawyer_shell.dart';

/// Home — lawyer_dashboard.html `<section id="home">` (lines 287-393).
class LawyerHomeScreen extends ConsumerWidget {
  const LawyerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(lawyerCasesProvider);
    final stats = cases.whenOrNull(data: LawyerCaseStats.of);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Hero(name: lawyerDisplayName(ref)),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LawyerStatGrid(stats: stats),
              const SizedBox(height: AppSpacing.xxxl),
              const _QuickActions(),
              const SizedBox(height: AppSpacing.xxxl),
              _UpcomingHearings(stats: stats, failed: cases.hasError),
              const SizedBox(height: AppSpacing.xxl),
              const _UpcomingDeadlines(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.name});

  final String name;

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
              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: Color(0xFFBFDBFE),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Powered by NyayaAI · Lawyer Portal',
                    style: TextStyle(
                      color: Color(0xFFBFDBFE),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text.rich(
            TextSpan(
              text: 'Welcome back, ',
              children: [
                TextSpan(
                  text: '$name.',
                  style: const TextStyle(color: Color(0xFF93C5FD)),
                ),
              ],
            ),
            style: const TextStyle(
              fontFamily: 'serif',
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            LawyerContent.heroSubtitle,
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
              foregroundColor: LawyerColors.blue700,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => showLawyerSection(ref, LawyerSection.myCases),
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text('View My Cases'),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      (
        Icons.folder_open_outlined,
        LawyerColors.blue100,
        LawyerColors.blue600,
        'View My Cases',
        () => showLawyerSection(ref, LawyerSection.myCases),
      ),
      (
        Icons.add_circle_outline_rounded,
        LawyerColors.green100,
        LawyerColors.green600,
        'Add a Case',
        () {
          showLawyerSection(ref, LawyerSection.myCases);
          ref.read(claimFocusRequestProvider.notifier).state++;
        },
      ),
      (
        Icons.gavel_rounded,
        LawyerColors.purple100,
        LawyerColors.purple600,
        'Legal Assistant',
        () => showLawyerSection(ref, LawyerSection.legalAssistant),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StripTitle(
          icon: Icons.bolt_rounded,
          iconColor: LawyerColors.blue600,
          title: 'Quick Actions',
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - AppSpacing.md) / 2;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final (icon, tint, color, label, onTap) in actions)
                  SizedBox(
                    width: width,
                    child: LawyerCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      onTap: onTap,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: tint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 20, color: color),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StripTitle extends StatelessWidget {
  const _StripTitle({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: titleColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Upcoming Hearings" (lines 371-380, 1459-1470): each case whose next
/// hearing falls in the coming week, soonest first. Not tappable.
class _UpcomingHearings extends StatelessWidget {
  const _UpcomingHearings({required this.stats, required this.failed});

  final LawyerCaseStats? stats;

  /// The cases could not be loaded. The website cannot get here — its cases
  /// arrive inside the page — so this says what My Cases says, and My Cases
  /// offers the retry.
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LawyerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StripTitle(
            icon: Icons.notifications_none_rounded,
            iconColor: LawyerColors.blue600,
            title: 'Upcoming Hearings',
            titleColor: dark ? LawyerColors.blue100 : LawyerColors.blue900,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (s == null && failed)
            const LawyerEmptyText('Could not load your cases.', center: false)
          else if (s == null)
            const LawyerLoading()
          else if (s.upcomingHearings.isEmpty)
            const LawyerEmptyText(
              'No upcoming hearings scheduled.',
              center: false,
            )
          else
            for (final h in s.upcomingHearings)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: LawyerRow(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'FIR: ${h.firNo}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        h.date,
                        style: const TextStyle(color: LawyerColors.slate500),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// "Upcoming Deadlines" (lines 382-390, `loadHomeDeadlines` 1168-1205).
class _UpcomingDeadlines extends ConsumerWidget {
  const _UpcomingDeadlines();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deadlines = ref.watch(lawyerUpcomingDeadlinesProvider);
    final today = jsTodayUtc();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return LawyerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StripTitle(
            icon: Icons.warning_amber_rounded,
            iconColor: LawyerColors.red600,
            title: 'Upcoming Deadlines',
            titleColor: dark ? LawyerColors.red200 : const Color(0xFF7F1D1D),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...deadlines.when(
            loading: () => const [
              Text('Loading…', style: TextStyle(color: LawyerColors.slate400)),
            ],
            error: (_, __) => const [
              LawyerEmptyText('Could not load deadlines.', center: false),
            ],
            data: (list) => list.isEmpty
                ? const [
                    LawyerEmptyText(
                      'No deadlines due in the next 14 days.',
                      center: false,
                    ),
                  ]
                : [
                    for (final d in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _HomeDeadlineRow(
                          deadline: d,
                          overdue: d.isPastDue(today),
                        ),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _HomeDeadlineRow extends ConsumerWidget {
  const _HomeDeadlineRow({required this.deadline, required this.overdue});

  final CaseDeadline deadline;
  final bool overdue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LawyerRow(
      color: overdue && !dark ? LawyerColors.red50 : null,
      borderColor: overdue ? LawyerColors.red200 : null,
      onTap: () => openCaseWorkspace(ref, deadline.firNo),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'FIR: ${deadline.firNo}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: dark ? LawyerColors.blue100 : LawyerColors.blue900,
                    ),
                  ),
                  TextSpan(
                    text: '  ${deadline.deadlineType}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: overdue ? LawyerColors.red700 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Flexible: on a phone the date and " — OVERDUE" together can be
          // wider than what the FIR and type leave.
          Flexible(
            child: Text(
              '${deadline.dueDate}${overdue ? ' — OVERDUE' : ''}',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: overdue ? LawyerColors.red600 : LawyerColors.slate500,
                fontWeight: overdue ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
