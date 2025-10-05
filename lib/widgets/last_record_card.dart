import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_mini.dart';

class LastRecordCard extends StatelessWidget {
  final AttendanceMini record;
  const LastRecordCard({super.key, required this.record});

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isCheckedOut = record.checkOutTime != null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تفاصيل آخر تسجيل:',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('الموقع:'),
                const SizedBox(width: 6),
                Expanded(child: Text(record.locationName ?? '—')),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('الحضور:'),
                const SizedBox(width: 6),
                Text(_fmt(record.checkInTime)),
                const SizedBox(width: 12),
                const Text('الانصراف:'),
                const SizedBox(width: 6),
                Text(_fmt(record.checkOutTime)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('النوع:'),
                const SizedBox(width: 6),
                Text(isCheckedOut
                    ? (record.earlyCheckout ? 'انصراف مبكر' : 'انصراف')
                    : 'حضور'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
