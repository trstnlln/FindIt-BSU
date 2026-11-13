import 'dart:async';
import 'dart:convert';

import 'backend_features.dart';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceAlerts {
  static StreamSubscription<String>? _refresh;
  static const _vapid = String.fromEnvironment('FCM_WEB_VAPID_KEY');
  static bool get _supported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  static String _id(String token) =>
      base64Url.encode(utf8.encode(token)).replaceAll('=', '');
  static Future<void> _register(String uid, String token) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid ||
        FirebaseAuth.instance.currentUser?.emailVerified != true) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString('device-alerts-token:$uid');
    final devices = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('devices');
    final batch = FirebaseFirestore.instance.batch();
    batch.set(devices.doc(_id(token)), {
      'token': token,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (previous != null && previous != token) {
      batch.delete(devices.doc(_id(previous)));
    }
    await batch.commit();
    await prefs.setString('device-alerts-token:$uid', token);
  }

  static Future<void> _watch(String uid) async {
    await _refresh?.cancel();
    _refresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      try {
        await _register(uid, token);
      } catch (_) {
        /* Retry registration on the next launch. */
      }
    }, onError: (Object error) {});
  }

  static Future<void> enable() async {
    if (!BackendFeatures.cloudAlerts) {
      throw StateError(
        'Device delivery has not been configured. Use live activity in the app.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError('Verify your account first.');
    }
    if (!_supported || (kIsWeb && _vapid.isEmpty)) {
      throw StateError('Device alerts are unavailable.');
    }
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError('Notification permission was not granted.');
    }
    final token = await messaging.getToken(vapidKey: kIsWeb ? _vapid : null);
    if (token == null) throw StateError('Device registration failed.');
    await _register(user.uid, token);
    await (await SharedPreferences.getInstance()).setBool(
      'device-alerts-enabled:${user.uid}',
      true,
    );
    await _watch(user.uid);
  }

  /// Restore an existing opt-in without showing another permission prompt.
  static Future<void> restore() async {
    if (!BackendFeatures.cloudAlerts) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (!_supported ||
          user == null ||
          !user.emailVerified ||
          (kIsWeb && _vapid.isEmpty)) {
        return;
      }
      if ((await SharedPreferences.getInstance()).getBool(
            'device-alerts-enabled:${user.uid}',
          ) !=
          true) {
        return;
      }
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? _vapid : null,
      );
      if (token != null) await _register(user.uid, token);
      await _watch(user.uid);
    } catch (_) {
      /* The in-app inbox remains available without push. */
    }
  }

  static Future<void> disableCurrentDevice() async {
    await _refresh?.cancel();
    _refresh = null;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('device-alerts-token:${user.uid}');
      await prefs.remove('device-alerts-enabled:${user.uid}');
      await prefs.remove('device-alerts-token:${user.uid}');
      if (token == null) return;
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(_id(token))
            .delete()
            .timeout(const Duration(seconds: 2));
      } finally {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (_) {
      /* Sign-out must still work when offline. */
    }
  }
}
