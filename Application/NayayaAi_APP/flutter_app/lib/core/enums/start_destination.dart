/// Where a cold start lands once the session has been resolved.
///
/// Lives in `core/` rather than in the splash feature because three features
/// have a stake in the answer: onboarding, authentication and the dashboard. The
/// splash screen only *asks* the question -- whatever service ends up answering
/// it (an AuthRepository, a GoRouter redirect) returns one of these.
enum StartDestination {
  /// First run, or onboarding was abandoned part-way. Precedes [login].
  onboarding,

  /// No session, an expired session, or a session check that failed. This is the
  /// safe default: showing sign-in to someone already signed in costs a tap;
  /// the reverse costs a security boundary.
  login,

  /// A session that was checked and found valid.
  dashboard,
}
