// tool/mock_server.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

/* ----------------------------------------------------------
   In-memory state
---------------------------------------------------------- */

// เก็บผู้ใช้ที่สมัครไว้ในหน่วยความจำ (mock)
final List<Map<String, dynamic>> _mockUsers = [
  {
    'id': 'u1',
    'name': 'Mock User',
    'email': 'user@example.com',
    'password': '123456',
  },

    {
    'id': 'u2',
    'name': 'Lukgate',
    'email': 'user1@example.com',
    'password': '123456',
  },
];

// ประวัติที่เกิดจากการยืม “ระหว่างรัน” (จะหายเมื่อรีสตาร์ท)
final List<Map<String, dynamic>> _loanHistory = [];

// หนังสือแบบ global (แก้สถานะแล้วคงอยู่จนกว่าจะรีสตาร์ท)
final List<Map<String, dynamic>> _books = _allBooks();

/* ----------------------------------------------------------
   Entry
---------------------------------------------------------- */
Future<void> main(List<String> args) async {
  final port = int.tryParse(args.isNotEmpty ? args.first : '8000') ?? 8000;

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware)
      .addHandler(_router);

  final server = await io.serve(handler, 'localhost', port);
  print('✅ Mock server listening on http://localhost:$port');
}

/* ----------------------------------------------------------
   CORS
---------------------------------------------------------- */
Middleware get _corsMiddleware => (inner) {
      return (req) async {
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final res = await inner(req);
        return res.change(headers: _corsHeaders);
      };
    };

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};

/* ----------------------------------------------------------
   Mock datasets (seed)
---------------------------------------------------------- */
final List<Map<String, dynamic>> _mockLoanHistory = [
  {
    "id": "h_001",
    "bookId": "hp_1",
    "title": "Harry Potter and the Philosopher's Stone",
    "author": "J.K. Rowling",
    "coverUrl": "https://covers.openlibrary.org/b/id/7884866-L.jpg",
    "status": "returned",
    "borrowedAt": "2025-09-02",
    "dueAt": "2025-09-16",
    "returnedAt": "2025-09-12"
  },
  {
    "id": "h_002",
    "bookId": "hp_2",
    "title": "Harry Potter and the Chamber of Secrets",
    "author": "J.K. Rowling",
    "coverUrl": "https://covers.openlibrary.org/b/id/7884867-L.jpg",
    "status": "borrowed",
    "borrowedAt": "2025-10-01",
    "dueAt": "2025-10-15",
    "returnedAt": null
  },
  {
    "id": "h_003",
    "bookId": "hp_3",
    "title": "Harry Potter and the Prisoner of Azkaban",
    "author": "J.K. Rowling",
    "coverUrl": "https://covers.openlibrary.org/b/id/7884868-L.jpg",
    "status": "overdue",
    "borrowedAt": "2025-09-10",
    "dueAt": "2025-09-24",
    "returnedAt": null
  },
];

/* ----------------------------------------------------------
   Router
---------------------------------------------------------- */
Future<Response> _router(Request req) async {
  final path = req.url.path; // eg. api/books, api/loans/history
  final method = req.method;

  /* ---------- AUTH: LOGIN ---------- */
  if (path == 'api/auth/login' && method == 'POST') {
    final body = await req.readAsString();
    final data = jsonDecode(body);
    final email = (data['email'] ?? '').toString();
    final password = (data['password'] ?? '').toString();

    final u = _mockUsers.firstWhere(
      (x) => x['email'] == email && x['password'] == password,
      orElse: () => {},
    );

    if (u.isEmpty) {
      return Response(
        401,
        body: jsonEncode({'message': 'Invalid credentials'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.ok(
      jsonEncode({
        'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        'user': {'id': u['id'], 'name': u['name'], 'email': u['email']}
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /* ---------- AUTH: REGISTER ---------- */
  if (path == 'api/auth/register' && method == 'POST') {
    final body = await req.readAsString();
    final data = jsonDecode(body);

    final name = (data['name'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final password = (data['password'] ?? '').toString();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      return Response(
        400,
        body: jsonEncode({'message': 'Missing fields'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (_mockUsers.any((u) => u['email'] == email)) {
      return Response(
        409,
        body: jsonEncode({'message': 'Email already exists'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final user = {
      'id': 'u_${DateTime.now().microsecondsSinceEpoch}',
      'name': name,
      'email': email,
      'password': password,
    };
    _mockUsers.add(user);

    return Response.ok(
      jsonEncode({
        'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        'user': {'id': user['id'], 'name': name, 'email': email}
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /* ---------- LOANS: HISTORY ---------- */
  if (path == 'api/loans/history' && method == 'GET') {
    final status = req.url.queryParameters['status']?.toLowerCase();

    // รวม mock เริ่มต้น + ประวัติที่เพิ่งยืม
    final all = <Map<String, dynamic>>[
      ..._mockLoanHistory,
      ..._loanHistory,
    ];

    var data = all;
    if (status != null && status.isNotEmpty) {
      data = data
          .where((e) => (e['status'] as String).toLowerCase() == status)
          .toList();
    }

    // เรียงใหม่ล่าสุดก่อน
    data.sort((a, b) =>
        (b['borrowedAt'] as String).compareTo(a['borrowedAt'] as String));

    return Response.ok(jsonEncode(data),
        headers: {'Content-Type': 'application/json'});
  }

  /* ---------- LOANS: BORROW (เพิ่มประวัติ + อัปเดตสถานะหนังสือ) ---------- */
  if (path == 'api/loans/borrow' && method == 'POST') {
    final body = await req.readAsString();
    final parsed = jsonDecode(body) as Map<String, dynamic>;
    final ids = (parsed['bookIds'] as List).cast<String>();

    final now = DateTime.now();
    final due = now.add(const Duration(days: 14));

    final borrowed = <Map<String, dynamic>>[];

    for (final id in ids) {
      final idx = _books.indexWhere((e) => e['id'] == id);
      if (idx == -1) continue;

      // อัปเดตสถานะหนังสือในหน่วยความจำ
      _books[idx]['status'] = 'borrowed';

      final b = _books[idx];
      final item = {
        "id": "h_${DateTime.now().microsecondsSinceEpoch}",
        "bookId": b['id'],
        "title": b['title'],
        "author": b['author'],
        "coverUrl": b['coverUrl'],
        "status": "borrowed",
        "borrowedAt": now.toIso8601String().substring(0, 10),
        "dueAt": due.toIso8601String().substring(0, 10),
        "returnedAt": null,
      };
      _loanHistory.add(item);
      borrowed.add(item);
    }

    return Response.ok(
      jsonEncode({"ok": true, "added": borrowed.length}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /* ---------- LOANS: RETURN ---------- */
// POST /api/loans/return
// body: { "historyIds": ["h_123", ...] } | { "bookIds": ["hp_1", ...] }
  if (path == 'api/loans/return' && method == 'POST') {
    final body = await req.readAsString();
    final parsed = jsonDecode(body) as Map<String, dynamic>;

    final historyIds =
        (parsed['historyIds'] as List?)?.cast<String>() ?? const <String>[];
    final bookIds =
        (parsed['bookIds'] as List?)?.cast<String>() ?? const <String>[];

    final today = DateTime.now().toIso8601String().substring(0, 10);

    int updated = 0;

    // helper: คืน 1 รายการ
    bool _returnOne(Map<String, dynamic> it) {
      final st = (it['status'] as String).toLowerCase();
      if (st != 'borrowed' && st != 'overdue') return false;
      it['status'] = 'returned';
      it['returnedAt'] = today;

      // อัปเดตสถานะหนังสือ
      final idx = _books.indexWhere((b) => b['id'] == it['bookId']);
      if (idx != -1) _books[idx]['status'] = 'available';
      return true;
    }

    // 1) ถ้ามี historyIds → จิ้มคืนทีละรายการ
    if (historyIds.isNotEmpty) {
      for (final hid in historyIds) {
        // ทั้ง mock เริ่มต้น + ที่เกิดจากการยืมจริง
        final all = [..._mockLoanHistory, ..._loanHistory];
        final entry = all.firstWhere(
          (e) => e['id'] == hid,
          orElse: () => {},
        );
        if (entry.isNotEmpty) {
          if (_returnOne(entry)) updated++;
        }
      }
    }

    // 2) ถ้ามี bookIds → หา latest entry ของเล่มนั้นที่ยังไม่คืน
    if (bookIds.isNotEmpty) {
      final all = [..._mockLoanHistory, ..._loanHistory];
      for (final bid in bookIds) {
        final entries = all.where((e) => e['bookId'] == bid).toList()
          ..sort((a, b) =>
              (b['borrowedAt'] as String).compareTo(a['borrowedAt'] as String));
        if (entries.isNotEmpty) {
          if (_returnOne(entries.first)) updated++;
        }
      }
    }

    return Response.ok(
      jsonEncode({"ok": true, "updated": updated}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /* ---------- BOOK: DETAIL ---------- */
  if (path.startsWith('api/books/') && method == 'GET') {
    final id = path.substring('api/books/'.length);
    final match = _books.where((b) => b['id'] == id);
    if (match.isEmpty) {
      return Response.notFound(
        jsonEncode({'error': 'Book not found', 'id': id}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    return Response.ok(jsonEncode(match.first),
        headers: {'Content-Type': 'application/json'});
  }

  /* ---------- BOOK: LIST ---------- */
  if (path == 'api/books' && method == 'GET') {
    final qp = req.url.queryParameters;
    final query = (qp['query'] ?? '').toLowerCase();
    final category = (qp['category'] ?? '').trim();
    final page = int.tryParse(qp['page'] ?? '1') ?? 1;
    final limit = int.tryParse(qp['limit'] ?? '20') ?? 20;

    Iterable<Map<String, dynamic>> filtered = _books;

    if (query.isNotEmpty) {
      filtered = filtered.where((b) =>
          (b['title'] as String).toLowerCase().contains(query) ||
          (b['author'] as String).toLowerCase().contains(query) ||
          (b['isbn'] as String).toLowerCase().contains(query));
    }
    if (category.isNotEmpty) {
      filtered =
          filtered.where((b) => (b['categories'] as List).contains(category));
    }

    final items = filtered.toList();
    final start = (page - 1) * limit;
    final end = (start + limit).clamp(0, items.length);
    final slice = start < items.length
        ? items.sublist(start, end)
        : <Map<String, dynamic>>[];

    return Response.ok(jsonEncode(slice),
        headers: {'Content-Type': 'application/json'});
  }

  // 404
  return Response.notFound(
    jsonEncode({'error': 'Not found', 'path': req.url.toString()}),
    headers: {'Content-Type': 'application/json'},
  );
}

/// -------------------- Data --------------------
/// รวมรายการหนังสือไว้ที่เดียว ใช้ได้ทั้ง list และ detail
List<Map<String, dynamic>> _allBooks() {
  final books = <Map<String, dynamic>>[
    // ---------- Fantasy: Harry Potter (1–7) ----------
    {
      "id": "hp_1",
      "title": "Harry Potter and the Philosopher's Stone",
      "author": "J.K. Rowling",
      "isbn": "9780747532699",
      "rating": 4.9,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780747532699-L.jpg"
    },
    {
      "id": "hp_2",
      "title": "Harry Potter and the Chamber of Secrets",
      "author": "J.K. Rowling",
      "isbn": "9780747538493",
      "rating": 4.8,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780747538493-L.jpg"
    },
    {
      "id": "hp_3",
      "title": "Harry Potter and the Prisoner of Azkaban",
      "author": "J.K. Rowling",
      "isbn": "9780747542155",
      "rating": 4.9,
      "categories": ["Fantasy", "Novel"],
      "status": "borrowed",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780747542155-L.jpg"
    },
    {
      "id": "hp_4",
      "title": "Harry Potter and the Goblet of Fire",
      "author": "J.K. Rowling",
      "isbn": "9780747546245",
      "rating": 4.8,
      "categories": ["Fantasy", "Novel"],
      "status": "reserved",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780747546245-L.jpg"
    },
    {
      "id": "hp_5",
      "title": "Harry Potter and the Order of the Phoenix",
      "author": "J.K. Rowling",
      "isbn": "9780747551003",
      "rating": 4.7,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780747551003-L.jpg"
    },
    {
      "id": "hp_6",
      "title": "Harry Potter and the Half-Blood Prince",
      "author": "J.K. Rowling",
      "isbn": "9780747581086",
      "rating": 4.8,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780747581086-L.jpg"
    },
    {
      "id": "hp_7",
      "title": "Harry Potter and the Deathly Hallows",
      "author": "J.K. Rowling",
      "isbn": "9780747591054",
      "rating": 4.9,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780747591054-L.jpg"
    },

    // ---------- Tolkien: LOTR + Hobbit ----------
    {
      "id": "lotr_1",
      "title": "The Fellowship of the Ring",
      "author": "J.R.R. Tolkien",
      "isbn": "9780261102354",
      "rating": 4.9,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780261102354-L.jpg"
    },
    {
      "id": "lotr_2",
      "title": "The Two Towers",
      "author": "J.R.R. Tolkien",
      "isbn": "9780261102361",
      "rating": 4.9,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780261102361-L.jpg"
    },
    {
      "id": "lotr_3",
      "title": "The Return of the King",
      "author": "J.R.R. Tolkien",
      "isbn": "9780261102378",
      "rating": 4.9,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780261102378-L.jpg"
    },
    {
      "id": "hobbit",
      "title": "The Hobbit",
      "author": "J.R.R. Tolkien",
      "isbn": "9780261102217",
      "rating": 4.8,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780261102217-L.jpg"
    },

    // ---------- Frank Herbert: Dune (core 6) ----------
    {
      "id": "dune_1",
      "title": "Dune",
      "author": "Frank Herbert",
      "isbn": "9780441013593",
      "rating": 4.7,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780441013593-L.jpg"
    },
    {
      "id": "dune_2",
      "title": "Dune Messiah",
      "author": "Frank Herbert",
      "isbn": "9780441172696",
      "rating": 4.3,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780441172696-L.jpg"
    },
    {
      "id": "dune_3",
      "title": "Children of Dune",
      "author": "Frank Herbert",
      "isbn": "9780441104024",
      "rating": 4.2,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780441104024-L.jpg"
    },
    {
      "id": "dune_4",
      "title": "God Emperor of Dune",
      "author": "Frank Herbert",
      "isbn": "9780441104031",
      "rating": 4.2,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780441104031-L.jpg"
    },
    {
      "id": "dune_5",
      "title": "Heretics of Dune",
      "author": "Frank Herbert",
      "isbn": "9780441328000",
      "rating": 4.1,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780441328000-L.jpg"
    },
    {
      "id": "dune_6",
      "title": "Chapterhouse: Dune",
      "author": "Frank Herbert",
      "isbn": "9780441102679",
      "rating": 4.1,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780441102679-L.jpg"
    },

    // ---------- Isaac Asimov: Foundation (7) ----------
    {
      "id": "foundation_1",
      "title": "Foundation",
      "author": "Isaac Asimov",
      "isbn": "9780553293357",
      "rating": 4.4,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553293357-L.jpg"
    },
    {
      "id": "foundation_2",
      "title": "Foundation and Empire",
      "author": "Isaac Asimov",
      "isbn": "9780553293371",
      "rating": 4.3,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553293371-L.jpg"
    },
    {
      "id": "foundation_3",
      "title": "Second Foundation",
      "author": "Isaac Asimov",
      "isbn": "9780553293364",
      "rating": 4.3,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553293364-L.jpg"
    },
    {
      "id": "foundation_4",
      "title": "Foundation’s Edge",
      "author": "Isaac Asimov",
      "isbn": "9780553293388",
      "rating": 4.2,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553293388-L.jpg"
    },
    {
      "id": "foundation_5",
      "title": "Foundation and Earth",
      "author": "Isaac Asimov",
      "isbn": "9780553587579",
      "rating": 4.2,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553587579-L.jpg"
    },
    {
      "id": "foundation_6",
      "title": "Prelude to Foundation",
      "author": "Isaac Asimov",
      "isbn": "9780553278392",
      "rating": 4.1,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553278392-L.jpg"
    },
    {
      "id": "foundation_7",
      "title": "Forward the Foundation",
      "author": "Isaac Asimov",
      "isbn": "9780553803709",
      "rating": 4.1,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553803709-L.jpg"
    },

    // ---------- A Song of Ice and Fire ----------
    {
      "id": "asoiaf_1",
      "title": "A Game of Thrones",
      "author": "George R. R. Martin",
      "isbn": "9780553103540",
      "rating": 4.7,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553103540-L.jpg"
    },
    {
      "id": "asoiaf_2",
      "title": "A Clash of Kings",
      "author": "George R. R. Martin",
      "isbn": "9780553108033",
      "rating": 4.6,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553108033-L.jpg"
    },
    {
      "id": "asoiaf_3",
      "title": "A Storm of Swords",
      "author": "George R. R. Martin",
      "isbn": "9780553106633",
      "rating": 4.8,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553106633-L.jpg"
    },
    {
      "id": "asoiaf_4",
      "title": "A Feast for Crows",
      "author": "George R. R. Martin",
      "isbn": "9780553801507",
      "rating": 4.1,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553801507-L.jpg"
    },
    {
      "id": "asoiaf_5",
      "title": "A Dance with Dragons",
      "author": "George R. R. Martin",
      "isbn": "9780553801477",
      "rating": 4.2,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553801477-L.jpg"
    },

    // ---------- Brandon Sanderson ----------
    {
      "id": "stormlight_1",
      "title": "The Way of Kings",
      "author": "Brandon Sanderson",
      "isbn": "9780765326355",
      "rating": 4.8,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780765326355-L.jpg"
    },
    {
      "id": "stormlight_2",
      "title": "Words of Radiance",
      "author": "Brandon Sanderson",
      "isbn": "9780765326362",
      "rating": 4.8,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780765326362-L.jpg"
    },
    {
      "id": "stormlight_3",
      "title": "Oathbringer",
      "author": "Brandon Sanderson",
      "isbn": "9780765326379",
      "rating": 4.7,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780765326379-L.jpg"
    },
    {
      "id": "stormlight_4",
      "title": "Rhythm of War",
      "author": "Brandon Sanderson",
      "isbn": "9780765326386",
      "rating": 4.6,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780765326386-L.jpg"
    },
    {
      "id": "mistborn_1",
      "title": "Mistborn: The Final Empire",
      "author": "Brandon Sanderson",
      "isbn": "9780765311788",
      "rating": 4.6,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780765311788-L.jpg"
    },
    {
      "id": "mistborn_2",
      "title": "The Well of Ascension",
      "author": "Brandon Sanderson",
      "isbn": "9780765316882",
      "rating": 4.5,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780765316882-L.jpg"
    },
    {
      "id": "mistborn_3",
      "title": "The Hero of Ages",
      "author": "Brandon Sanderson",
      "isbn": "9780765316899",
      "rating": 4.6,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780765316899-L.jpg"
    },

    // ---------- YA / Dystopia / Adventure ----------
    {
      "id": "hunger_1",
      "title": "The Hunger Games",
      "author": "Suzanne Collins",
      "isbn": "9780439023528",
      "rating": 4.5,
      "categories": ["Dystopia", "YA"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780439023528-L.jpg"
    },
    {
      "id": "hunger_2",
      "title": "Catching Fire",
      "author": "Suzanne Collins",
      "isbn": "9780439023498",
      "rating": 4.5,
      "categories": ["Dystopia", "YA"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780439023498-L.jpg"
    },
    {
      "id": "hunger_3",
      "title": "Mockingjay",
      "author": "Suzanne Collins",
      "isbn": "9780439023511",
      "rating": 4.3,
      "categories": ["Dystopia", "YA"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780439023511-L.jpg"
    },
    {
      "id": "percy_1",
      "title": "Percy Jackson: The Lightning Thief",
      "author": "Rick Riordan",
      "isbn": "9780786838653",
      "rating": 4.5,
      "categories": ["Fantasy", "YA"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780786838653-L.jpg"
    },
    {
      "id": "percy_2",
      "title": "Percy Jackson: The Sea of Monsters",
      "author": "Rick Riordan",
      "isbn": "9781423103349",
      "rating": 4.4,
      "categories": ["Fantasy", "YA"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781423103349-L.jpg"
    },
    {
      "id": "percy_3",
      "title": "Percy Jackson: The Titan's Curse",
      "author": "Rick Riordan",
      "isbn": "9781423101451",
      "rating": 4.4,
      "categories": ["Fantasy", "YA"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781423101451-L.jpg"
    },
    {
      "id": "percy_4",
      "title": "Percy Jackson: The Battle of the Labyrinth",
      "author": "Rick Riordan",
      "isbn": "9781423101468",
      "rating": 4.4,
      "categories": ["Fantasy", "YA"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781423101468-L.jpg"
    },
    {
      "id": "percy_5",
      "title": "Percy Jackson: The Last Olympian",
      "author": "Rick Riordan",
      "isbn": "9781423101475",
      "rating": 4.6,
      "categories": ["Fantasy", "YA"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781423101475-L.jpg"
    },
    {
      "id": "his_dark_1",
      "title": "Northern Lights (The Golden Compass)",
      "author": "Philip Pullman",
      "isbn": "9780440238133",
      "rating": 4.4,
      "categories": ["Fantasy", "YA"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780440238133-L.jpg"
    },
    {
      "id": "his_dark_2",
      "title": "The Subtle Knife",
      "author": "Philip Pullman",
      "isbn": "9780440238140",
      "rating": 4.4,
      "categories": ["Fantasy", "YA"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780440238140-L.jpg"
    },
    {
      "id": "his_dark_3",
      "title": "The Amber Spyglass",
      "author": "Philip Pullman",
      "isbn": "9780440238157",
      "rating": 4.5,
      "categories": ["Fantasy", "YA"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780440238157-L.jpg"
    },

    // ---------- Classics / Literary ----------
    {
      "id": "1984",
      "title": "Nineteen Eighty-Four",
      "author": "George Orwell",
      "isbn": "9780451524935",
      "rating": 4.8,
      "categories": ["Dystopia", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780451524935-L.jpg"
    },
    {
      "id": "brave_new_world",
      "title": "Brave New World",
      "author": "Aldous Huxley",
      "isbn": "9780060850524",
      "rating": 4.5,
      "categories": ["Dystopia", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780060850524-L.jpg"
    },
    {
      "id": "handmaids_tale",
      "title": "The Handmaid's Tale",
      "author": "Margaret Atwood",
      "isbn": "9780385490818",
      "rating": 4.5,
      "categories": ["Dystopia", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780385490818-L.jpg"
    },
    {
      "id": "catch22",
      "title": "Catch-22",
      "author": "Joseph Heller",
      "isbn": "9780684833392",
      "rating": 4.4,
      "categories": ["Satire", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780684833392-L.jpg"
    },
    {
      "id": "to_kill_a_mockingbird",
      "title": "To Kill a Mockingbird",
      "author": "Harper Lee",
      "isbn": "9780060935467",
      "rating": 4.9,
      "categories": ["Classic", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780060935467-L.jpg"
    },
    {
      "id": "the_great_gatsby",
      "title": "The Great Gatsby",
      "author": "F. Scott Fitzgerald",
      "isbn": "9780743273565",
      "rating": 4.3,
      "categories": ["Classic", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780743273565-L.jpg"
    },
    {
      "id": "moby_dick",
      "title": "Moby-Dick",
      "author": "Herman Melville",
      "isbn": "9780142437247",
      "rating": 4.1,
      "categories": ["Classic", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780142437247-L.jpg"
    },
    {
      "id": "war_and_peace",
      "title": "War and Peace",
      "author": "Leo Tolstoy",
      "isbn": "9780199232765",
      "rating": 4.4,
      "categories": ["Classic", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780199232765-L.jpg"
    },
    {
      "id": "crime_and_punishment",
      "title": "Crime and Punishment",
      "author": "Fyodor Dostoevsky",
      "isbn": "9780140449136",
      "rating": 4.5,
      "categories": ["Classic", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780140449136-L.jpg"
    },
    {
      "id": "pride_and_prejudice",
      "title": "Pride and Prejudice",
      "author": "Jane Austen",
      "isbn": "9780141199078",
      "rating": 4.6,
      "categories": ["Classic", "Romance"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780141199078-L.jpg"
    },
    {
      "id": "the_alchemist",
      "title": "The Alchemist",
      "author": "Paulo Coelho",
      "isbn": "9780061122415",
      "rating": 4.2,
      "categories": ["Fable", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780061122415-L.jpg"
    },
    {
      "id": "the_kite_runner",
      "title": "The Kite Runner",
      "author": "Khaled Hosseini",
      "isbn": "9781594631931",
      "rating": 4.6,
      "categories": ["Drama", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781594631931-L.jpg"
    },
    {
      "id": "life_of_pi",
      "title": "Life of Pi",
      "author": "Yann Martel",
      "isbn": "9780156027328",
      "rating": 4.3,
      "categories": ["Adventure", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780156027328-L.jpg"
    },
    {
      "id": "book_thief",
      "title": "The Book Thief",
      "author": "Markus Zusak",
      "isbn": "9780375842207",
      "rating": 4.7,
      "categories": ["Historical", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780375842207-L.jpg"
    },

    // ---------- Business / Psychology ----------
    {
      "id": "lean_startup",
      "title": "The Lean Startup",
      "author": "Eric Ries",
      "isbn": "9780307887894",
      "rating": 4.5,
      "categories": ["Business", "Startup"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780307887894-L.jpg"
    },
    {
      "id": "zero_to_one",
      "title": "Zero to One",
      "author": "Peter Thiel",
      "isbn": "9780804139298",
      "rating": 4.4,
      "categories": ["Business", "Startup"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780804139298-L.jpg"
    },
    {
      "id": "hard_thing",
      "title": "The Hard Thing About Hard Things",
      "author": "Ben Horowitz",
      "isbn": "9780062273208",
      "rating": 4.5,
      "categories": ["Business", "Management"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780062273208-L.jpg"
    },
    {
      "id": "atomic_habits",
      "title": "Atomic Habits",
      "author": "James Clear",
      "isbn": "9780735211292",
      "rating": 4.9,
      "categories": ["Self-Help", "Productivity"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780735211292-L.jpg"
    },
    {
      "id": "deep_work",
      "title": "Deep Work",
      "author": "Cal Newport",
      "isbn": "9781455586691",
      "rating": 4.6,
      "categories": ["Self-Help", "Productivity"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781455586691-L.jpg"
    },
    {
      "id": "thinking_fast_slow",
      "title": "Thinking, Fast and Slow",
      "author": "Daniel Kahneman",
      "isbn": "9780374533557",
      "rating": 4.5,
      "categories": ["Psychology", "Business"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780374533557-L.jpg"
    },
    {
      "id": "influence",
      "title": "Influence: The Psychology of Persuasion",
      "author": "Robert B. Cialdini",
      "isbn": "9780061241895",
      "rating": 4.6,
      "categories": ["Psychology", "Business"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780061241895-L.jpg"
    },
    {
      "id": "start_with_why",
      "title": "Start With Why",
      "author": "Simon Sinek",
      "isbn": "9781591846444",
      "rating": 4.3,
      "categories": ["Business", "Leadership"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781591846444-L.jpg"
    },
    {
      "id": "outliers",
      "title": "Outliers",
      "author": "Malcolm Gladwell",
      "isbn": "9780316017930",
      "rating": 4.3,
      "categories": ["Psychology", "Business"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780316017930-L.jpg"
    },
    {
      "id": "becoming",
      "title": "Becoming",
      "author": "Michelle Obama",
      "isbn": "9781524763138",
      "rating": 4.8,
      "categories": ["Memoir", "Non-fiction"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781524763138-L.jpg"
    },
    {
      "id": "educated",
      "title": "Educated",
      "author": "Tara Westover",
      "isbn": "9780399590504",
      "rating": 4.7,
      "categories": ["Memoir", "Non-fiction"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780399590504-L.jpg"
    },
    {
      "id": "born_a_crime",
      "title": "Born a Crime",
      "author": "Trevor Noah",
      "isbn": "9780399588198",
      "rating": 4.8,
      "categories": ["Memoir", "Non-fiction"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780399588198-L.jpg"
    },

    // ---------- Science / History / Economics ----------
    {
      "id": "brief_history_time",
      "title": "A Brief History of Time",
      "author": "Stephen Hawking",
      "isbn": "9780553380163",
      "rating": 4.7,
      "categories": ["Science", "Physics"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553380163-L.jpg"
    },
    {
      "id": "selfish_gene",
      "title": "The Selfish Gene",
      "author": "Richard Dawkins",
      "isbn": "9780199291151",
      "rating": 4.6,
      "categories": ["Science", "Biology"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780199291151-L.jpg"
    },
    {
      "id": "sapiens",
      "title": "Sapiens: A Brief History of Humankind",
      "author": "Yuval Noah Harari",
      "isbn": "9780062316097",
      "rating": 4.7,
      "categories": ["History", "Anthropology"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780062316097-L.jpg"
    },
    {
      "id": "homo_deus",
      "title": "Homo Deus: A Brief History of Tomorrow",
      "author": "Yuval Noah Harari",
      "isbn": "9780062464316",
      "rating": 4.5,
      "categories": ["History", "Future"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780062464316-L.jpg"
    },
    {
      "id": "guns_germs_steel",
      "title": "Guns, Germs, and Steel",
      "author": "Jared Diamond",
      "isbn": "9780393317558",
      "rating": 4.4,
      "categories": ["History", "Geography"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780393317558-L.jpg"
    },
    {
      "id": "why_nations_fail",
      "title": "Why Nations Fail",
      "author": "Daron Acemoglu; James A. Robinson",
      "isbn": "9780307719225",
      "rating": 4.4,
      "categories": ["Economics", "History"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780307719225-L.jpg"
    },

    // ---------- Software / Engineering ----------
    {
      "id": "clean_architecture",
      "title": "Clean Architecture",
      "author": "Robert C. Martin",
      "isbn": "9780134494166",
      "rating": 4.7,
      "categories": ["Software", "Architecture"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780134494166-L.jpg"
    },
    {
      "id": "clean_code",
      "title": "Clean Code",
      "author": "Robert C. Martin",
      "isbn": "9780132350884",
      "rating": 4.8,
      "categories": ["Software", "Development"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780132350884-L.jpg"
    },
    {
      "id": "pragmatic_programmer",
      "title": "The Pragmatic Programmer",
      "author": "Andrew Hunt; David Thomas",
      "isbn": "9780135957059",
      "rating": 4.8,
      "categories": ["Software", "Development"],
      "status": "reserved",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780135957059-L.jpg"
    },
    {
      "id": "refactoring",
      "title": "Refactoring",
      "author": "Martin Fowler",
      "isbn": "9780201485677",
      "rating": 4.6,
      "categories": ["Software", "Engineering"],
      "status": "borrowed",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780201485677-L.jpg"
    },
    {
      "id": "design_patterns",
      "title": "Design Patterns",
      "author": "Gamma; Helm; Johnson; Vlissides",
      "isbn": "9780201633610",
      "rating": 4.7,
      "categories": ["Software", "Architecture"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780201633610-L.jpg"
    },
    {
      "id": "domain_driven_design",
      "title": "Domain-Driven Design",
      "author": "Eric Evans",
      "isbn": "9780321125217",
      "rating": 4.6,
      "categories": ["Software", "Architecture"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780321125217-L.jpg"
    },
    {
      "id": "accelerate",
      "title": "Accelerate",
      "author": "Nicole Forsgren; Jez Humble; Gene Kim",
      "isbn": "9781942788331",
      "rating": 4.6,
      "categories": ["Software", "DevOps"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781942788331-L.jpg"
    },
    {
      "id": "mythical_man_month",
      "title": "The Mythical Man-Month",
      "author": "Frederick P. Brooks Jr.",
      "isbn": "9780201835953",
      "rating": 4.3,
      "categories": ["Software", "Management"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780201835953-L.jpg"
    },
    {
      "id": "effective_java",
      "title": "Effective Java (3rd Edition)",
      "author": "Joshua Bloch",
      "isbn": "9780134685991",
      "rating": 4.7,
      "categories": ["Software", "Java"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780134685991-L.jpg"
    },
    {
      "id": "you_dont_know_js",
      "title": "You Don't Know JS Yet",
      "author": "Kyle Simpson",
      "isbn": "9781091210092",
      "rating": 4.5,
      "categories": ["Software", "JavaScript"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781091210092-L.jpg"
    },
    {
      "id": "kotlin_in_action",
      "title": "Kotlin in Action",
      "author": "Dmitry Jemerov; Svetlana Isakova",
      "isbn": "9781617293290",
      "rating": 4.6,
      "categories": ["Software", "Kotlin"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781617293290-L.jpg"
    },
    {
      "id": "flutter_in_action",
      "title": "Flutter in Action",
      "author": "Eric Windmill",
      "isbn": "9781617296147",
      "rating": 4.4,
      "categories": ["Software", "Flutter"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781617296147-L.jpg"
    },

    // ---------- AI / Data / Design ----------
    {
      "id": "hands_on_ml",
      "title":
          "Hands-On Machine Learning with Scikit-Learn, Keras, and TensorFlow",
      "author": "Aurélien Géron",
      "isbn": "9781492032649",
      "rating": 4.7,
      "categories": ["AI", "Data"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781492032649-L.jpg"
    },
    {
      "id": "deep_learning",
      "title": "Deep Learning",
      "author": "Ian Goodfellow; Yoshua Bengio; Aaron Courville",
      "isbn": "9780262035613",
      "rating": 4.6,
      "categories": ["AI", "Data"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780262035613-L.jpg"
    },
    {
      "id": "prml",
      "title": "Pattern Recognition and Machine Learning",
      "author": "Christopher M. Bishop",
      "isbn": "9780387310732",
      "rating": 4.5,
      "categories": ["AI", "Data"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780387310732-L.jpg"
    },
    {
      "id": "dont_make_me_think",
      "title": "Don't Make Me Think, Revisited",
      "author": "Steve Krug",
      "isbn": "9780321965516",
      "rating": 4.6,
      "categories": ["Design", "UX"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780321965516-L.jpg"
    },
    {
      "id": "design_everyday_things",
      "title": "The Design of Everyday Things",
      "author": "Don Norman",
      "isbn": "9780465050659",
      "rating": 4.6,
      "categories": ["Design", "UX"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780465050659-L.jpg"
    },
  ];

  // ---------- ส่วนเพิ่มให้ทะลุ 100 เล่ม ----------
  books.addAll([
    {
      "id": "foundation_box",
      "title": "The Complete Robot",
      "author": "Isaac Asimov",
      "isbn": "9780385184007",
      "rating": 4.4,
      "categories": ["Sci-Fi", "Short Stories"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780385184007-L.jpg"
    },
    {
      "id": "ender_game",
      "title": "Ender's Game",
      "author": "Orson Scott Card",
      "isbn": "9780812550702",
      "rating": 4.6,
      "categories": ["Sci-Fi", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780812550702-L.jpg"
    },
    {
      "id": "neuromancer",
      "title": "Neuromancer",
      "author": "William Gibson",
      "isbn": "9780441569595",
      "rating": 4.3,
      "categories": ["Sci-Fi", "Cyberpunk"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780441569595-L.jpg"
    },
    {
      "id": "snow_crash",
      "title": "Snow Crash",
      "author": "Neal Stephenson",
      "isbn": "9780553380958",
      "rating": 4.3,
      "categories": ["Sci-Fi", "Cyberpunk"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780553380958-L.jpg"
    },
    {
      "id": "ready_player_one",
      "title": "Ready Player One",
      "author": "Ernest Cline",
      "isbn": "9780307887443",
      "rating": 4.4,
      "categories": ["Sci-Fi", "Pop"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780307887443-L.jpg"
    },
    {
      "id": "american_gods",
      "title": "American Gods",
      "author": "Neil Gaiman",
      "isbn": "9780380789030",
      "rating": 4.4,
      "categories": ["Fantasy", "Myth"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780380789030-L.jpg"
    },
    {
      "id": "good_omens",
      "title": "Good Omens",
      "author": "Neil Gaiman; Terry Pratchett",
      "isbn": "9780060853983",
      "rating": 4.5,
      "categories": ["Fantasy", "Comedy"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780060853983-L.jpg"
    },
    {
      "id": "name_of_the_wind",
      "title": "The Name of the Wind",
      "author": "Patrick Rothfuss",
      "isbn": "9780756404741",
      "rating": 4.6,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780756404741-L.jpg"
    },
    {
      "id": "wise_mans_fear",
      "title": "The Wise Man's Fear",
      "author": "Patrick Rothfuss",
      "isbn": "9780756404734",
      "rating": 4.5,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780756404734-L.jpg"
    },
    {
      "id": "wheel_time_1",
      "title": "The Eye of the World",
      "author": "Robert Jordan",
      "isbn": "9780312850098",
      "rating": 4.5,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780312850098-L.jpg"
    },
    {
      "id": "wheel_time_2",
      "title": "The Great Hunt",
      "author": "Robert Jordan",
      "isbn": "9780312851408",
      "rating": 4.4,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780312851408-L.jpg"
    },
    {
      "id": "wheel_time_3",
      "title": "The Dragon Reborn",
      "author": "Robert Jordan",
      "isbn": "9780312852481",
      "rating": 4.5,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780312852481-L.jpg"
    },
    {
      "id": "wheel_time_4",
      "title": "The Shadow Rising",
      "author": "Robert Jordan",
      "isbn": "9780312854317",
      "rating": 4.5,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780312854317-L.jpg"
    },
    {
      "id": "wheel_time_5",
      "title": "The Fires of Heaven",
      "author": "Robert Jordan",
      "isbn": "9780312854270",
      "rating": 4.4,
      "categories": ["Fantasy", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780312854270-L.jpg"
    },
    {
      "id": "shadow_of_wind",
      "title": "The Shadow of the Wind",
      "author": "Carlos Ruiz Zafón",
      "isbn": "9781594480003",
      "rating": 4.6,
      "categories": ["Mystery", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781594480003-L.jpg"
    },
    {
      "id": "gone_girl",
      "title": "Gone Girl",
      "author": "Gillian Flynn",
      "isbn": "9780307588371",
      "rating": 4.1,
      "categories": ["Thriller", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780307588371-L.jpg"
    },
    {
      "id": "girl_on_train",
      "title": "The Girl on the Train",
      "author": "Paula Hawkins",
      "isbn": "9781594634024",
      "rating": 4.0,
      "categories": ["Thriller", "Novel"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781594634024-L.jpg"
    },
    {
      "id": "life_changing_magic",
      "title": "The Life-Changing Magic of Tidying Up",
      "author": "Marie Kondo",
      "isbn": "9781607747307",
      "rating": 4.1,
      "categories": ["Self-Help", "Lifestyle"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9781607747307-L.jpg"
    },
    {
      "id": "atomic_design",
      "title": "Atomic Design",
      "author": "Brad Frost",
      "isbn": "9780997259907",
      "rating": 4.5,
      "categories": ["Design", "Web"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780997259907-L.jpg"
    },
    {
      "id": "story_brand",
      "title": "Building a StoryBrand",
      "author": "Donald Miller",
      "isbn": "9780718033323",
      "rating": 4.5,
      "categories": ["Marketing", "Business"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780718033323-L.jpg"
    },
    {
      "id": "four_steps",
      "title": "The Four Steps to the Epiphany",
      "author": "Steve Blank",
      "isbn": "9780989200547",
      "rating": 4.4,
      "categories": ["Business", "Startup"],
      "status": "available",
      "coverUrl": "https://covers.openlibrary.org/b/isbn/9780989200547-L.jpg"
    },
  ]);

  return books;
}
