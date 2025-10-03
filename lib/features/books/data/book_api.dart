import 'package:dio/dio.dart';
import '../domain/models/book.dart';

class BookApi {
  BookApi(this._dio);
  final Dio _dio;

  Future<List<Book>> getBooks({String query = '', String category = '', int page = 1, int limit = 20}) async {
    final r = await _dio.get('/books', queryParameters: {
      'query': query,
      'category': category,
      'page': page,
      'limit': limit,
    });
    return (r.data as List).map((e) => Book.fromJson(e)).toList();
  }

  Future<Book> getBook(String id) async {
    final r = await _dio.get('/books/$id');
    return Book.fromJson(r.data);
  }

  Future<void> reserve(String bookId) async => _dio.post('/reservations', data: {"bookId": bookId});
  Future<void> borrow(String bookId) async => _dio.post('/loans', data: {"bookId": bookId});
  Future<void> returnLoan(String loanId) async => _dio.post('/returns', data: {"loanId": loanId});
}
