// lib/features/profile/presentation/edit_profile_page.dart
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/session.dart';        // เผื่อใช้ token เวลาเชื่อมต่อ backend จริง
import '../data/profile_store.dart';          // local store: name/email/avatar

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _avatar = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    await ProfileStore.init();
    // ใส่ค่าเริ่มตั้งแต่รอบ build แรก เพื่อลดการกระพริบ
    _name.text = ProfileStore.name();
    _email.text = ProfileStore.email();
    _avatar.text = ProfileStore.avatar();
    setState(() {}); // อัปเดต preview header
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _avatar.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // ถ้ามี backend จริง → call API ด้วย token ได้ตามนี้:
      // final dio = createDio(Session.token);
      // await dio.put('/profile', data: {
      //   'name': _name.text.trim(),
      //   'avatar': _avatar.text.trim(),
      // });

      // เก็บลงเครื่องให้เห็นผลทันที
      await ProfileStore.setName(_name.text.trim());
      await ProfileStore.setEmail(_email.text.trim());
      await ProfileStore.setAvatar(_avatar.text.trim());

      if (!mounted) return;
      await AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        animType: AnimType.scale,
        dismissOnTouchOutside: false,
        dismissOnBackKeyPress: false,
        customHeader: CircleAvatar(
          radius: 36,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(Icons.check_rounded,
              color: Theme.of(context).colorScheme.onPrimary, size: 40),
        ),
        title: 'Saved',
        desc: 'Profile updated successfully.',
        btnOkText: 'OK',
        btnOkOnPress: () {},
      ).show();

      if (!mounted) return;
      context.pop(true); // ส่งผลลัพธ์ให้หน้า Profile รู้ว่าอัปเดตแล้ว
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ---- Header preview ----
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage:
                      _avatar.text.isNotEmpty ? NetworkImage(_avatar.text) : null,
                  child: _avatar.text.isEmpty
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _name.text.isEmpty ? 'Mock User' : _name.text,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Form ----
          Form(
            key: _form,
            child: Column(
              children: [
                // Full name (นิ่ง: บังคับ label อยู่ด้านบนเสมอ)
                TextFormField(
                  controller: _name,
                  autofocus: false,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  onChanged: (_) => setState(() {}), // อัปเดต preview header
                ),
                const SizedBox(height: 12),

                // Email
                TextFormField(
                  controller: _email,
                  autofocus: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);
                    return ok ? null : 'Invalid email';
                  },
                ),
                const SizedBox(height: 12),

                // Avatar URL
                TextFormField(
                  controller: _avatar,
                  autofocus: false,
                  decoration: const InputDecoration(
                    labelText: 'Avatar URL (optional)',
                    prefixIcon: Icon(Icons.image_outlined),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  onChanged: (_) => setState(() {}), // อัปเดต preview header
                ),
                const SizedBox(height: 20),

                // Save
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _save,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_loading ? 'Saving...' : 'Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
