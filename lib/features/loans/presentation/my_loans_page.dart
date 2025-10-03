// lib/features/loans/presentation/my_loans_page.dart
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:library_booking/features/books/data/book_repo.dart';
import 'package:library_booking/features/books/domain/models/book.dart';
import 'package:library_booking/features/books/presentation/home_page.dart';
import 'package:library_booking/features/books/presentation/providers/selection_provider.dart';

// ใช้ Dio เดียวกับหน้า Login
import 'package:library_booking/core/dio_client.dart';
import 'package:library_booking/features/auth/data/session.dart';

class MyLoansPage extends ConsumerStatefulWidget {
  const MyLoansPage({super.key});

  @override
  ConsumerState<MyLoansPage> createState() => _MyLoansPageState();
}

class _MyLoansPageState extends ConsumerState<MyLoansPage> {
  bool _loading = false;

  Future<List<Book>> _fetchPicked() async {
    final selectedIds = ref.read(selectedBooksProvider);
    if (selectedIds.isEmpty) return const <Book>[];

    // ดึงหนังสือครั้งเดียวแล้วกรองด้วย id ที่เลือก
    final all = await ref
        .read(bookRepoProvider)
        .listBooks(query: '', category: '', page: 1, limit: 1000);

    return all.where((b) => selectedIds.contains(b.id)).toList();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() {}); // ให้ FutureBuilder ยิงใหม่
  }

  void _clearAll() {
    ref.read(selectedBooksProvider.notifier).state = <String>{};
    if (mounted) setState(() {});
  }

  void _removeOne(String id) {
    final set = {...ref.read(selectedBooksProvider)};
    set.remove(id);
    ref.read(selectedBooksProvider.notifier).state = set;
    if (mounted) setState(() {});
  }

  Future<void> _borrowSelected() async {
    final ids = ref.read(selectedBooksProvider).toList();
    if (ids.isEmpty || _loading) return;

    setState(() => _loading = true);
    try {
      final dio = createDio(Session.token);
      await dio.post('/loans/borrow', data: {'bookIds': ids});

      // ล้างรายการที่เลือก
      ref.read(selectedBooksProvider.notifier).state = <String>{};

      if (!mounted) return;
      await AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader, // ใช้ customHeader แทน
        customHeader: CircleAvatar(
          radius: 36,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(
            Icons.check_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 40,
          ),
        ),
        animType: AnimType.scale,
        dismissOnTouchOutside: false,
        dismissOnBackKeyPress: false,
        title: 'Borrowed!',
        desc: 'ทำรายการยืมสำเร็จแล้ว',
        btnOkText: 'ไปดูประวัติ',
        btnOkOnPress: () => context.go('/history'),
      ).show();
    } on DioException catch (e) {
      if (!mounted) return;
      await AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        customHeader: CircleAvatar(
          radius: 36,
          backgroundColor: Theme.of(context).colorScheme.error,
          child: Icon(
            Icons.close_rounded,
            color: Theme.of(context).colorScheme.onError,
            size: 40,
          ),
        ),
        animType: AnimType.scale,
        dismissOnTouchOutside: false,
        dismissOnBackKeyPress: false,
        title: 'Failed',
        desc: e.response?.data?.toString() ?? e.message ?? 'Borrow failed',
        btnOkText: 'ปิด',
        btnOkOnPress: () {},
      ).show();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(selectedBooksProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('My Loans'),
        actions: [
          if (selectedIds.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear all'),
              style: TextButton.styleFrom(foregroundColor: colors.error),
            ),
        ],
      ),
      body: selectedIds.isEmpty
          ? const _Empty()
          : RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Book>>(
                future: _fetchPicked(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return _Error(msg: '${snap.error}');
                  }
                  final items = snap.data ?? const <Book>[];
                  if (items.isEmpty) return const _Empty();

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final b = items[i];
                      return Dismissible(
                        key: ValueKey('loan_${b.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.delete_outline, color: colors.error),
                        ),
                        onDismissed: (_) => _removeOne(b.id),
                        child: _LoanTile(
                          book: b,
                          onRemove: () => _removeOne(b.id),
                          onOpen: () => context.push('/books/${b.id}'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
      bottomNavigationBar: selectedIds.isEmpty
          ? null
          : _BottomBar(
              count: selectedIds.length,
              loading: _loading,
              onBorrow: _borrowSelected,
            ),
    );
  }
}

/* ---------- Widgets ---------- */

class _LoanTile extends StatelessWidget {
  const _LoanTile({
    required this.book,
    required this.onRemove,
    required this.onOpen,
  });

  final Book book;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  book.coverUrl,
                  width: 40,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 40,
                    height: 56,
                    child: Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: colors.error,
                onPressed: onRemove,
                tooltip: 'Remove',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.count,
    required this.onBorrow,
    required this.loading,
  });

  final int count;
  final VoidCallback onBorrow;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, -2),
              color: Colors.black12,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined),
                  const SizedBox(width: 8),
                  Text('Selected: ',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: loading ? null : onBorrow,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(loading ? 'Processing...' : 'Borrow'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.menu_book_outlined, size: 64),
        const SizedBox(height: 8),
        Text('No selected books',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Go back and select some books',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.msg});
  final String msg;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(height: 8),
          Text('Error', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(msg, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}
