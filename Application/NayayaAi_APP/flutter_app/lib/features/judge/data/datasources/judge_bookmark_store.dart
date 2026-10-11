import 'dart:convert';

import '../../../../core/storage/secure_storage_service.dart';
import '../models/judge_models.dart';

/// The Law Library's bookmarks, kept on the device.
///
/// The website keeps them in `localStorage` under `nyayaai_judge_bookmarks`
/// (judge_dashboard.html:996-1047): in the browser, not on the server, and
/// shared by whoever uses that browser. This is the same arrangement on a
/// phone — the same key, one list per device, untouched by sign-out — held in
/// the app's existing secure storage rather than a new dependency (analysis
/// OQ-J5). No server has these.
class JudgeBookmarkStore {
  const JudgeBookmarkStore(this._storage);

  static const key = 'nyayaai_judge_bookmarks';

  final SecureStorageService _storage;

  /// `JSON.parse(localStorage.getItem(...) || "[]")`, and `[]` when that
  /// throws.
  Future<List<JudgeBookmark>> read() async {
    final raw = await _storage.read(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is Map) JudgeBookmark.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Writes [bookmarks] and returns what is stored afterwards, so the screen
  /// shows what was actually saved rather than what it asked for.
  Future<List<JudgeBookmark>> write(List<JudgeBookmark> bookmarks) async {
    await _storage.write(
      key,
      jsonEncode([for (final b in bookmarks) b.toJson()]),
    );
    return read();
  }
}
