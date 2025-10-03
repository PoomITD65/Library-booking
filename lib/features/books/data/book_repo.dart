import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dio_client.dart';
import '../../auth/data/session.dart';
import 'book_api.dart';
import '../domain/models/book.dart';

final bookRepoProvider = Provider<BookRepo>((ref) {
  final dio = createDio(() async {
    return await Session.token();
  });
  return BookRepo(BookApi(dio));
});

class BookRepo {
  BookRepo(this.api);
  final BookApi api;

  Future<List<Book>> listBooks({String query = '', String category = '', int page = 1, int limit = 20}) {
    return api.getBooks(query: query, category: category, page: page, limit: limit);
  }

  Future<Book> getBook(String id) => api.getBook(id);

  Future<void> reserve(String bookId) => api.reserve(bookId);

  Future<void> borrow(String bookId) => api.borrow(bookId);

  // NOTE: ใน mock ผมทำ returns รับ loanId; repo จริงควร map book->loan
  Future<void> returnByLoan(String loanId) => api.returnLoan(loanId);
}
