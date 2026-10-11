/// Keys used in secure storage.
///
/// Namespaced so an unrelated plugin writing to the same keychain/keystore
/// cannot collide with ours.
abstract final class StorageKeys {
  const StorageKeys._();

  static const _prefix = 'nyayaai';

  /// The cached signed-in profile, as JSON. Holds only what the server will not
  /// give back on session restore: display name, email, unique ID. The session
  /// cookie itself is the cookie jar's business, not this one's.
  static const cachedUser = '${_prefix}_cached_user';

  /// The in-progress FIR, as JSON. A 27-field statutory form is minutes of
  /// typing, and losing it to a backgrounded app that Android then killed is
  /// the one failure this feature cannot recover from.
  ///
  /// In *secure* storage rather than shared preferences because a part-written
  /// FIR holds a complainant's name, address and date of birth before it has
  /// reached the server. Cleared the moment the FIR is registered.
  static const firDraft = '${_prefix}_fir_draft';
}
