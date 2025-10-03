import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/book.dart';
import 'widgets/book_card.dart';
import 'providers/search_filter_providers.dart';
// ✅ ใช้สำหรับเก็บ favorite ids
import 'providers/favorites_provider.dart';

/// เก็บ id หนังสือที่ถูกกด + (แสดงผลเป็น badge บน AppBar ของ scaffold)
final selectedBooksProvider = StateProvider<Set<String>>((_) => <String>{});

// ฟิลเตอร์/เรียงลำดับภายในหน้า
enum StatusFilter { all, available, reserved, borrowed, overdue }
final statusFilterProvider =
    StateProvider<StatusFilter>((_) => StatusFilter.all);

enum SortOption { relevance, ratingDesc, ratingAsc, titleAsc, titleDesc }
final sortOptionProvider =
    StateProvider<SortOption>((_) => SortOption.relevance);

/// -------------------- BODY ของหน้า Home --------------------
class HomePageBody extends ConsumerWidget {
  const HomePageBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final category = ref.watch(categoryProvider);
    final status = ref.watch(statusFilterProvider);
    final sort = ref.watch(sortOptionProvider);

    final booksAsync = ref.watch(pagedBooksProvider((query, category)));

    const chips = [
      'All',
      'Computer',
      'Business',
      'Sci-Tech',
      'Fantasy',
      'Classic',
      'YA',
      'Dystopia'
    ];

    return CustomScrollView(
      slivers: [
        // Search + Filter
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.tune),
                  onPressed: () => _openFilterSheet(context, ref),
                ),
              ],
            ),
          ),
        ),

        // Promo banner
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  // 🔧 withOpacity -> withValues เพื่อเลี่ยง deprecate
                  colors: [
                    Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: .6),
                    Theme.of(context).colorScheme.primary.withValues(alpha: .8),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Read For Fun - Borrow Books Today!',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
        ),

        // Category chips
        SliverToBoxAdapter(
          child: SingleChildScrollView(
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
                final selected =
                    (isAll && category.isEmpty) || category == value;
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
          ),
        ),

        // Grid
        booksAsync.when(
          data: (items) {
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
                itemBuilder: (_, i) => _BookCardWrapper(book: sorted[i]),
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
    );
  }

  void _openFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }
}

/// แยก wrapper เพื่ออัพเดตปุ่ม + และ favorite แบบเฉพาะตัว
class _BookCardWrapper extends ConsumerWidget {
  const _BookCardWrapper({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedBooksProvider);
    final isSelected = selected.contains(book.id);

    // ❤️ state ของ favorites
    final favIds = ref.watch(favoritesProvider);
    final isFav = favIds.contains(book.id);

    return BookCard(
      book,
      isSelected: isSelected,
      onAdd: () {
        final set = {...ref.read(selectedBooksProvider)};
        isSelected ? set.remove(book.id) : set.add(book.id);
        ref.read(selectedBooksProvider.notifier).state = set;
      },
      onTap: () {
        // ใส่การนำทางไปหน้า detail ถ้ามีเส้นทาง
        // context.push('/books/${book.id}');
      },

      // ✅ ใส่พารามิเตอร์ favorite ตามสัญญาใหม่ของ BookCard
      isFavorited: isFav,
      onToggleFavorite: () =>
          ref.read(favoritesProvider.notifier).toggle(book.id),
    );
  }
}

/// ---------- Filter Sheet ----------
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
        bottom: 16 + MediaQuery.of(context).padding.bottom,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Filter books',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ],
          ),
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
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(
      WidgetRef ref, StatusFilter v, String label, StatusFilter cur) {
    final selected = v == cur;
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => ref.read(statusFilterProvider.notifier).state = v,
    );
    // ignore: dead_code
  }

  Widget _sortTile(
      WidgetRef ref, SortOption opt, String label, SortOption cur) {
    return RadioListTile<SortOption>(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: opt,
      groupValue: cur,
      onChanged: (v) => ref.read(sortOptionProvider.notifier).state = v!,
      title: Text(label),
    );
  }
}

/// ---------- Empty / Error views ----------
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inbox_outlined, size: 42),
        const SizedBox(height: 8),
        Text('No books found',
            style: Theme.of(context).textTheme.titleMedium),
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
        const SizedBox(height: 12),
        FilledButton(onPressed: () {}, child: const Text('Retry')),
      ]),
    );
  }
}
