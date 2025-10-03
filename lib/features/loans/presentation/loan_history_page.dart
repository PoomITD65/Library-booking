import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import '../../../core/dio_client.dart';
import '../../auth/data/session.dart';
import '../../loans/data/loan_repo.dart';

/// สถานะในประวัติ
enum LoanHistoryStatus { borrowed, returned, overdue }

LoanHistoryStatus _statusFromString(String s) {
  switch (s.toLowerCase()) {
    case 'returned':
      return LoanHistoryStatus.returned;
    case 'overdue':
      return LoanHistoryStatus.overdue;
    default:
      return LoanHistoryStatus.borrowed;
  }
}

/// โมเดลประวัติการยืม
class LoanHistoryItem {
  final String id;
  final String bookId;
  final String title;
  final String author;
  final String coverUrl;
  final LoanHistoryStatus status;
  final DateTime borrowedAt;
  final DateTime? dueAt;
  final DateTime? returnedAt;

  LoanHistoryItem({
    required this.id,
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.status,
    required this.borrowedAt,
    this.dueAt,
    this.returnedAt,
  });

  factory LoanHistoryItem.fromJson(Map<String, dynamic> j) {
    return LoanHistoryItem(
      id: j['id'] as String,
      bookId: j['bookId'] as String,
      title: j['title'] as String,
      author: j['author'] as String,
      coverUrl: j['coverUrl'] as String,
      status: _statusFromString(j['status'] as String),
      borrowedAt: DateTime.parse(j['borrowedAt'] as String),
      dueAt: j['dueAt'] != null ? DateTime.parse(j['dueAt']) : null,
      returnedAt: j['returnedAt'] != null ? DateTime.parse(j['returnedAt']) : null,
    );
  }
}

/// ใช้ Dio กลางของโปรเจกต์
final _dioProvider = Provider<Dio>((ref) => createDio(Session.token));

/// ดึงประวัติทั้งหมด
final historyProvider =
    FutureProvider.autoDispose<List<LoanHistoryItem>>((ref) async {
  final dio = ref.read(_dioProvider);
  final resp = await dio.get('/loans/history'); // <-- endpoint mock
  final list = (resp.data as List).cast<Map<String, dynamic>>();
  return list.map(LoanHistoryItem.fromJson).toList();
});

/// ฟิลเตอร์ที่ UI ใช้
enum HistoryFilter { all, borrowed, returned, overdue }
final historyFilterProvider =
    StateProvider<HistoryFilter>((_) => HistoryFilter.all);

class LoanHistoryPage extends ConsumerWidget {
  const LoanHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final filter = ref.watch(historyFilterProvider);
    final async = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          // ฟิลเตอร์ด้านบน
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _chip(ref, HistoryFilter.all, 'All', filter),
                _chip(ref, HistoryFilter.borrowed, 'Borrowed', filter),
                _chip(ref, HistoryFilter.returned, 'Returned', filter),
                _chip(ref, HistoryFilter.overdue, 'Overdue', filter),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(error: '$e'),
              data: (items) {
                // กรองตาม filter
                Iterable<LoanHistoryItem> list = items;
                switch (filter) {
                  case HistoryFilter.borrowed:
                    list = list.where(
                        (e) => e.status == LoanHistoryStatus.borrowed);
                    break;
                  case HistoryFilter.returned:
                    list = list.where(
                        (e) => e.status == LoanHistoryStatus.returned);
                    break;
                  case HistoryFilter.overdue:
                    list = list
                        .where((e) => e.status == LoanHistoryStatus.overdue);
                    break;
                  case HistoryFilter.all:
                    break;
                }

                final sorted = list.toList()
                  ..sort((a, b) => b.borrowedAt.compareTo(a.borrowedAt));

                if (sorted.isEmpty) return const _EmptyView();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final h = sorted[i];
                    return _HistoryTile(
                      item: h,
                      onReturned: () {
                        // หลังคืนเสร็จ → refresh
                        ref.invalidate(historyProvider);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ให้ bottom nav ไปที่ tab เดิม (index 2)
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border), label: 'Favorites'),
          NavigationDestination(
              icon: Icon(Icons.history), label: 'History'),
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
              /* already here */
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
      ),
    );
  }

  Widget _chip(WidgetRef ref, HistoryFilter me, String label,
      HistoryFilter current) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: me == current,
        label: Text(label),
        onSelected: (_) =>
            ref.read(historyFilterProvider.notifier).state = me,
      ),
    );
  }
}

class _HistoryTile extends ConsumerStatefulWidget {
  const _HistoryTile({required this.item, required this.onReturned});
  final LoanHistoryItem item;
  final VoidCallback onReturned;

  @override
  ConsumerState<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends ConsumerState<_HistoryTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = Theme.of(context).colorScheme;

    IconData statusIcon;
    String statusText;
    Color badgeColor;

    switch (item.status) {
      case LoanHistoryStatus.borrowed:
        statusIcon = Icons.menu_book_outlined;
        statusText = 'Borrowed';
        badgeColor = Colors.blue;
        break;
      case LoanHistoryStatus.returned:
        statusIcon = Icons.check_circle_outline;
        statusText = 'Returned';
        badgeColor = Colors.green;
        break;
      case LoanHistoryStatus.overdue:
        statusIcon = Icons.warning_amber_outlined;
        statusText = 'Overdue';
        badgeColor = Colors.red;
        break;
    }

    final canReturn = item.status == LoanHistoryStatus.borrowed ||
        item.status == LoanHistoryStatus.overdue;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            item.coverUrl,
            width: 48,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                width: 48, height: 64, color: colors.surfaceVariant),
          ),
        ),
        title: Text(item.title,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.author),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Badge(
                    icon: statusIcon,
                    label: statusText,
                    color: badgeColor),
                Text('Borrowed: ${_fmt(item.borrowedAt)}',
                    style: Theme.of(context).textTheme.bodySmall),
                if (item.dueAt != null)
                  Text('Due: ${_fmt(item.dueAt!)}',
                      style: Theme.of(context).textTheme.bodySmall),
                if (item.returnedAt != null)
                  Text('Returned: ${_fmt(item.returnedAt!)}',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
        trailing: canReturn
            ? FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final repo = ref.read(loanRepoProvider);
                          final updated = await repo
                              .returnByHistoryIds([item.id]);
                          if (updated > 0 && mounted) {
                            await AwesomeDialog(
                              context: context,
                              dialogType: DialogType.noHeader,
                              animType: AnimType.scale,
                              dismissOnBackKeyPress: false,
                              dismissOnTouchOutside: false,
                              customHeader: CircleAvatar(
                                radius: 30,
                                backgroundColor: colors.primary,
                                child: Icon(Icons.check_rounded,
                                    size: 34,
                                    color: colors.onPrimary),
                              ),
                              title: 'Returned',
                              desc: 'Book returned successfully.',
                              btnOkOnPress: () {},
                            ).show();
                            widget.onReturned(); // refresh list
                          } else if (mounted) {
                            await AwesomeDialog(
                              context: context,
                              dialogType: DialogType.info,
                              animType: AnimType.scale,
                              title: 'No change',
                              desc: 'There was nothing to update.',
                              btnOkOnPress: () {},
                            ).show();
                          }
                        } catch (e) {
                          if (!mounted) return;
                          await AwesomeDialog(
                            context: context,
                            dialogType: DialogType.error,
                            animType: AnimType.scale,
                            title: 'Return failed',
                            desc: '$e',
                            btnOkOnPress: () {},
                          ).show();
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Return'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Badge extends StatelessWidget {
  const _Badge(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ]),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.history, size: 42),
        const SizedBox(height: 8),
        Text('No history yet',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Your borrow/return history will appear here',
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
