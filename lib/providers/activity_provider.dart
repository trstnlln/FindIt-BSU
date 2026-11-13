import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/activity_entry.dart';
import '../models/claim_model.dart';
import '../models/item_model.dart';
import '../services/activity_service.dart';

/// One set of participant-scoped listeners per session. No Cloud Functions needed.
class ActivityProvider extends ChangeNotifier {
  final ActivityService service;
  ActivityProvider({ActivityService? service})
    : service = service ?? ActivityService();
  String? _uid;
  int _revision = 0;
  bool _disposed = false;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _pending = <String>{};
  final _errors = <String>{};
  List<ItemModel> reports = [];
  List<ClaimModel> incoming = [], submitted = [];
  Map<String, Map<String, dynamic>> _ownerChats = {}, _claimantChats = {};
  Map<String, String> _reads = {};
  bool get isLoading => _pending.isNotEmpty;
  bool get hasError => _errors.isNotEmpty;
  List<ActivityEntry> get entries => _uid == null
      ? []
      : deriveActivity(
          uid: _uid!,
          incoming: incoming,
          submitted: submitted,
          conversations: {..._ownerChats, ..._claimantChats},
        );
  bool isUnread(ActivityEntry entry) => _reads[entry.id] != entry.version;
  int get unreadCount => entries.where(isUnread).length;
  ClaimModel? claim(String? id) {
    for (final claim in [...incoming, ...submitted]) {
      if (claim.id == id) return claim;
    }
    return null;
  }

  bool hasUnreadMessage(String itemId) => entries.any(
    (entry) => entry.message && entry.itemId == itemId && isUnread(entry),
  );
  ActivityEntry? messageFor(String itemId) {
    for (final entry in entries) {
      if (entry.message && entry.itemId == itemId && isUnread(entry)) {
        return entry;
      }
    }
    return null;
  }

  void bind(String? uid, {bool force = false}) {
    if (_disposed || (!force && uid == _uid)) return;
    _uid = uid;
    final revision = ++_revision;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    reports = [];
    incoming = [];
    submitted = [];
    _ownerChats = {};
    _claimantChats = {};
    _reads = {};
    _errors.clear();
    _pending.clear();
    if (uid != null) {
      _watch(
        'reports',
        service.reports(uid),
        (value) => reports = value,
        revision,
      );
      _watch(
        'incoming',
        service.incoming(uid),
        (value) => incoming = value,
        revision,
      );
      _watch(
        'submitted',
        service.submitted(uid),
        (value) => submitted = value,
        revision,
      );
      _watch(
        'ownerChats',
        service.conversations(uid, 'ownerId'),
        (value) => _ownerChats = value,
        revision,
      );
      _watch(
        'claimantChats',
        service.conversations(uid, 'claimantId'),
        (value) => _claimantChats = value,
        revision,
      );
      _watch('reads', service.reads(uid), (value) => _reads = value, revision);
    }
    scheduleMicrotask(() {
      if (!_disposed && revision == _revision) notifyListeners();
    });
  }

  void retry() => bind(_uid, force: true);
  void _watch<T>(
    String key,
    Stream<T> stream,
    void Function(T) update,
    int revision,
  ) {
    _pending.add(key);
    _subscriptions.add(
      stream.listen(
        (value) {
          if (_disposed || revision != _revision) return;
          update(value);
          _pending.remove(key);
          _errors.remove(key);
          notifyListeners();
        },
        onError: (Object error) {
          if (_disposed || revision != _revision) return;
          _pending.remove(key);
          _errors.add(key);
          notifyListeners();
        },
      ),
    );
  }

  Future<void> markRead(ActivityEntry entry) async {
    final uid = _uid;
    final revision = _revision;
    if (uid == null || !isUnread(entry)) return;
    await service.markRead(uid, entry.id, entry.version);
    if (!_disposed && revision == _revision) {
      _reads = {..._reads, entry.id: entry.version};
      notifyListeners();
    }
  }

  Future<void> markMessageRead(String claimId, String messageId) async {
    final uid = _uid;
    if (uid == null || _reads['message-$claimId'] == messageId) return;
    await markRead(
      ActivityEntry(
        id: 'message-$claimId',
        version: messageId,
        itemId: '',
        title: '',
        body: '',
        date: DateTime(1970),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    ++_revision;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}
