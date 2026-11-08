import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Drafts contain public report fields only. Photos and private verification
/// answers/amounts are deliberately never persisted on a shared device.
class ReportDraftStore {
  String _key(String uid) => 'report-draft-v1:$uid';
  Future<Map<String, dynamic>?> load(String uid) async {
    final text = (await SharedPreferences.getInstance()).getString(_key(uid));
    if (text == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String uid, Map<String, dynamic> draft) async {
    final allowed = <String, dynamic>{};
    for (final key in [
      'type',
      'title',
      'description',
      'category',
      'location',
      'specificLocation',
      'custodyLocation',
      'date',
    ]) {
      if (draft.containsKey(key)) allowed[key] = draft[key];
    }
    await (await SharedPreferences.getInstance()).setString(
      _key(uid),
      jsonEncode(allowed),
    );
  }

  Future<void> clear(String uid) async =>
      (await SharedPreferences.getInstance()).remove(_key(uid));
}
