class Loan {
  final String id, bookId, userId;
  final DateTime borrowedAt, dueAt;
  final DateTime? returnedAt;
  Loan({required this.id, required this.bookId, required this.userId, required this.borrowedAt, required this.dueAt, this.returnedAt});
  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
    id: j['id'], bookId: j['bookId'], userId: j['userId'],
    borrowedAt: DateTime.parse(j['borrowedAt']),
    dueAt: DateTime.parse(j['dueAt']),
    returnedAt: j['returnedAt']!=null? DateTime.parse(j['returnedAt']) : null,
  );
}

class LoanEntry {
  final String id;
  final String bookId;
  final String title;
  final String author;
  final String coverUrl;
  final String status;
  final String borrowedAt;
  final String dueAt;
  final String? returnedAt;

  LoanEntry({
    required this.id,
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.status,
    required this.borrowedAt,
    required this.dueAt,
    required this.returnedAt,
  });

  factory LoanEntry.fromJson(Map<String, dynamic> json) => LoanEntry(
    id: json['id'] as String,
    bookId: json['bookId'] as String,
    title: json['title'] as String,
    author: json['author'] as String,
    coverUrl: json['coverUrl'] as String,
    status: json['status'] as String,
    borrowedAt: json['borrowedAt'] as String,
    dueAt: json['dueAt'] as String,
    returnedAt: json['returnedAt'] as String?,
  );
}
