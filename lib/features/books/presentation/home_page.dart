import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/book.dart';
import 'widgets/book_card.dart';
import 'providers/search_filter_providers.dart';
import 'providers/favorites_provider.dart'; // ✅ เพิ่มบรรทัดนี้

/// ========== เลือกหนังสือ (จำนวนที่กด) ==========
final selectedBooksProvider = StateProvider<Set<String>>((_) => <String>{});

/// ฟิลเตอร์/เรียงลำดับเฉพาะฝั่ง client
enum StatusFilter { all, available, reserved, borrowed, overdue }

final statusFilterProvider =
    StateProvider<StatusFilter>((_) => StatusFilter.all);

enum SortOption { relevance, ratingDesc, ratingAsc, titleAsc, titleDesc }

final sortOptionProvider =
    StateProvider<SortOption>((_) => SortOption.relevance);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    // state ค้นหา/หมวดหมู่
    final query = ref.watch(searchQueryProvider);
    final category = ref.watch(categoryProvider);

    // โหลดหนังสือตาม query + category (ฝั่ง server/pagination)
    final booksAsync = ref.watch(pagedBooksProvider((query, category)));

    // จำนวนที่กด (โชว์ badge)
    final selectedCount = ref.watch(selectedBooksProvider).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Central Library'),
        actions: [
          // ไอคอน My Loans + badge จำนวนเล่มที่กด
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu_book_outlined),
                  tooltip: 'My Loans',
                  onPressed: () => context.push('/loans'),
                ),
                if (selectedCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$selectedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      body: CustomScrollView(
        slivers: [
          // Search + ปุ่มฟิลเตอร์
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) =>
                          ref.read(searchQueryProvider.notifier).set(v),
                      decoration: InputDecoration(
                        hintText: 'Search books...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.tune),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) => const _FilterSheet(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // โปรโมแบนเนอร์
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [colors.secondary, colors.primary],
                  ),
                ),
                child: const Text(
                  'Read For Fun - Borrow Books Today!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // หมวดหมู่
          SliverToBoxAdapter(
            child: _CategoryChips(current: category),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // เนื้อหา: grid/loading/error/empty
          booksAsync.when(
            data: (items) {
              // client-side filter/sort เพิ่มเติม
              final status = ref.watch(statusFilterProvider);
              final sort = ref.watch(sortOptionProvider);
              final favIds = ref.watch(favoritesProvider); // ✅ ids ที่ favorite

              Iterable<Book> list = items;
              list = switch (status) {
                StatusFilter.all => list,
                StatusFilter.available =>
                  list.where((b) => b.status == BookStatus.available),
                StatusFilter.reserved =>
                  list.where((b) => b.status == BookStatus.reserved),
                StatusFilter.borrowed =>
                  list.where((b) => b.status == BookStatus.borrowed),
                StatusFilter.overdue =>
                  list.where((b) => b.status == BookStatus.overdue),
              };

              final sorted = list.toList();
              switch (sort) {
                case SortOption.ratingDesc:
                  sorted.sort((a, b) => b.rating.compareTo(a.rating));
                  break;
                case SortOption.ratingAsc:
                  sorted.sort((a, b) => a.rating.compareTo(b.rating));
                  break;
                case SortOption.titleAsc:
                  sorted.sort((a, b) =>
                      a.title.toLowerCase().compareTo(b.title.toLowerCase()));
                  break;
                case SortOption.titleDesc:
                  sorted.sort((a, b) =>
                      b.title.toLowerCase().compareTo(a.title.toLowerCase()));
                  break;
                case SortOption.relevance:
                  break;
              }

              if (sorted.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyView(),
                );
              }

              return SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: .68,
                  ),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) {
                    final b = sorted[i];
                    final isSelected =
                        ref.watch(selectedBooksProvider).contains(b.id);
                    final isFav = favIds.contains(b.id); // ✅

                    return BookCard(
                      b,
                      onTap: () => context.push('/books/${b.id}'),
                      isSelected: isSelected,
                      onAdd: () {
                        final set = {...ref.read(selectedBooksProvider)};
                        set.contains(b.id) ? set.remove(b.id) : set.add(b.id);
                        ref.read(selectedBooksProvider.notifier).state = set;
                      },

                      // ✅ ส่งค่า favorite ให้การ์ด
                      isFavorited: isFav,
                      onToggleFavorite: () =>
                          ref.read(favoritesProvider.notifier).toggle(b.id),
                    );
                  },
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorView(error: '$e'),
            ),
          ),
        ],
      ),

      // แถบนำทางล่าง
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
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

/// -------- Category chips --------
class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const chips = [
      'All',
      'Computer',
      'Business',
      'Sci-Tech',
      'Fantasy',
      'Classic',
      'YA',
      'Dystopia',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: chips.map((c) {
          final isAll = c == 'All';
          final value = switch (c) {
            'Computer' => 'Software',
            'Sci-Tech' => 'Science',
            _ => isAll ? '' : c,
          };
          final selected = (isAll && current.isEmpty) || current == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              label: Text(c),
              onSelected: (_) =>
                  ref.read(categoryProvider.notifier).state = value,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// -------- Bottom sheet: ฟิลเตอร์/เรียง --------
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(statusFilterProvider);
    final sort = ref.watch(sortOptionProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Filter books',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ]),
          const SizedBox(height: 8),
          const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(ref, StatusFilter.all, 'All', status),
              _statusChip(ref, StatusFilter.available, 'Available', status),
              _statusChip(ref, StatusFilter.reserved, 'Reserved', status),
              _statusChip(ref, StatusFilter.borrowed, 'Borrowed', status),
              _statusChip(ref, StatusFilter.overdue, 'Overdue', status),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _sortTile(ref, SortOption.relevance, 'Relevance', sort),
          _sortTile(ref, SortOption.ratingDesc, 'Rating: high → low', sort),
          _sortTile(ref, SortOption.ratingAsc, 'Rating: low → high', sort),
          _sortTile(ref, SortOption.titleAsc, 'Title: A → Z', sort),
          _sortTile(ref, SortOption.titleDesc, 'Title: Z → A', sort),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(
      WidgetRef ref, StatusFilter value, String label, StatusFilter current) {
    final selected = value == current;
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => ref.read(statusFilterProvider.notifier).state = value,
    );
  }

  Widget _sortTile(
      WidgetRef ref, SortOption opt, String label, SortOption current) {
    return RadioListTile<SortOption>(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: opt,
      groupValue: current,
      onChanged: (v) => ref.read(sortOptionProvider.notifier).state = v!,
    );
  }
}

/// -------- Views: Empty / Error --------
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inbox_outlined, size: 42),
        const SizedBox(height: 8),
        Text('No books found', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Try different filters or keywords',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 42, color: Colors.red),
        const SizedBox(height: 8),
        Text('Something went wrong',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(error, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
