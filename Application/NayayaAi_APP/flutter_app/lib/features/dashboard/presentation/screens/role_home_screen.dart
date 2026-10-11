import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/user_role.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../citizen/presentation/screens/citizen_shell.dart';
import '../../../judge/presentation/screens/judge_shell.dart';
import '../../../lawyer/presentation/screens/lawyer_shell.dart';
import '../widgets/dashboard_cards.dart';
import 'police_dashboard_screen.dart';

/// Where every role lands after signing in.
///
/// One route, `/home`, branching on the signed-in role — so a role change does
/// not orphan a deep link, and no screen below has to check for a session.
///
/// Police and admin get the tabbed console ([PoliceDashboardScreen]); citizens
/// get the Citizen Portal ([CitizenShell]), the website's
/// `/citizen-dashboard` rebuilt natively; lawyers get the Lawyer Portal
/// ([LawyerShell]), the website's `/lawyer_dashboard`; judges get the Judge
/// Portal ([JudgeShell]), the website's `/judge-dashboard`. No role lands on
/// the list below any more; it stays as the fallback a new role would reach,
/// naming what is planned without pretending any of it exists:
///
///   - **Built** — an [ActionCard] that actually navigates.
///   - **Planned** — a plain, non-interactive list. A tappable card that opens
///     an empty page is worse than an honest list.
///
/// Each planned item becomes an action card as its feature lands (see
/// docs/FEATURE_INVENTORY.md), at which point that role gets a console of its
/// own too.
class RoleHomeScreen extends ConsumerWidget {
  const RoleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider.select((s) => s.user));

    // The router guarantees a session before this route is reachable, so a null
    // user here means the redirect is mid-flight during sign-out. Render a
    // holding state rather than throwing on the frame before we are replaced.
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user.role.hasPoliceAccess) {
      return PoliceDashboardScreen(user: user);
    }

    if (user.role == UserRole.citizen) {
      return const CitizenShell();
    }

    if (user.role == UserRole.lawyer) {
      return const LawyerShell();
    }

    if (user.role == UserRole.judge) {
      return const JudgeShell();
    }

    return _RoleHomeList(user: user);
  }
}

class _RoleHomeList extends ConsumerWidget {
  const _RoleHomeList({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
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
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            sliver: SliverList.list(
              children: [
                IdentityCard(
                  name: user.displayName,
                  email: user.email,
                  role: user.role,
                  uniqueId: user.uniqueId,
                ),
                const SizedBox(height: AppSpacing.xxxl),
                const SectionHeading('COMING NEXT'),
                const SizedBox(height: AppSpacing.md),
                ..._plannedFor(user.role)
                    .map((f) => PlannedFeatureTile(feature: f)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PlannedFeature> _plannedFor(UserRole role) {
    switch (role) {
      // Unreachable: police and admin go to PoliceDashboardScreen above,
      // citizens to CitizenShell, lawyers to LawyerShell and judges to
      // JudgeShell. Listed so that a new role added to the enum breaks this
      // switch rather than silently landing on an empty roadmap.
      case UserRole.judge:
      case UserRole.citizen:
      case UserRole.lawyer:
      case UserRole.police:
      case UserRole.admin:
        return const [];
    }
  }
}
