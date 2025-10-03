import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_booking/features/loans/domain/models/loan.dart';
import '../../../core/dio_client.dart';
import '../../auth/data/session.dart';

final loanRepoProvider = Provider<LoanRepo>((ref) {
  final dio = createDio(Session.token);
  return LoanRepo(dio);
});

class LoanRepo {
  LoanRepo(this._dio);
  final Dio _dio;

  Future<List<LoanEntry>> history({String status = ''}) async {
    final resp = await _dio.get('/loans/history', queryParameters: {
      if (status.isNotEmpty) 'status': status,
    });
    final data = (resp.data as List).cast<Map<String, dynamic>>();
    return data.map(LoanEntry.fromJson).toList();
  }

  Future<void> borrow(List<String> bookIds) async {
    await _dio.post('/loans/borrow', data: {'bookIds': bookIds});
  }

  /// คืนตาม id ของประวัติ (แม่นยำสุด)
  Future<int> returnByHistoryIds(List<String> historyIds) async {
    final resp =
        await _dio.post('/loans/return', data: {'historyIds': historyIds});
    return (resp.data is Map) ? (resp.data['updated'] ?? 0) as int : 0;
  }

  /// คืนตาม bookIds (จะคืน entry ล่าสุดของเล่มนั้นที่ยังไม่คืน)
  Future<int> returnByBookIds(List<String> bookIds) async {
    final resp =
        await _dio.post('/loans/return', data: {'bookIds': bookIds});
    return (resp.data is Map) ? (resp.data['updated'] ?? 0) as int : 0;
  }
}
