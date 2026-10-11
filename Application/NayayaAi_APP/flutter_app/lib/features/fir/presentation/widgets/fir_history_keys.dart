import 'package:flutter/widgets.dart';

/// Keys for the history list and the record viewer.
///
/// Same purpose as [FirFieldKeys]: they exist so a test can name a control the
/// way the screen does, rather than reaching it by position or by wording. A
/// test that finds the Download button by its label turns a copy edit into a
/// failure that says nothing about what broke.
abstract final class FirHistoryKeys {
  const FirHistoryKeys._();

  static const search = Key('firHistory.search');
  static const list = Key('firHistory.list');

  /// One row, keyed by the FIR number it opens — which is the only identity the
  /// server gives a record, and is unique by the duplicate check on filing.
  static Key tile(String firNo) => Key('firHistory.tile.$firNo');

  static const download = Key('firRecord.download');
  static const narrative = Key('firRecord.narrative');
}
