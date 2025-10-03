import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectionNotifier extends StateNotifier<Set<String>> {
  SelectionNotifier() : super(<String>{});
  void toggle(String id) => state = state.contains(id)
      ? (state..remove(id)).toSet()
      : (state..add(id)).toSet();
  void clear() => state = {};
}

final selectionProvider = StateNotifierProvider<SelectionNotifier, Set<String>>(
  (ref) => SelectionNotifier(),
);
