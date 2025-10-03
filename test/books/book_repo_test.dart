import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:library_booking/features/books/data/book_api.dart';
import 'package:library_booking/features/books/data/book_repo.dart';
import 'package:library_booking/features/books/domain/models/book.dart';

/// In-memory API สำหรับเทสต์: ไม่ยิงเน็ตจริง
class _MockBookApi extends BookApi {
  _MockBookApi() : super(Dio());

  @override
  Future<List<Book>> getBooks({
    String query = '',
    String category = '',
    int page = 1,
    int limit = 20,
  }) async {
    // ชุดข้อมูลจำลองเล็ก ๆ (ของจริงใช้ mock server)
    final data = <Book>[
      const Book(
        id: 'b1',
        title: 'Clean Code',
        author: 'Robert C. Martin',
        coverUrl: 'https://covers.openlibrary.org/b/isbn/9780132350884-L.jpg',
        isbn: '9780132350884',
        rating: 4.8,
        categories: ['Software', 'Development'],
        status: BookStatus.available,
      ),
      const Book(
        id: 'hp_1',
        title: "Harry Potter and the Philosopher's Stone",
        author: 'J.K. Rowling',
        coverUrl: 'https://covers.openlibrary.org/b/isbn/9780747532699-L.jpg',
        isbn: '9780747532699',
        rating: 4.9,
        categories: ['Fantasy', 'Novel'],
        status: BookStatus.available,
      ),
    ];

    Iterable<Book> list = data;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((b) =>
          b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.isbn.contains(q));
    }
    if (category.isNotEmpty) {
      list = list.where((b) => b.categories.contains(category));
    }

    final items = list.toList();
    final start = (page - 1) * limit;
    final end = (start + limit).clamp(0, items.length);
    return start < items.length ? items.sublist(start, end) : <Book>[];
  }

  @override
  Future<Book> getBook(String id) async {
    return const Book(
      id: 'b1',
      title: 'Clean Code',
      author: 'Robert C. Martin',
      coverUrl: 'https://covers.openlibrary.org/b/isbn/9780132350884-L.jpg',
      isbn: '9780132350884',
      rating: 4.8,
      categories: ['Software', 'Development'],
      status: BookStatus.available,
    );
  }

  // เมธอดพวก reserve/borrow/return ไม่จำเป็นสำหรับเทสต์นี้ ปล่อยใช้ของ superclass ได้
}

void main() {
  group('BookRepo', () {
    test('listBooks() คืนรายการตาม query/category/page/limit ได้', () async {
      final repo = BookRepo(_MockBookApi());

      final all = await repo.listBooks(page: 1, limit: 10);
      expect(all, isNotEmpty);

      final onlySoftware = await repo.listBooks(category: 'Software');
      expect(onlySoftware.every((b) => b.categories.contains('Software')), isTrue);

      final searchHarry = await repo.listBooks(query: 'harry');
      expect(searchHarry.any((b) => b.title.toLowerCase().contains('harry')), isTrue);
    });

    test('getBook() คืน Book เดียว', () async {
      final repo = BookRepo(_MockBookApi());
      final b = await repo.getBook('b1');
      expect(b.id, 'b1');
      expect(b.title, isNotEmpty);
    });
  });
}
