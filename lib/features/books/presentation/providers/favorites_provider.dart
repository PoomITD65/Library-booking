// lib/features/books/presentation/providers/favorites_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// เก็บ id หนังสือที่ favorite ไว้
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (_) => FavoritesNotifier(),
);

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super(<String>{});

  bool isFav(String id) => state.contains(id);

  void toggle(String id) {
    final s = {...state};
    s.contains(id) ? s.remove(id) : s.add(id);
    state = s;
  }

  void clear() => state = {};
  void remove(String id) => state = {...state}..remove(id);
}
