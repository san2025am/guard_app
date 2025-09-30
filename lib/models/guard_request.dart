import 'package:intl/intl.dart';

class GuardRequest {
  GuardRequest({
    required this.id,
    required this.requestType,
    required this.requestTypeDisplay,
    required this.status,
    required this.statusDisplay,
    this.description,
    this.approvalNotes,
    this.approverName,
    this.createdAt,
    this.leaveStart,
    this.leaveEnd,
    this.leaveHours,
    required this.raw,
  });

  final String id;
  final String requestType;
  final String requestTypeDisplay;
  final String status;
  final String statusDisplay;
  final String? description;
  final String? approvalNotes;
  final String? approverName;
  final DateTime? createdAt;
  final DateTime? leaveStart;
  final DateTime? leaveEnd;
  final String? leaveHours;
  final Map<String, dynamic> raw;

  factory GuardRequest.fromJson(Map<dynamic, dynamic> json) {
    final map = json.map((key, value) => MapEntry(key.toString(), value));

    final id = _firstNonEmpty(map, const ['id', 'uuid', 'request_id', 'pk']) ?? '';
    final requestType = _firstNonEmpty(map, const ['request_type', 'type', 'category']) ?? '';
    final requestTypeDisplay = _firstNonEmpty(
          map,
          const ['request_type_display', 'type_label', 'type_display', 'request_type_label'],
        ) ??
        requestType;
    final status = _firstNonEmpty(map, const ['status', 'state', 'current_status']) ?? '';
    final statusDisplay = _firstNonEmpty(
          map,
          const ['status_display', 'status_label', 'statusText'],
        ) ??
        status;
    final description = _firstNonEmpty(
      map,
      const ['description', 'details', 'note', 'notes', 'comment'],
      allowEmpty: true,
    );
    final approvalNotes = _firstNonEmpty(
      map,
      const ['approval_notes', 'approver_notes', 'manager_comment'],
      allowEmpty: true,
    );
    final approverName = _firstNonEmpty(
      map,
      const ['approver_name', 'approver', 'manager_name'],
      allowEmpty: true,
    );

    final created = _firstNonEmpty(
      map,
      const ['created_at', 'created', 'timestamp', 'submitted_on'],
      allowEmpty: true,
    );
    DateTime? createdAt;
    if (created != null && created.isNotEmpty) {
      createdAt = DateTime.tryParse(created);
    }

    DateTime? parseDateTime(String? value) {
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    final leaveStartIso = _firstNonEmpty(map, const ['leave_start']);
    final leaveEndIso = _firstNonEmpty(map, const ['leave_end']);
    final leaveHours = _firstNonEmpty(map, const ['leave_hours', 'leaveHours'], allowEmpty: true);

    return GuardRequest(
      id: id.isNotEmpty ? id : map.hashCode.toString(),
      requestType: requestType,
      requestTypeDisplay: requestTypeDisplay,
      status: status,
      statusDisplay: statusDisplay,
      description: description,
      approvalNotes: approvalNotes,
      approverName: approverName,
      createdAt: createdAt,
      leaveStart: parseDateTime(leaveStartIso),
      leaveEnd: parseDateTime(leaveEndIso),
      leaveHours: leaveHours,
      raw: Map<String, dynamic>.from(map),
    );
  }

  String get primaryTitle => requestTypeDisplay.isNotEmpty ? requestTypeDisplay : requestType;

  String? get formattedDate =>
      createdAt == null ? null : DateFormat.yMMMd().add_Hm().format(createdAt!.toLocal());

  String? get formattedLeaveRange {
    if (leaveStart == null || leaveEnd == null) return null;
    final formatter = DateFormat.yMMMd().add_Hm();
    return '${formatter.format(leaveStart!.toLocal())} → ${formatter.format(leaveEnd!.toLocal())}';
  }

  static String? _firstNonEmpty(
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
