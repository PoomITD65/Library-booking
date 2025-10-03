import 'package:flutter/foundation.dart';

enum BookStatus { available, reserved, borrowed, overdue }

BookStatus _statusFromString(String s) {
  switch (s) {
    case 'available':
      return BookStatus.available;
    case 'reserved':
      return BookStatus.reserved;
    case 'borrowed':
      return BookStatus.borrowed;
    case 'overdue':
      return BookStatus.overdue;
    default:
      return BookStatus.available;
  }
}

@immutable
class Book {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String isbn;
  final double rating;
  final List<String> categories;
  final BookStatus status;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.isbn,
    required this.rating,
    required this.categories,
    required this.status,
  });

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        author: j['author'] as String,
        coverUrl: j['coverUrl'] as String,
        isbn: j['isbn'] as String,
        rating: (j['rating'] as num).toDouble(),
        categories: (j['categories'] as List).cast<String>(),
        status: j['status'] is String
            ? _statusFromString(j['status'] as String)
            : BookStatus.available,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'coverUrl': coverUrl,
        'isbn': isbn,
        'rating': rating,
        'categories': categories,
        'status': status.name,
      };

  // ✅ equality แบบง่าย: เทียบที่ id
  @override
  bool operator ==(Object other) => other is Book && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
