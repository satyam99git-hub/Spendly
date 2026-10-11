import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/lawyer_remote_data_source.dart';
import '../../data/models/lawyer_models.dart';
import '../../data/repositories/lawyer_repository_impl.dart';
import '../../domain/repositories/lawyer_repository.dart';

final lawyerRepositoryProvider = Provider<LawyerRepository>(
  (ref) => LawyerRepositoryImpl(
    remote: LawyerRemoteDataSource(ref.watch(dioClientProvider).dio),
  ),
);

// ---- sections ---------------------------------------------------------------

/// The page's five sidebar sections, in its order and with its labels
/// (lawyer_dashboard.html:225-251).
enum LawyerSection {
  home('Home', Icons.dashboard_outlined),
  myCases('My Cases', Icons.folder_open_outlined),
  caseWorkspace('Case Workspace', Icons.work_outline_rounded),
  legalAssistant('Legal Assistant', Icons.gavel_rounded),
  drafts('Drafts', Icons.description_outlined);

  const LawyerSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The page opens on Home (`showSection('home')`, line 1412).
final lawyerSectionProvider = StateProvider.autoDispose<LawyerSection>(
  (ref) => LawyerSection.home,
);

/// `showSection(id)` (lines 1374-1386): switches in place, and reloads the
/// global drafts every time Drafts is shown.
void showLawyerSection(WidgetRef ref, LawyerSection section) {
  if (section == LawyerSection.drafts) ref.invalidate(lawyerAllDraftsProvider);
  ref.read(lawyerSectionProvider.notifier).state = section;
}

// ---- the case workspace ------------------------------------------------------

/// Which case the workspace shows. [openId] changes on every
/// `openCaseWorkspace`, even for the same FIR, because the page resets the
/// workspace and reloads every tab each time (lines 841-859).
class WorkspaceTarget {
  const WorkspaceTarget(this.firNo, this.openId);

  final String firNo;
  final int openId;
}

final workspaceTargetProvider =
    StateProvider.autoDispose<WorkspaceTarget?>((ref) => null);

/// `openCaseWorkspace(firNo)`.
void openCaseWorkspace(WidgetRef ref, String firNo) {
  ref
    ..invalidate(caseDetailProvider(firNo))
    ..invalidate(caseDocumentsProvider(firNo))
    ..invalidate(caseHearingsProvider(firNo))
    ..invalidate(caseDeadlinesProvider(firNo))
    ..invalidate(caseDraftsProvider(firNo));
  final previous = ref.read(workspaceTargetProvider)?.openId ?? 0;
  ref.read(workspaceTargetProvider.notifier).state =
      WorkspaceTarget(firNo, previous + 1);
  ref.read(lawyerSectionProvider.notifier).state = LawyerSection.caseWorkspace;
}

final caseDetailProvider =
    FutureProvider.autoDispose.family<LawyerCase, String>(
  (ref, firNo) => ref.watch(lawyerRepositoryProvider).caseDetail(firNo),
);

final caseDocumentsProvider =
    FutureProvider.autoDispose.family<List<CaseDocument>, String>(
  (ref, firNo) => ref.watch(lawyerRepositoryProvider).documents(firNo),
);

final caseHearingsProvider =
    FutureProvider.autoDispose.family<List<CaseHearing>, String>(
  (ref, firNo) => ref.watch(lawyerRepositoryProvider).hearings(firNo),
);

final caseDeadlinesProvider =
    FutureProvider.autoDispose.family<List<CaseDeadline>, String>(
  (ref, firNo) => ref.watch(lawyerRepositoryProvider).deadlines(firNo),
);

final caseDraftsProvider =
    FutureProvider.autoDispose.family<List<CaseDraft>, String>(
  (ref, firNo) => ref.watch(lawyerRepositoryProvider).drafts(firNo),
);

// ---- page-wide data ----------------------------------------------------------

/// The cases the page renders into My Cases, and from which Home counts its
/// stats and upcoming hearings.
final lawyerCasesProvider = FutureProvider.autoDispose<List<LawyerCase>>(
  (ref) => ref.watch(lawyerRepositoryProvider).cases(),
);

/// Home's "Upcoming Deadlines", fetched when the page loads (line 1413).
final lawyerUpcomingDeadlinesProvider =
    FutureProvider.autoDispose<List<CaseDeadline>>(
  (ref) => ref.watch(lawyerRepositoryProvider).upcomingDeadlines(),
);

/// The Drafts section's list.
final lawyerAllDraftsProvider = FutureProvider.autoDispose<List<CaseDraft>>(
  (ref) => ref.watch(lawyerRepositoryProvider).allDrafts(),
);

/// The account's `fullname`, which the page takes from the session the
/// sign-in created (`session['fullname']`, app.py:2094). A sign-in on the app
/// does not return it, so it is read from the profile route instead. Null
/// when that fails; the screens then fall back as the server does.
final lawyerFullNameProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    final profile = await ref.watch(lawyerRepositoryProvider).profile();
    final name = profile?.fullname ?? '';
    return name.isEmpty ? null : name;
  } catch (_) {
    return null;
  }
});

/// What the sidebar avatar shows once `updateAvatarDisplay` has run — which on
/// the website happens only when the profile modal loads or a photo is
/// uploaded (lines 1627, 1670). Until then the avatar is the name's first
/// letter, as the page renders it.
class LawyerAvatar {
  const LawyerAvatar({required this.photoUrl, required this.initial});

  final String photoUrl;
  final String initial;
}

final lawyerAvatarProvider =
    StateProvider.autoDispose<LawyerAvatar?>((ref) => null);

/// "Add a Case" on Home focuses the claim box (line 356). Bumped to ask My
/// Cases to take focus.
final claimFocusRequestProvider = StateProvider.autoDispose<int>((ref) => 0);

/// Bumped by [reloadLawyerPortal] so every section starts over.
final lawyerPortalGenerationProvider =
    StateProvider.autoDispose<int>((ref) => 0);

/// `window.location.reload()` after a case is claimed (line 1504): the page
/// comes back on Home with everything fetched again and every section as it
/// was on first load.
void reloadLawyerPortal(WidgetRef ref) {
  ref
    ..invalidate(lawyerCasesProvider)
    ..invalidate(lawyerUpcomingDeadlinesProvider)
    ..invalidate(lawyerAllDraftsProvider)
    ..invalidate(lawyerFullNameProvider);
  ref.read(lawyerAvatarProvider.notifier).state = null;
  ref.read(workspaceTargetProvider.notifier).state = null;
  ref.read(lawyerSectionProvider.notifier).state = LawyerSection.home;
  ref.read(lawyerPortalGenerationProvider.notifier).state++;
}
