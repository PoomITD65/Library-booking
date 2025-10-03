// lib/features/profile/presentation/profile_page.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dio_client.dart';
import '../../auth/data/session.dart';
import '../../books/presentation/providers/favorites_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  // สร้าง dio ไว้ใช้ในหน้านี้
  static final _dioProvider = Provider<Dio>((ref) => createDio(Session.token));

  Future<int> _fetchBorrowedCount(WidgetRef ref) async {
    final dio = ref.read(_dioProvider);
    // mock_server: /api/loans/history (ถ้าคุณใช้ prefix /api)
    final res = await dio.get(
        '/loans/history', // ถ้าเซิร์ฟเวอร์คุณมี /api ให้เปลี่ยนเป็น '/api/loans/history'
        queryParameters: {'status': 'borrowed'});
    final list = res.data as List<dynamic>;
    return list.length;
  }

  Future<int> _fetchReservedCount(WidgetRef ref) async {
    final dio = ref.read(_dioProvider);
    // ดึงรายการหนังสือจำนวนมากพอ แล้วกรอง reserved ฝั่ง client
    final res = await dio
        .get('/books', // ถ้าเซิร์ฟเวอร์คุณมี /api ให้เปลี่ยนเป็น '/api/books'
            queryParameters: {'page': '1', 'limit': '1000'});
    final list = (res.data as List<dynamic>);
    final reserved =
        list.where((e) => (e as Map)['status']?.toString() == 'reserved');
    return reserved.length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final favCount = ref.watch(favoritesProvider).length;

    // ดึง borrowed & reserved พร้อมกัน
    final futureCounts = Future.wait<int>([
      _fetchBorrowedCount(ref),
      _fetchReservedCount(ref),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ---- Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.primaryContainer,
                  child: const Icon(Icons.person, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mock User',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('user@example.com',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final changed = await context.push<bool>('/profile/edit');
                    // ถ้าอยากรีเฟรชค่าโชว์ในหน้า Profile ทันที แนะนำให้ดึงค่าจาก ProfileStore มาใช้แทนการ hardcode
                    // หรือ setState() ถ้าเปลี่ยนเป็น StatefulWidget
                  },
                  child: const Text('Edit'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Stats (ดึงจาก mock)
          FutureBuilder<List<int>>(
            future: futureCounts,
            builder: (context, snap) {
              final borrowed = snap.hasData ? snap.data![0] : 0;
              final reserved = snap.hasData ? snap.data![1] : 0;

              return Row(
                children: [
                  _StatCard(
                    label: 'Borrowed',
                    value: '$borrowed',
                    icon: Icons.menu_book_outlined,
                    loading: snap.connectionState != ConnectionState.done,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Reserved',
                    value: '$reserved',
                    icon: Icons.lock_clock_outlined,
                    loading: snap.connectionState != ConnectionState.done,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Favorites',
                    value: '$favCount',
                    icon: Icons.favorite_outline,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // ---- Quick actions
          Text('Quick actions',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionChip(
                icon: Icons.search_outlined,
                label: 'Find books',
                onTap: () => context.go('/home'),
              ),
              _ActionChip(
                icon: Icons.favorite_border,
                label: 'My favorites',
                onTap: () => context.go('/favorites'),
              ),
              _ActionChip(
                icon: Icons.history,
                label: 'History',
                onTap: () => context.go('/history'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---- Sections
          _SectionCard(
            title: 'Account',
            children: const [
              ListTile(
                leading: Icon(Icons.badge_outlined),
                title: Text('Library card'),
                subtitle: Text('ID: U000123'),
              ),
              ListTile(
                leading: Icon(Icons.notifications_outlined),
                title: Text('Notifications'),
                subtitle: Text('Due reminders, reservations'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'App',
            children: const [
              ListTile(
                leading: Icon(Icons.color_lens_outlined),
                title: Text('Appearance'),
                subtitle: Text('System / Light / Dark'),
              ),
              ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Privacy'),
              ),
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('About'),
                subtitle: Text('v1.0.0'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---- Sign out
          FilledButton.tonalIcon(
            onPressed: () async {
              await Session.setToken(null);
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),

      // ---- Bottom nav
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border), label: 'Favorites'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/favorites');
              break;
            case 2:
              context.go('/history');
              break;
            case 3:
              break;
          }
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.loading = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(height: 8),
            if (loading)
              const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ]),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
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
