import 'package:intl/intl.dart';

class GuardAdvance {
  GuardAdvance({
    required this.id,
    required this.amount,
    this.reason,
    required this.status,
    required this.statusDisplay,
    this.requestedAt,
    this.approvedAt,
    required this.raw,
  });

  final String id;
  final double amount;
  final String? reason;
  final String status;
  final String statusDisplay;
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final Map<String, dynamic> raw;

  factory GuardAdvance.fromJson(Map<dynamic, dynamic> json) {
    final map = json.map((key, value) => MapEntry(key.toString(), value));

    final id = _text(map, ['id', 'uuid', 'pk']) ?? '';
    final amountStr = _text(map, ['amount', 'value']) ?? '0';
    final status = _text(map, ['status']) ?? '';
    final statusDisplay = _text(map, ['status_display', 'statusLabel', 'status_text']) ?? status;
    final reason = _text(map, ['reason', 'note', 'description'], allowEmpty: true);
    final requestedIso = _text(map, ['requested_at', 'created_at', 'timestamp'], allowEmpty: true);
    final approvedIso = _text(map, ['approved_at'], allowEmpty: true);

    DateTime? parseDate(String? iso) =>
        (iso == null || iso.isEmpty) ? null : DateTime.tryParse(iso);

    return GuardAdvance(
      id: id.isNotEmpty ? id : map.hashCode.toString(),
      amount: double.tryParse(amountStr) ?? 0,
      reason: reason,
      status: status,
      statusDisplay: statusDisplay,
      requestedAt: parseDate(requestedIso),
      approvedAt: parseDate(approvedIso),
      raw: Map<String, dynamic>.from(map),
    );
  }

  String? get formattedRequestedAt => _formatDateTime(requestedAt);
  String? get formattedApprovedAt => _formatDateTime(approvedAt);

  static String? _formatDateTime(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat.yMMMd().add_Hm().format(dt.toLocal());
  }

  static String? _text(
    Map<String, dynamic> map,
    List<String> keys, {
    bool allowEmpty = false,
  }) {
    for (final key in keys) {
      final dynamic value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty && !allowEmpty) continue;
      return text;
    }
    return null;
  }
}
