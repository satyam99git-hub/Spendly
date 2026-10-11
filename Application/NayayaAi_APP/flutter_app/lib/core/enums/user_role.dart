/// The four roles the NyayaAI server recognises at registration, plus [admin],
/// which exists in the server's permission checks but cannot be signed up for.
///
/// The wire values are the exact lowercase strings the server stores and
/// returns; do not "tidy" them.
enum UserRole {
  citizen('citizen', 'Citizen', 'CIT'),
  police('police', 'Police Officer', 'POL'),
  lawyer('lawyer', 'Lawyer', 'LAW'),
  judge('judge', 'Judge', 'JUD'),

  /// Not offered at registration. The server treats an admin as police for
  /// missing-persons access and as a judge for the judge dashboard, so the app
  /// has to be able to represent one that already exists in the database.
  admin('admin', 'Administrator', 'ADM');

  const UserRole(this.wireValue, this.label, this.idPrefix);

  /// What the server sends and expects.
  final String wireValue;

  /// Human-readable name for the UI.
  final String label;

  /// Prefix the server requires on this role's unique ID.
  final String idPrefix;

  /// Roles a person can actually register as. [admin] is excluded because
  /// `POST /signup` rejects it with "Invalid role".
  static const registerable = [citizen, police, lawyer, judge];

  /// True when the *user* must supply their own unique ID at registration.
  ///
  /// The server generates `CIT###` for citizens but demands a caller-supplied,
  /// correctly-prefixed, not-already-taken ID for the three professional roles.
  bool get requiresUserSuppliedId => this != citizen && this != admin;

  /// Whether this role reaches the police console. Mirrors the server's
  /// `_is_police()`, which accepts police, admin and officer.
  bool get hasPoliceAccess => this == police || this == admin;

  /// Parses a wire value. Unknown or missing values fall back to [citizen] —
  /// the least-privileged role — so a server-side role the app has not been
  /// taught about can never accidentally unlock a professional surface.
  static UserRole fromWire(String? value) {
    final v = value?.trim().toLowerCase();

    // The server's own checks treat "officer" as police; accept it so an
    // account created that way is not silently demoted to citizen.
    if (v == 'officer') return police;

    for (final role in UserRole.values) {
      if (role.wireValue == v) return role;
    }
    return citizen;
  }
}
