import 'package:hive_flutter/hive_flutter.dart';

class ProfileStore {
  static Box? _box;
  static const _boxName = 'profile';

  static const _kName = 'name';
  static const _kEmail = 'email';
  static const _kAvatar = 'avatar';

  static Future<void> init() async {
    if (_box != null) return;
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  static Future<void> setName(String v) async {
    await init(); await _box!.put(_kName, v);
  }

  static Future<void> setEmail(String v) async {
    await init(); await _box!.put(_kEmail, v);
  }

  static Future<void> setAvatar(String v) async {
    await init(); await _box!.put(_kAvatar, v);
  }

  static String name({String def = 'Mock User'}) {
    return (_box?.get(_kName) as String?) ?? def;
  }

  static String email({String def = 'user@example.com'}) {
    return (_box?.get(_kEmail) as String?) ?? def;
  }

  static String avatar({String def = ''}) {
    return (_box?.get(_kAvatar) as String?) ?? def;
  }
}
