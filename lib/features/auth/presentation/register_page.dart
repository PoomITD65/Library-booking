// lib/features/auth/presentation/register_page.dart
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dio_client.dart';
import '../data/session.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _hidePw = true;
  bool _hideCp = true;
  bool _accept = true;
  bool _loading = false;

  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = createDio(Session.token);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_accept) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept Terms & Privacy')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final resp = await _dio.post('/auth/register', data: {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
      });

      final token = (resp.data is Map) ? resp.data['token'] as String? : null;

      if (token != null && token.isNotEmpty) {
        if (!mounted) return;

        // 🔔 แสดงแจ้งเตือนก่อนเข้าสู่ระบบ
        await AwesomeDialog(
          context: context,
          dialogType: DialogType.noHeader,
          animType: AnimType.scale,
          dismissOnBackKeyPress: false,
          dismissOnTouchOutside: false,
          customHeader: CircleAvatar(
            radius: 36,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(
              Icons.check_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          title: 'Registered!',
          desc: 'Account created. Logging you in…',
          autoHide: const Duration(milliseconds: 1200),
        ).show();

        // ✅ จากนั้นค่อยเซฟ token เพื่อให้ guard เปลี่ยนหน้า
        await Session.setToken(token);

        if (!mounted) return;
        context.go('/home');
      } else {
        if (!mounted) return;
        await AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'Registered!',
          desc: 'Please login to continue.',
          btnOkOnPress: () => context.go('/login'),
        ).show();
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? 'Register failed')
          : (e.message ?? 'Register failed');
      if (!mounted) return;
      await AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'Failed',
        desc: '$msg',
        btnOkOnPress: () {},
      ).show();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final maxW = c.maxWidth;
            final horizontal = maxW >= 480 ? (maxW - 420) / 2 : 16.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Icon(Icons.menu_book_rounded, size: 46, color: cs.primary),
                    const SizedBox(height: 8),
                    Text(
                      'Central Library',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text('Create your account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),

                    // Full name
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Email
                    TextFormField(
                      controller: _email,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);
                        return ok ? null : 'Invalid email';
                      },
                    ),
                    const SizedBox(height: 12),

                    // Password
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePw,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _hidePw ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _hidePw = !_hidePw),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 12),

                    // Confirm Password
                    TextFormField(
                      controller: _confirm,
                      obscureText: _hideCp,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.lock_person_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _hideCp ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _hideCp = !_hideCp),
                        ),
                      ),
                      validator: (v) =>
                          (v != _password.text) ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 8),

                    // Terms
                    Row(
                      children: [
                        Checkbox(
                          value: _accept,
                          onChanged: (v) => setState(() => _accept = v ?? false),
                        ),
                        const Expanded(
                          child: Text(
                              'I agree to the Terms of Service and Privacy Policy'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Register Button
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Register'),
                    ),
                    const SizedBox(height: 12),

                    // Already have account
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account? "),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
