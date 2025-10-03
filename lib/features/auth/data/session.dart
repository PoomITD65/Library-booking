// lib/features/auth/data/session.dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Session {
  static Box? _box;
  static const _boxName = 'session';
  static const _kToken = 'token';

  // ✅ ใช้แจ้ง router ให้ refresh
  static final ValueNotifier<bool> auth = ValueNotifier<bool>(false);

  static Future<void> init() async {
    if (_box != null) return;
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    final t = _box!.get(_kToken) as String?;
    auth.value = (t != null && t.isNotEmpty);
  }

  static Future<String?> token() async {
    await init();
    return _box!.get(_kToken) as String?;
  }

  // ✅ สถานะ sync สำหรับ guard
  static bool get isLoggedIn => auth.value;

  static Future<void> setToken(String? value) async {
    await init();
    if (value == null || value.isEmpty) {
      await _box!.delete(_kToken);
      auth.value = false;
    } else {
      await _box!.put(_kToken, value);
      auth.value = true;
    }
  }

  static Future<void> clear() async {
    await init();
    await _box!.clear();
    auth.value = false;
  }
}
