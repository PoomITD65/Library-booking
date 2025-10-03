// lib/features/books/presentation/book_detail_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/book_repo.dart';
import '../domain/models/book.dart';

class BookDetailPage extends ConsumerWidget {
  const BookDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookRepoProvider);

    return FutureBuilder<Book>(
      future: repo.getBook(id),
      builder: (context, snap) {
        // ----- Loading -----
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
              title: const Text('Loading...'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // ----- Not found / Error -----
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
              title: const Text('Book'),
            ),
            body: const Center(child: Text('Not found')),
          );
        }

        // ----- Data ready -----
        final b = snap.data!;

        // CTA ตามสถานะ (กดได้เฉพาะ Available)
        late final String ctaLabel;
        VoidCallback? cta; // null = disabled
        switch (b.status) {
          case BookStatus.available:
            ctaLabel = 'Reserve';
            cta = () async {
              await repo.reserve(b.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reserved successfully')),
              );
            };
            break;
          case BookStatus.reserved:
            ctaLabel = 'Reserved';
            cta = null;
            break;
          case BookStatus.borrowed:
            ctaLabel = 'Borrowed';
            cta = null;
            break;
          case BookStatus.overdue:
            ctaLabel = 'Overdue';
            cta = null;
            break;
        }

        return Scaffold(
          appBar: AppBar(
            // ให้มีปุ่มย้อนกลับเสมอ (เผื่อเปิดหน้าโดยตรง)
            leading: BackButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
            title: Text(
              b.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ปกหนังสือ
              AspectRatio(
                aspectRatio: 3 / 4,
                child: CachedNetworkImage(
                  imageUrl: b.coverUrl,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),

              // ชื่อ/ผู้เขียน
              Text(
                b.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                b.author,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),

              // ISBN / Rating
              Text('ISBN: ${b.isbn} • Rating ${b.rating.toStringAsFixed(1)}'),

              const SizedBox(height: 12),

              // สถานะ + หมวดหมู่
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(status: b.status),
                  ...b.categories.map((c) => Chip(label: Text(c))),
                ],
              ),

              const SizedBox(height: 20),

              // ปุ่มทำรายการ (disabled ถ้าไม่ใช่ Available)
              FilledButton(
                onPressed: cta,
                child: Text(ctaLabel),
              ),

              if (b.status != BookStatus.available) ...[
                const SizedBox(height: 8),
                Text(
                  _statusHelpText(b.status),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final BookStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BookStatus.available => ('Available', Colors.green),
      BookStatus.reserved => ('Reserved', Colors.orange),
      BookStatus.borrowed => ('Borrowed', Colors.blue),
      BookStatus.overdue => ('Overdue', Colors.red),
    };

    return Chip(
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text(label),
    );
    }
}

String _statusHelpText(BookStatus s) => switch (s) {
      BookStatus.available =>
        'This book is available to reserve now.',
      BookStatus.reserved =>
        'This book has been reserved by someone else.',
      BookStatus.borrowed =>
        'This book is currently borrowed and cannot be reserved.',
      BookStatus.overdue =>
        'This book is overdue and unavailable right now.',
    };
