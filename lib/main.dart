import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/app_router.dart'; // ถ้าพี่ใช้ไฟล์ router อื่น ปรับ import ตามจริง
import 'features/auth/data/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.init(); // ← สำคัญ: กัน LateInitializationError
  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter, // ใช้ GoRouter ที่ประกาศไว้
    );
  }
}
