/// نماذج البيانات الخاصة بطلبات الحراس وملحقات الزي.
import 'package:intl/intl.dart';

/// يمثل طلبًا واحدًا للحارس مع تفاصيل الحالة والتواريخ.
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
    this.uniformDelivery,
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
  final GuardUniformDelivery? uniformDelivery;
  final Map<String, dynamic> raw;

  /// ينظّف هيكل JSON المرن القادم من الخادم.
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

    GuardUniformDelivery? uniformDelivery;
    final uniformMap = map['uniform_delivery'];
    if (uniformMap is Map) {
      try {
        uniformDelivery = GuardUniformDelivery.fromJson(
          Map<String, dynamic>.from(uniformMap as Map),
        );
      } catch (_) {
        uniformDelivery = null;
      }
    }

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
      uniformDelivery: uniformDelivery,
      raw: Map<String, dynamic>.from(map),
    );
  }

  /// عنوان مهيأ يُظهر التصنيف البشري للطلب.
  String get primaryTitle => requestTypeDisplay.isNotEmpty ? requestTypeDisplay : requestType;

  /// صيغة قراءة للتاريخ والوقت الذي أُنشئ فيه الطلب.
  String? get formattedDate =>
      createdAt == null ? null : DateFormat.yMMMd().add_Hm().format(createdAt!.toLocal());

  /// صيغة زمنية للطلبات المرتبطة بالإجازات.
  String? get formattedLeaveRange {
    if (leaveStart == null || leaveEnd == null) return null;
    final formatter = DateFormat.yMMMd().add_Hm();
    return '${formatter.format(leaveStart!.toLocal())} → ${formatter.format(leaveEnd!.toLocal())}';
  }

  /// يعيد أول قيمة نصية غير فارغة مع دعم أسماء مفاتيح متعددة.
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

/// تفاصيل تسليم الزي والأسعار والطريقة المستخدمة للدفع.
class GuardUniformDelivery {
  GuardUniformDelivery({
    required this.id,
    required this.paymentMethod,
    required this.paymentMethodDisplay,
    required this.totalValue,
    this.deliveryDate,
    required this.items,
  });

  final String id;
  final String paymentMethod;
  final String paymentMethodDisplay;
  final String totalValue;
  final DateTime? deliveryDate;
  final List<GuardUniformDeliveryItem> items;

  /// يحوّل بيانات التسليم من الخادم إلى نموذج strongly-typed.
  factory GuardUniformDelivery.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => GuardUniformDeliveryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return GuardUniformDelivery(
      id: (json['id'] ?? '').toString(),
      paymentMethod: (json['payment_method'] ?? '').toString(),
      paymentMethodDisplay: (json['payment_method_display'] ?? json['paymentMethodDisplay'] ?? '').toString(),
      totalValue: (json['total_value'] ?? json['totalValue'] ?? '').toString(),
      deliveryDate: json['delivery_date'] == null
          ? null
          : DateTime.tryParse(json['delivery_date'].toString()),
      items: items,
    );
  }
}

/// عنصر مفرد ضمن تسليم الزي، يحتوي على الكمية والتكلفة.
class GuardUniformDeliveryItem {
  GuardUniformDeliveryItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.value,
    this.notes,
  });

  final String id;
  final String itemId;
  final String itemName;
  final int quantity;
  final String value;
  final String? notes;

  factory GuardUniformDeliveryItem.fromJson(Map<String, dynamic> json) => GuardUniformDeliveryItem(
        id: (json['id'] ?? '').toString(),
        itemId: (json['item_id'] ?? json['itemId'] ?? '').toString(),
        itemName: (json['item_name'] ?? json['itemName'] ?? '').toString(),
        quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
        value: (json['value'] ?? '').toString(),
        notes: json['notes']?.toString(),
      );
}
