import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_booking/features/loans/domain/models/loan.dart';
import '../../data/loan_repo.dart';


final loanHistoryProvider =
    AsyncNotifierProvider.autoDispose<LoanHistoryNotifier, List<LoanEntry>>(
        LoanHistoryNotifier.new);

class LoanHistoryNotifier extends AutoDisposeAsyncNotifier<List<LoanEntry>> {
  @override
  Future<List<LoanEntry>> build() async {
    final repo = ref.read(loanRepoProvider);
    return repo.history();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(loanRepoProvider).history());
  }

  // ใช้กรณี optimistic update หลัง borrow สำเร็จ
  void prepend(List<LoanEntry> items) {
    final cur = state.value ?? const <LoanEntry>[];
    state = AsyncData([...items, ...cur]);
  }
}
