import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/enums/user_role.dart';
import '../features/authentication/presentation/controllers/auth_controller.dart';
import '../features/authentication/presentation/controllers/auth_state.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/authentication/presentation/screens/signup_screen.dart';
import '../features/citizen/presentation/screens/citizen_missing_person_detail_screen.dart';
import '../features/complaints/presentation/screens/complaint_detail_screen.dart';
import '../features/dashboard/presentation/screens/role_home_screen.dart';
import '../features/evidence/presentation/controllers/evidence_lock_controller.dart';
import '../features/evidence/presentation/screens/evidence_add_screen.dart';
import '../features/evidence/presentation/screens/evidence_detail_screen.dart';
import '../features/fir/presentation/controllers/fir_form_controller.dart';
import '../features/fir/presentation/screens/fir_form_screen.dart';
import '../features/fir/presentation/screens/fir_history_screen.dart';
import '../features/fir/presentation/screens/fir_record_screen.dart';
import '../features/fir/presentation/screens/fir_success_screen.dart';
import '../features/legal/presentation/screens/ask_law_screen.dart';
import '../features/legal/presentation/screens/law_library_screen.dart';
import '../features/legal/presentation/screens/law_outcome_screen.dart';
import '../features/legal/presentation/screens/law_reference_screen.dart';
import '../features/legal/presentation/screens/law_section_screen.dart';
import '../features/missing_persons/presentation/screens/missing_person_detail_screen.dart';
import '../features/missing_persons/presentation/screens/missing_person_form_screen.dart';
import '../features/missing_persons/presentation/screens/missing_persons_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import 'app_routes.dart';

// Re-exported so callers import one file for both the router and its paths.
export 'app_routes.dart';

/// The app's router, with the auth redirect that keeps signed-out users out of
/// role screens.
///
/// Centralising the decision here is what lets every screen below be written as
/// though its precondition already holds: [RoleHomeScreen] never has to check
/// for a session, because it is unreachable without one.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  // Signing out closes the evidence locker.
  //
  // Wired here rather than inside either feature: the locker must not import the
  // auth controller to learn it should relock, and the auth controller has no
  // business knowing a locker exists. This file is already where auth state
  // drives what the rest of the app may show, so the one cross-feature reset
  // lives with the rest of that decision.
  ref.listen<AuthState>(
    authControllerProvider,
    (previous, next) {
      if (previous?.isSignedIn == true && !next.isSignedIn) {
        ref.invalidate(evidenceLockControllerProvider);
      }
    },
  );

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      final onSplash = location == AppRoutes.splash;
      final onAuthScreen =
          location == AppRoutes.login || location == AppRoutes.signup;

      // 1. Still asking the server whether the stored cookie is good. Hold on
      //    the splash. Redirecting now would flash sign-in on every cold start
      //    of an already-signed-in user.
      if (auth.isResolving) {
        return onSplash ? null : AppRoutes.splash;
      }

      // 2. Mid sign-in. Stay exactly where we are: bouncing the user off the
      //    form they just submitted would tear down the screen that is about to
      //    render the failure.
      if (auth.isBusy) return null;

      // 3. Resolved and signed out. Sign-up is as legitimate a destination as
      //    sign-in, so only the splash and role screens are redirected away.
      if (!auth.isSignedIn) {
        return onAuthScreen ? null : AppRoutes.login;
      }

      // 4. Signed in, but sitting on the splash or an auth screen — this is the
      //    post-sign-in transition and the post-restore handoff.
      if (onSplash || onAuthScreen) return AppRoutes.home;

      // 5. Police-only surfaces. Checked here rather than inside each screen so
      //    that adding a route under /fir or /evidence cannot accidentally ship
      //    ungated, and so no police screen has to render a "you may not be
      //    here" state.
      //
      //    This is a UI guard, not a security control: `/generate_fir` and every
      //    evidence endpoint have no session check of their own (see
      //    docs/features/01-authentication.md, "Known issues in the server"), so
      //    it protects the officer from a dead end, not the record from a
      //    citizen. The real fix is server-side.
      final isPoliceRoute = AppRoutes.policePrefixes.any(location.startsWith);
      if (isPoliceRoute && auth.user?.role.hasPoliceAccess != true) {
        return AppRoutes.home;
      }

      // 6. Citizen-only surfaces. The website's `/citizen-dashboard` turns
      //    away every role but citizen (app.py:572-573); so does this.
      final isCitizenRoute = AppRoutes.citizenPrefixes.any(location.startsWith);
      if (isCitizenRoute && auth.user?.role != UserRole.citizen) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: AppRoutes.signupName,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const RoleHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.firNew,
        name: AppRoutes.firNewName,
        builder: (context, state) => const FirFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.firSuccess,
        name: AppRoutes.firSuccessName,
        // The screen is a receipt for an FIR that was just filed. Without one
        // there is nothing to show, so a cold launch onto this URL — a restored
        // task, a notification tap, a deep link — lands on the dashboard rather
        // than on a blank confirmation.
        redirect: (context, state) =>
            ref.read(firFormControllerProvider).receipt == null
                ? AppRoutes.home
                : null,
        builder: (context, state) => const FirSuccessScreen(),
      ),
      GoRoute(
        path: AppRoutes.firHistory,
        name: AppRoutes.firHistoryName,
        builder: (context, state) => const FirHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.firRecord,
        name: AppRoutes.firRecordName,
        builder: (context, state) => FirRecordScreen(
          // Required by the path pattern, so GoRouter cannot match this route
          // without it; the fallback satisfies the nullable type rather than
          // describing a reachable state.
          firNo: state.pathParameters['firNo'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.evidenceAdd,
        name: AppRoutes.evidenceAddName,
        builder: (context, state) => const EvidenceAddScreen(),
      ),
      GoRoute(
        path: AppRoutes.complaintDetail,
        name: AppRoutes.complaintDetailName,
        builder: (context, state) => ComplaintDetailScreen(
          // Required by the path pattern, so GoRouter cannot match this route
          // without it; the fallback satisfies the nullable type rather than
          // describing a reachable state.
          trackingId: state.pathParameters['trackingId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.lawLibrary,
        name: AppRoutes.lawLibraryName,
        builder: (context, state) => const LawLibraryScreen(),
        routes: [
          // Nested, so `/law/ask` and `/law/section/...` are children of the
          // library rather than siblings that happen to share a prefix. Back
          // from a section therefore lands on the library even when the section
          // was opened from a deep link.
          GoRoute(
            path: 'ask',
            name: AppRoutes.lawAskName,
            builder: (context, state) => const AskLawScreen(),
          ),
          GoRoute(
            path: 'outcome',
            name: AppRoutes.lawOutcomeName,
            builder: (context, state) => const LawOutcomeScreen(),
          ),
          GoRoute(
            path: 'reference',
            name: AppRoutes.lawReferenceName,
            builder: (context, state) => const LawReferenceScreen(),
          ),
          GoRoute(
            path: 'section/:act/:section',
            name: AppRoutes.lawSectionName,
            builder: (context, state) => LawSectionScreen(
              // Both are required by the path pattern, so GoRouter cannot match
              // without them; the fallbacks satisfy the nullable type rather
              // than describing a reachable state.
              act: state.pathParameters['act'] ?? '',
              section: state.pathParameters['section'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.missingPersons,
        name: AppRoutes.missingPersonsName,
        builder: (context, state) => const MissingPersonsScreen(),
        routes: [
          // `new` before `:personId`, and that order is load-bearing: GoRouter
          // matches child routes in declaration order, so a `:personId` sibling
          // declared first would swallow `/missing-persons/new` and open a case
          // whose ID is the word "new".
          GoRoute(
            path: 'new',
            name: AppRoutes.missingPersonNewName,
            builder: (context, state) => const MissingPersonFormScreen(),
          ),
          GoRoute(
            path: ':personId',
            name: AppRoutes.missingPersonName,
            builder: (context, state) => MissingPersonDetailScreen(
              // Required by the path pattern; the fallback satisfies the
              // nullable type rather than describing a reachable state.
              personId: state.pathParameters['personId'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.citizenMissingPerson,
        name: AppRoutes.citizenMissingPersonName,
        builder: (context, state) => CitizenMissingPersonDetailScreen(
          // Required by the path pattern; the fallback satisfies the nullable
          // type rather than describing a reachable state.
          personId: state.pathParameters['personId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.evidenceDetail,
        name: AppRoutes.evidenceDetailName,
        builder: (context, state) => EvidenceDetailScreen(
          // Both are required by the path pattern, so GoRouter cannot match this
          // route without them; the fallback exists to satisfy the nullable type
          // rather than to describe a reachable state.
          firNo: state.pathParameters['firNo'] ?? '',
          filename: state.pathParameters['filename'] ?? '',
        ),
      ),
    ],
  );
});

/// Bridges Riverpod's auth state to GoRouter's [Listenable]-based refresh.
///
/// Only notifies when the *status* changes, not on every AuthState rebuild. A
/// cleared failure or a refreshed display name does not affect which screen the
/// user belongs on, and re-running the redirect for those would be churn.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        if (previous?.status != next.status) notifyListeners();
      },
      fireImmediately: false,
    );
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
