import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../controllers/lawyer_providers.dart';
import 'all_drafts_screen.dart';
import 'case_workspace_screen.dart';
import 'lawyer_home_screen.dart';
import 'lawyer_profile_dialog.dart';
import 'legal_assistant_screen.dart';
import 'my_cases_screen.dart';

/// The Lawyer Portal — `templates/lawyer_dashboard.html` on a phone.
///
/// The website is one page with a sidebar of five sections switched in place
/// by `showSection`; on a phone that sidebar is a slide-in menu behind a menu
/// button (lines 107-115, 267-269, 1398-1410). A Drawer is that menu, with the
/// same five entries in the same order and the lawyer's avatar and name at the
/// foot, which open the profile (lines 253-264).
///
/// The sections sit in an [IndexedStack] because on the website they are
/// hidden, not destroyed: a typed question, a generated draft and the open
/// case are still there when the lawyer comes back. Only a reload clears them
/// — the page reloads itself after a case is claimed ([reloadLawyerPortal]).
class LawyerShell extends ConsumerWidget {
  const LawyerShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(lawyerSectionProvider);
    final generation = ref.watch(lawyerPortalGenerationProvider);
    final scheme = Theme.of(context).colorScheme;
    // Held here so the avatar the profile modal sets outlives the drawer,
    // which is closed while the modal is open.
    ref.watch(lawyerAvatarProvider);

    const sections = [
      LawyerHomeScreen(),
      MyCasesScreen(),
      CaseWorkspaceScreen(),
      LegalAssistantScreen(),
      AllDraftsScreen(),
    ];

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text('NyayaAI', overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Lawyer',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _signOut(ref),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      drawer: _LawyerDrawer(current: section),
      body: KeyedSubtree(
        // A new generation is a reloaded page: every section's typed text,
        // answers and messages start over.
        key: ValueKey(generation),
        child: IndexedStack(
          index: section.index,
          children: [
            for (var i = 0; i < sections.length; i++)
              TickerMode(enabled: i == section.index, child: sections[i]),
          ],
        ),
      ),
    );
  }
}

/// The page's "Sign out" is a link to `/logout` (line 281) — no question.
Future<void> _signOut(WidgetRef ref) =>
    ref.read(authControllerProvider.notifier).logout();

/// The name the page greets the lawyer with: `session['fullname']`, which the
/// server fills from the account, defaulting to "Advocate" (app.py:1087,
/// 2094).
String lawyerDisplayName(WidgetRef ref) {
  final fromServer = ref.watch(lawyerFullNameProvider).valueOrNull;
  if (fromServer != null && fromServer.isNotEmpty) return fromServer;
  final cached = ref.watch(
    authControllerProvider.select((s) => s.user?.fullName?.trim() ?? ''),
  );
  return cached.isNotEmpty ? cached : 'Advocate';
}

class _LawyerDrawer extends ConsumerWidget {
  const _LawyerDrawer({required this.current});

  final LawyerSection current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = lawyerDisplayName(ref);
    final avatar = ref.watch(lawyerAvatarProvider);

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
                    'Lawyer Portal',
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
                  for (final section in LawyerSection.values)
                    ListTile(
                      selected: section == current,
                      selectedTileColor: Colors.white.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      leading: Icon(section.icon, color: Colors.white),
                      title: Text(
                        section.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        showLawyerSection(ref, section);
                      },
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: LawyerAvatarCircle(
                // `{{ lawyer.name[0] }}` until `updateAvatarDisplay` runs.
                initial: avatar?.initial ?? (name.isEmpty ? 'L' : name[0]),
                photoUrl: avatar?.photoUrl ?? '',
                size: 32,
              ),
              title: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                showLawyerProfile(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The round avatar: the photo when there is one, else a letter on blue.
class LawyerAvatarCircle extends StatelessWidget {
  const LawyerAvatarCircle({
    super.key,
    required this.initial,
    required this.photoUrl,
    required this.size,
  });

  final String initial;
  final String photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF2563EB),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl.isEmpty
          ? letter
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => letter,
            ),
    );
  }
}
