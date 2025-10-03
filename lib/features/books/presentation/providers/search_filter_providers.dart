import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/book_repo.dart';
import '../../domain/models/book.dart';

// category: '' => All, otherwise exact match one of categories
final categoryProvider = StateProvider<String>((_) => '');

// search with debounce 350ms
class _SearchQuery extends StateNotifier<String> {
  _SearchQuery() : super('');
  Timer? _t;
  void set(String v) {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 350), () => state = v);
  }
}
final searchQueryProvider = StateNotifierProvider<_SearchQuery, String>(
  (ref) => _SearchQuery(),
);

// list provider (page 1 — สามารถต่อยอด infinite scroll ทีหลัง)
final pagedBooksProvider = FutureProvider.family<List<Book>, (String query, String category)>(
  (ref, args) {
    final (q, c) = args;
    final repo = ref.watch(bookRepoProvider);
    return repo.listBooks(query: q, category: c, page: 1, limit: 50);
  },
);
