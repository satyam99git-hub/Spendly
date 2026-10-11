import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../controllers/citizen_section.dart';
import 'case_status_screen.dart';
import 'citizen_home_screen.dart';
import 'citizen_missing_persons_screen.dart';
import 'emergency_contacts_screen.dart';
import 'file_complaint_screen.dart';
import 'rights_chat_screen.dart';
import 'track_complaint_screen.dart';

/// The Citizen Portal — `templates/citizen_dashboard.html` on a phone.
///
/// ---------------------------------------------------------------------------
/// WHY A DRAWER AND AN INDEXED STACK
///
/// The website is one page with a sidebar of seven sections, switched in place
/// by `showSection`. On a phone its sidebar is already a slide-in menu behind a
/// menu button (citizen_dashboard.html:139-148, 223-225). A Drawer is that
/// menu, with the same seven entries in the same order and "Sign Out" at the
/// foot.
///
/// The sections live in an [IndexedStack] because on the website they are
/// hidden, not destroyed: a half-typed complaint, the last tracked result and
/// the whole rights conversation are still there when the citizen comes back
/// to them. Only a reload clears them — here, signing out.
/// ---------------------------------------------------------------------------
class CitizenShell extends ConsumerWidget {
  const CitizenShell({super.key});

  static const _sections = [
    CitizenHomeScreen(),
    FileComplaintScreen(),
    TrackComplaintScreen(),
    CaseStatusScreen(),
    RightsChatScreen(),
    CitizenMissingPersonsScreen(),
    EmergencyContactsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(citizenSectionProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        // Flexible, because at a large text scale the title and the badge
        // together are wider than the bar.
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
                  'Citizen',
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
      drawer: _CitizenDrawer(current: section),
      body: IndexedStack(
        index: section.index,
        children: [
          // A hidden section keeps its state but not its animations — a
          // spinner behind the visible section has nothing to show anyone.
          for (var i = 0; i < _sections.length; i++)
            TickerMode(enabled: i == section.index, child: _sections[i]),
        ],
      ),
    );
  }
}

/// The website's "Sign Out" is a link to `/logout` — no question asked. The
/// project owner kept that for citizens (decision D-4a); the police console
/// keeps its own confirmation.
Future<void> _signOut(WidgetRef ref) =>
    ref.read(authControllerProvider.notifier).logout();

class _CitizenDrawer extends ConsumerWidget {
  const _CitizenDrawer({required this.current});

  final CitizenSection current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    'Citizen Portal',
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
                  for (final section in CitizenSection.values)
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
                        showCitizenSection(ref, section);
                      },
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: AppColors.onNavyMuted,
              ),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.onNavyMuted),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _signOut(ref);
              },
            ),
          ],
        ),
      ),
    );
  }
}
