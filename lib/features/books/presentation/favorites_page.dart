// lib/features/books/presentation/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:library_booking/features/books/data/book_repo.dart';
import 'package:library_booking/features/books/domain/models/book.dart';
import 'package:library_booking/features/books/presentation/widgets/book_card.dart';
import 'package:library_booking/features/books/presentation/providers/favorites_provider.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),

      body: ids.isEmpty
          ? const _Empty()
          : FutureBuilder<List<Book>>(
              future: ref
                  .read(bookRepoProvider)
                  .listBooks(query: '', category: '', page: 1, limit: 1000),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _Error('${snap.error}');
                }

                final all = snap.data ?? const <Book>[];
                final favBooks =
                    all.where((b) => ids.contains(b.id)).toList();

                if (favBooks.isEmpty) return const _Empty();

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: .68,
                  ),
                  itemCount: favBooks.length,
                  itemBuilder: (_, i) {
                    final b = favBooks[i];
                    final isFav =
                        ref.watch(favoritesProvider).contains(b.id);

                    return BookCard(
                      b,
                      // หน้า Favorites ไม่ได้ใช้ปุ่ม + ก็ส่ง noop ไปและไม่เลือก
                      onAdd: () {},
                      isSelected: false,
                      onTap: () => context.push('/books/${b.id}'),

                      // ❤️ มุมซ้ายบน: toggle ได้
                      isFavorited: isFav,
                      onToggleFavorite: () =>
                          ref.read(favoritesProvider.notifier).toggle(b.id),
                    );
                  },
                );
              },
            ),

      // ให้ UI ต่อเนื่องกับ Home
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), 
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border), 
              label: 'Favorites'),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
              icon: Icon(Icons.person_outline), 
              label: 'Profile'),
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
              context.go('/profile');
              break;
          }
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.favorite_border, size: 48),
          const SizedBox(height: 8),
          Text('No favorites yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Tap the heart on any book to add here',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class _Error extends StatelessWidget {
  const _Error(this.msg);
  final String msg;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(height: 8),
          Text('Error: $msg'),
        ]),
      );
}
