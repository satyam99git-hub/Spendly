import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../../complaints/domain/entities/complaint_status.dart';
import '../../../complaints/presentation/controllers/complaint_providers.dart';
import '../../../complaints/presentation/screens/complaints_inbox_screen.dart';
import '../../../evidence/presentation/controllers/evidence_lock_controller.dart';
import '../../../evidence/presentation/screens/evidence_locker_screen.dart';
import '../widgets/dashboard_cards.dart';

/// The police console.
///
/// ---------------------------------------------------------------------------
/// WHY TABS AND NOT A LIST OF LINKS
///
/// The three things an officer does on this app are registering an FIR, working
/// the complaints that come in, and filing what belongs to a case. They are not
/// steps in a sequence and none is subordinate to the others — a complaint
/// arrives days before anyone decides whether it is an FIR, evidence arrives days
/// after the FIR, and an officer at a counter switches between them several
/// times an hour. A menu screen would put a push-and-pop between every switch,
/// and would relock nothing while doing it.
///
/// So they are three surfaces at the same level, held side by side, with the
/// state of each preserved while the others are on screen. Which is why the body
/// is an [IndexedStack] rather than a rebuild: the complaints inbox would
/// otherwise forget both its search box and the filters an officer was triaging
/// under, and the FIR tab would lose its scroll position on every switch.
///
/// The evidence locker is the deliberate exception — it is relocked on the way
/// out of its tab, so the PIN is asked every time it is opened. See [_selectTab].
/// ---------------------------------------------------------------------------
class PoliceDashboardScreen extends ConsumerStatefulWidget {
  const PoliceDashboardScreen({super.key, required this.user});

  final AuthUser user;

  @override
  ConsumerState<PoliceDashboardScreen> createState() =>
      _PoliceDashboardScreenState();
}

class _PoliceDashboardScreenState extends ConsumerState<PoliceDashboardScreen> {
  /// Index into both the [IndexedStack] and the [NavigationBar] below — they are
  /// two views of the same list, so their order is not free to differ.
  static const _firTab = 0;
  static const _evidenceTab = 2;

  int _tab = _firTab;

  /// Switches tabs, and relocks the evidence locker on the way out of it.
  ///
  /// ---------------------------------------------------------------------------
  /// WHY LEAVING THE TAB CLOSES THE LOCKER
  ///
  /// The gate exists to stop a phone left on a desk from showing a complainant's
  /// evidence to whoever picks it up. A locker that stays open for the rest of
  /// the session does not do that: an officer unlocks it once at the start of a
  /// shift, works the FIR tab for an hour, hands the handset to a colleague, and
  /// the evidence is one tap away with no PIN in between.
  ///
  /// So the PIN is asked every time the tab is opened. It costs the officer a
  /// few seconds each visit, and that is the whole of what the gate buys —
  /// there is no session check on any evidence endpoint server-side, so a curtain
  /// that is usually open is not a curtain at all.
  ///
  /// Relocked here rather than inside the locker screen because the locker is in
  /// an [IndexedStack]: its widget is never disposed when another tab is shown,
  /// so it has no lifecycle callback that fires on leaving. The shell is what
  /// knows the tab changed.
  void _selectTab(int index) {
    if (index == _tab) return;

    if (_tab == _evidenceTab) {
      ref.read(evidenceLockControllerProvider.notifier).lock();
    }
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onEvidence = _tab == _evidenceTab;
    final lockerOpen =
        ref.watch(evidenceLockControllerProvider.select((s) => s.unlocked));

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text('NyayaAI'),
        actions: [
          // Only on the tab it acts on, and only when there is something to
          // close. A padlock that is always visible and usually does nothing is
          // a padlock nobody reads.
          if (onEvidence && lockerOpen)
            IconButton(
              onPressed:
                  ref.read(evidenceLockControllerProvider.notifier).lock,
              icon: const Icon(Icons.lock_outline_rounded),
              tooltip: 'Lock the evidence locker',
            ),
          IconButton(
            onPressed: () => confirmSignOut(context, ref),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _FirTab(user: widget.user),
          const ComplaintsInboxScreen(),
          const EvidenceLockerScreen(),
          const _LawTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        // Complaints sits between the two, and the order is the order of the
        // work: a complaint arrives, it may become an FIR, and evidence is filed
        // against that FIR afterwards. FIR keeps the first slot because filing
        // one at a counter is still what an officer opens this app to do.
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'FIR',
          ),
          NavigationDestination(
            // The count of complaints nobody has picked up yet, on the tab
            // itself. The website carries the same number on its sidebar, and
            // it is the one thing on this console that arrives without anybody
            // asking: an officer who has to open the tab to find out whether
            // there is work in it is an officer who opens it out of habit and
            // then stops.
            icon: _PendingBadge(child: Icon(Icons.inbox_outlined)),
            selectedIcon: _PendingBadge(child: Icon(Icons.inbox_rounded)),
            label: 'Complaints',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline_rounded),
            selectedIcon: Icon(Icons.lock_rounded),
            label: 'Evidence',
          ),
          // Last, because it is the only one that is not case work. An officer
          // opens the other three to do something to a record; they open this
          // one to look something up.
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Law',
          ),
        ],
      ),
    );
  }
}

/// The FIR tab: who you are, the one thing you can do, and what is coming.
class _FirTab extends StatelessWidget {
  const _FirTab({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        IdentityCard(
          name: user.displayName,
          email: user.email,
          role: user.role,
          uniqueId: user.uniqueId,
        ),
        const SizedBox(height: AppSpacing.xxl),
        ActionCard(
          icon: Icons.note_add_outlined,
          title: 'File an FIR',
          subtitle: 'FORM IF-1, four steps, with a review before it is filed',
          onTap: () => context.pushNamed(AppRoutes.firNewName),
        ),
        const SizedBox(height: AppSpacing.md),
        // Second, not first. Filing is what an officer opens this app to do at a
        // counter; looking a record up is what they do afterwards.
        ActionCard(
          icon: Icons.folder_open_outlined,
          title: 'FIR history',
          subtitle: 'Search past FIRs, read one, download its PDF',
          onTap: () => context.pushNamed(AppRoutes.firHistoryName),
        ),
        const SizedBox(height: AppSpacing.md),
        // A pushed route rather than a fifth tab. Registering a missing person
        // and reviewing the sightings that come back is something an officer
        // goes and does and comes back from, like FIR history — not something
        // they switch between while working a counter.
        ActionCard(
          icon: Icons.person_search_outlined,
          title: 'Missing persons',
          subtitle: 'Register a case, review sightings and face matches',
          onTap: () => context.pushNamed(AppRoutes.missingPersonsName),
        ),
      ],
    );
  }
}

/// The Law tab: the library and the two things built on top of it.
///
/// Three cards rather than three tabs. They are all "look something up", they
/// are not switched between mid-task the way the FIR, complaints and evidence
/// surfaces are, and a bottom bar with six destinations is a bottom bar nobody
/// reads.
class _LawTab extends StatelessWidget {
  const _LawTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const SectionHeading('THE LAW'),
        const SizedBox(height: AppSpacing.md),
        ActionCard(
          icon: Icons.menu_book_outlined,
          title: 'Law library',
          subtitle: 'Browse and search all eight acts, section by section',
          onTap: () => context.pushNamed(AppRoutes.lawLibraryName),
        ),
        const SizedBox(height: AppSpacing.md),
        ActionCard(
          icon: Icons.auto_awesome_outlined,
          title: 'Ask NyayaAI',
          subtitle: 'A legal question in plain words, answered from the acts',
          onTap: () => context.pushNamed(AppRoutes.lawAskName),
        ),
        const SizedBox(height: AppSpacing.md),
        ActionCard(
          icon: Icons.balance_rounded,
          title: 'Which sections apply',
          subtitle: 'Describe an incident and see the sections it matches',
          onTap: () => context.pushNamed(AppRoutes.lawOutcomeName),
        ),
        const SizedBox(height: AppSpacing.md),
        ActionCard(
          icon: Icons.translate_rounded,
          title: 'Terms and the new codes',
          subtitle: 'What a word means, and what the BNS renumbered it to',
          onTap: () => context.pushNamed(AppRoutes.lawReferenceName),
        ),
      ],
    );
  }
}

/// Puts the pending-complaint count on the Complaints tab icon.
///
/// Reads whatever the inbox has already fetched — `complaintsProvider` is not
/// `autoDispose`, so on any tab but the first this is a value already in memory
/// and costs nothing. **It does not fetch.** A badge that pulled the whole
/// complaints table on every cold start, on a tab the officer may not open,
/// would be a request nobody asked for; the number appears once the inbox has
/// been looked at, and is refreshed by the same pull-to-refresh.
///
/// Renders the bare icon while the list is loading or failed. A badge is an
/// invitation, and an invitation the app is not sure about is better left unsaid
/// than shown as a zero.
class _PendingBadge extends ConsumerWidget {
  const _PendingBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref
        .watch(complaintsProvider)
        .valueOrNull
        ?.where((c) => c.status == ComplaintStatus.pending)
        .length;

    if (pending == null || pending == 0) return child;

    return Badge.count(
      count: pending,
      backgroundColor: Theme.of(context).colorScheme.error,
      child: child,
    );
  }
}
