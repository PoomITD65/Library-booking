// lib/features/books/presentation/widgets/book_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:library_booking/features/books/domain/models/book.dart';

class BookCard extends StatelessWidget {
  const BookCard(
    this.book, {
    super.key,
    required this.onAdd,
    required this.isSelected,
    required this.onTap,
    this.isFavorited = false,
    this.onToggleFavorite,
  });

  final Book book;
  final VoidCallback onAdd;
  final VoidCallback onTap;
  final bool isSelected;

  // optional: ใช้ในหน้า favorites ได้
  final bool isFavorited;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // ✅ กดได้เฉพาะ Available
    final isInteractive = book.status == BookStatus.available;

    // ป้ายสถานะสำหรับมุมบนขวา (เวลา non-interactive)
    String? _badgeText() => switch (book.status) {
          BookStatus.available => null,
          BookStatus.reserved  => 'Reserved',
          BookStatus.borrowed  => 'Borrowed',
          BookStatus.overdue   => 'Overdue',
        };

    return Opacity(
      // ทำให้การ์ดจางลงถ้าไม่พร้อมให้กด
      opacity: isInteractive ? 1.0 : 0.55,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          // ❌ ถ้าไม่ interactive: onTap เป็น null → แตะการ์ดไม่ได้
          onTap: isInteractive ? onTap : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // รูป + badge ต่าง ๆ
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.72,
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: CachedNetworkImage(
                              imageUrl: book.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  const ColoredBox(color: Color(0x11000000)),
                              errorWidget: (_, __, ___) =>
                                  const Center(child: Icon(Icons.broken_image)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ⭐ rating
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            book.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ]),
                      ),
                    ),
                    // ❤️ favorite (ถ้ามี callback)
                    if (onToggleFavorite != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(.35),
                            padding: const EdgeInsets.all(6),
                          ),
                          onPressed: onToggleFavorite,
                          icon: Icon(
                            isFavorited
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 18,
                            color: isFavorited ? Colors.red : Colors.white,
                          ),
                        ),
                      ),
                    // 🏷️ ป้ายสถานะ (เฉพาะตอนกดไม่ได้)
                    if (!isInteractive)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                _badgeText()!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ชื่อ + ผู้เขียน
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

              // แถบล่าง
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Row(
                  children: [
                    _StatusDot(book.status),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _statusLabel(book.status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    // ➕ ปุ่มเพิ่ม — disabled เมื่อไม่ interactive
                    IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            isSelected ? colors.primaryContainer : null,
                      ),
                      onPressed: isInteractive ? onAdd : null,
                      icon: Icon(isSelected ? Icons.check : Icons.add),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(BookStatus s) => switch (s) {
        BookStatus.available => 'Available',
        BookStatus.reserved  => 'Reserved',
        BookStatus.borrowed  => 'Borrowed',
        BookStatus.overdue   => 'Overdue',
      };
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.status);
  final BookStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BookStatus.available => Colors.green,
      BookStatus.reserved  => Colors.orange,
      BookStatus.borrowed  => Colors.blue,
      BookStatus.overdue   => Colors.red,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
