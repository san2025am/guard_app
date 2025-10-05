class AttendanceMini {
  final String id;
  final int employeeId;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final bool earlyCheckout;
  final String? locationId;
  final String? locationName;
  final DateTime updatedAt;

  AttendanceMini({
    required this.id,
    required this.employeeId,
    required this.checkInTime,
    required this.checkOutTime,
    required this.earlyCheckout,
    required this.locationId,
    required this.locationName,
    required this.updatedAt,
  });

  factory AttendanceMini.fromJson(Map<String, dynamic> j) => AttendanceMini(
        id: j['id'] as String,
        employeeId: j['employee_id'] as int,
        checkInTime: j['check_in_time'] != null
            ? DateTime.parse(j['check_in_time'])
            : null,
        checkOutTime: j['check_out_time'] != null
            ? DateTime.parse(j['check_out_time'])
            : null,
        earlyCheckout: (j['early_checkout'] as bool?) ?? false,
        locationId: j['location_id']?.toString(),
        locationName: j['location_name']?.toString(),
        updatedAt: DateTime.parse(j['updated_at']),
      );
}
