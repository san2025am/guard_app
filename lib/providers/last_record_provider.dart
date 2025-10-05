import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/attendance_mini.dart';
import '../services/api.dart';

class LastRecordProvider extends ChangeNotifier {
  AttendanceMini? _record;
  Timer? _watcher;
  Duration pollEvery = const Duration(seconds: 10);

  AttendanceMini? get record => _record;

  Future<void> refresh() async {
    try {
      final data = await ApiService.fetchLastAttendance();
      _record = data == null ? null : AttendanceMini.fromJson(data);
      notifyListeners();
      _restartWatcher();
    } catch (_) {
      // لا تفشل الواجهة
    }
  }

  void _restartWatcher() {
    _watcher?.cancel();
    if (_record == null) return;
    _watcher = Timer.periodic(pollEvery, (_) async {
      final id = _record?.id;
      if (id == null) return;
      try {
        final stillThere = await ApiService.attendanceExists(id);
        if (!stillThere) {
          _record = null;
          notifyListeners(); // اختفِ فورًا من الواجهة
          _watcher?.cancel();
        }
      } catch (_) {
        // تجاهل مؤقتًا
      }
    });
  }

  void clear() {
    _watcher?.cancel();
    _record = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _watcher?.cancel();
    super.dispose();
  }
}
