import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// เก็บ/อ่านค่าจาก Hive ใน box ชื่อ 'prefs'
class SettingsStore {
  static Box? _box;
  static const _boxName = 'prefs';

  static const _kThemeMode = 'themeMode';         // system/light/dark
  static const _kNotifyDue = 'notifyDue';         // เตือนใกล้ถึงกำหนด
  static const _kNotifyNews = 'notifyNews';       // ข่าว/อัปเดต
  static const _kLanguage = 'language';           // th/en

  static Future<void> init() async {
    if (_box != null) return;
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  static Future<void> setString(String key, String value) async {
    await init();
    await _box!.put(key, value);
  }

  static Future<void> setBool(String key, bool value) async {
    await init();
    await _box!.put(key, value);
  }

  static String getString(String key, {String def = ''}) {
    return (_box?.get(key) as String?) ?? def;
  }

  static bool getBool(String key, {bool def = false}) {
    return (_box?.get(key) as bool?) ?? def;
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _theme = 'system'; // system | light | dark
  bool _notifyDue = true;
  bool _notifyNews = false;
  String _language = 'th';  // th | en

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SettingsStore.init();
    setState(() {
      _theme = SettingsStore.getString(SettingsStore._kThemeMode, def: 'system');
      _notifyDue = SettingsStore.getBool(SettingsStore._kNotifyDue, def: true);
      _notifyNews = SettingsStore.getBool(SettingsStore._kNotifyNews, def: false);
      _language = SettingsStore.getString(SettingsStore._kLanguage, def: 'th');
      _ready = true;
    });
  }

  Future<void> _saveTheme(String v) async {
    setState(() => _theme = v);
    await SettingsStore.setString(SettingsStore._kThemeMode, v);
    // TODO: ถ้ามี ThemeMode provider ให้ trigger เปลี่ยนธีมทันทีที่นี่
  }

  Future<void> _saveNotifyDue(bool v) async {
    setState(() => _notifyDue = v);
    await SettingsStore.setBool(SettingsStore._kNotifyDue, v);
  }

  Future<void> _saveNotifyNews(bool v) async {
    setState(() => _notifyNews = v);
    await SettingsStore.setBool(SettingsStore._kNotifyNews, v);
  }

  Future<void> _saveLanguage(String v) async {
    setState(() => _language = v);
    await SettingsStore.setString(SettingsStore._kLanguage, v);
    // TODO: ถ้ามี localization ให้รีโหลด locale ตรงนี้
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Settings')
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // ===== Appearance =====
                _SectionCard(
                  title: 'Appearance',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.color_lens_outlined),
                      title: const Text('Theme'),
                      subtitle: Text(
                        switch (_theme) {
                          'light' => 'Light',
                          'dark' => 'Dark',
                          _ => 'System',
                        },
                      ),
                      trailing: DropdownButton<String>(
                        value: _theme,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'system', child: Text('System')),
                          DropdownMenuItem(value: 'light', child: Text('Light')),
                          DropdownMenuItem(value: 'dark', child: Text('Dark')),
                        ],
                        onChanged: (v) => _saveTheme(v ?? 'system'),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.language_outlined),
                      title: const Text('Language'),
                      subtitle: Text(_language == 'th' ? 'ไทย (Thai)' : 'English'),
                      trailing: DropdownButton<String>(
                        value: _language,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'th', child: Text('ไทย (Thai)')),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                        ],
                        onChanged: (v) => _saveLanguage(v ?? 'th'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ===== Notifications =====
                _SectionCard(
                  title: 'Notifications',
                  children: [
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.notifications_active_outlined),
                      title: const Text('Due date reminder'),
                      subtitle: const Text('เตือนเมื่อใกล้ถึงกำหนดคืน'),
                      value: _notifyDue,
                      onChanged: _saveNotifyDue,
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.campaign_outlined),
                      title: const Text('News & updates'),
                      subtitle: const Text('ข่าวสาร/ประกาศจากห้องสมุด'),
                      value: _notifyNews,
                      onChanged: _saveNotifyNews,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ===== Account & App =====
                _SectionCard(
                  title: 'App',
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('About'),
                      subtitle: Text('Library Booking • v0.1.0'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Terms & Privacy'),
                      onTap: () {
                        // TODO: เปิดหน้าเอกสาร หรือ external link
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ===== Danger Zone =====
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          children: [
                            Text('Danger zone',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.error,
                                    )),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.delete_forever_outlined, color: cs.error),
                        title: const Text('Clear saved settings'),
                        subtitle: const Text('ลบค่าที่ตั้งทั้งหมดในเครื่องนี้'),
                        onTap: () async {
                          await SettingsStore.init();
                          await SettingsStore._box?.clear();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cleared settings')),
                          );
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/* ---------- Reusable section card ---------- */
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}
