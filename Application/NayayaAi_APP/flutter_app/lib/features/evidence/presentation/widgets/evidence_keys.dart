import 'package:flutter/widgets.dart';

/// Keys for the locker's controls, so tests can name them the way the screens
/// do rather than by position or by wording. Same rationale as `FirFieldKeys`.
abstract final class EvidenceKeys {
  const EvidenceKeys._();

  // PIN gate
  static const pinField = Key('evidence.pin');
  static const pinSubmit = Key('evidence.pin.submit');

  // List
  static const search = Key('evidence.search');

  static const categoryChips = Key('evidence.category-chips');

  static Key categoryChip(String name) => Key('evidence.category-$name');
  static const list = Key('evidence.list');
  static const addButton = Key('evidence.add');

  /// One row. Keyed by identity — the server has no id, so `(fir_no, filename)`
  /// is the only thing that names a file uniquely.
  static Key tile(String firNo, String filename) =>
      Key('evidence.tile.$firNo/$filename');

  // Add
  static const addFirNo = Key('evidence.add.firNo');

  /// Opens the FIR history sheet from inside the number field.
  static const addFirPicker = Key('evidence.add.firNo.picker');
  static const addFile = Key('evidence.add.file');
  static const addSubmit = Key('evidence.add.submit');
}
