import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../dashboard/presentation/widgets/dashboard_cards.dart';
import '../../domain/entities/judge_content.dart';
import '../controllers/judge_providers.dart';
import 'docket_screen.dart';
import 'judge_home_screen.dart';
import 'judge_library_screen.dart';
import 'judge_workspace_screen.dart';

/// The Judge Portal — `templates/judge_dashboard.html` on a phone.
///
/// The website is one page with a hover sidebar and four sections switched in
/// place by `showPage` (JD:468-487). On a phone the sidebar is a Drawer with
/// the same entries in the same order, and the sections sit in an
/// [IndexedStack] because the page hides them rather than destroying them: a
/// chosen filter or a half-typed research question is still there on return.
///
/// Two things the page does not have:
///   - **an app bar with a sign-out.** The website's judge page has no way to
///     sign out at all (no `/logout` link anywhere in it). A phone has no
///     address bar to type `/logout` into, so the app keeps the sign-out it
///     already gave judges, with its confirmation (analysis OQ-J1).
///   - nothing else: "Orders & Drafts" is listed, and does what it does on the
///     page — nothing (JD:85-87; analysis J-23).
class JudgeShell extends ConsumerWidget {
  const JudgeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(judgeSectionProvider);
    final scheme = Theme.of(context).colorScheme;
    // `loadFirOptions()` runs once when the page loads (JD:1191); held here so
    // the hearing form's suggestions are ready and not refetched per opening.
    ref.watch(judgeFirOptionsProvider);

    const sections = [
      JudgeHomeScreen(),
      DocketScreen(),
      JudgeWorkspaceScreen(),
      JudgeLibraryScreen(),
    ];

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: const Text('NyayaAI'),
        actions: [
          IconButton(
            onPressed: () => confirmSignOut(context, ref),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      drawer: _JudgeDrawer(current: section),
      body: IndexedStack(
        index: section.index,
        children: [
          for (var i = 0; i < sections.length; i++)
            TickerMode(enabled: i == section.index, child: sections[i]),
        ],
      ),
    );
  }
}

class _JudgeDrawer extends ConsumerWidget {
  const _JudgeDrawer({required this.current});

  final JudgeSection current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ListTile tile({
      required IconData icon,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) =>
        ListTile(
          selected: selected,
          selectedTileColor: Colors.white.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          leading: Icon(icon, color: Colors.white),
          title: Text(label, style: const TextStyle(color: Colors.white)),
          onTap: onTap,
        );

    return Drawer(
      backgroundColor: AppColors.navy,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xxl,
                AppSpacing.xxl,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.balance_rounded, color: Colors.white),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'NyayaAI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    JudgeContent.portalLabel,
                    style:
                        TextStyle(color: AppColors.onNavyMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  for (final section in JudgeSection.values)
                    tile(
                      icon: section.icon,
                      label: section.label,
                      selected: section == current,
                      onTap: () {
                        Navigator.of(context).pop();
                        showJudgeSection(ref, section);
                      },
                    ),
                  // `<a href="#">` with no id and no listener (JD:85-87): the
                  // link goes nowhere and no section changes. The drawer simply
                  // closes, which is all a tap on it does on the page.
                  tile(
                    icon: Icons.description_outlined,
                    label: 'Orders & Drafts',
                    selected: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            const ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF2563EB),
                child: Text(
                  JudgeContent.avatarInitial,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              title: Text(
                JudgeContent.displayName,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
