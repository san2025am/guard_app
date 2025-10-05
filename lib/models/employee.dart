/// تمثيل مبسّط لموقع عمل الحارس والتعليمات المرتبطة به.
class LocationMini {
  final int id;
  final String name;
  final String clientName;
  final String? instructions; // جديد

  LocationMini({
    required this.id,
    required this.name,
    required this.clientName,
    this.instructions,
  });

  /// يبني النموذج من خريطة JSON قادمة من الخادم.
  factory LocationMini.fromJson(Map<String, dynamic> j) => LocationMini(
    id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
    name: (j['name'] ?? '').toString(),
    clientName: (j['client_name'] ?? j['clientName'] ?? '').toString(),
    instructions: (j['instructions'] ?? j['locationInstructions'])?.toString(),
  );
}
/// يجمع المعلومات المختصرة لمهمة الحارس الحالية.
class TaskMini {
  final String id;
  final String title;
  final String description;
  final String status;
  final String statusLabel;
  final String? statusNote;
  final String? nextStatus;
  final String? nextStatusLabel;
  final String? dueDate;
  final String locationName;

  TaskMini({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.statusLabel,
    this.statusNote,
    this.nextStatus,
    this.nextStatusLabel,
    this.dueDate,
    required this.locationName,
  });

  /// يحوّل خريطة خام إلى نموذج مهمة جاهز للعرض.
  factory TaskMini.fromJson(Map<String, dynamic> j) => TaskMini(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    description: (j['description'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    statusLabel: (j['status_label'] ?? j['statusLabel'] ?? j['status_display'] ?? '').toString(),
    statusNote: j['status_note']?.toString(),
    nextStatus: j['next_status']?.toString(),
    nextStatusLabel: j['next_status_label']?.toString(),
    dueDate: j['due_date']?.toString(),
    locationName: (j['location_name'] ?? '').toString(),
  );

  /// يحدد ما إذا كان بالإمكان ترقية حالة المهمة من الواجهة.
  bool get canAdvance => (nextStatus ?? '').isNotEmpty;

  /// يحلل تاريخ الاستحقاق إلى `DateTime` عند توفره.
  DateTime? get dueDateTime =>
      (dueDate == null || dueDate!.isEmpty) ? null : DateTime.tryParse(dueDate!);
}

/// ملخص لورديات الحارس المجدولة مع أوقاتها.
class ShiftMini {
  final int id;
  final String date;
  final String shiftName;
  final String startTime;
  final String endTime;
  final bool active;
  final String? notes;

  ShiftMini({
    required this.id,
    required this.date,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.active,
    this.notes,
  });

  /// ينشئ الورديات من بيانات الخادم المهيكلة.
  factory ShiftMini.fromJson(Map<String, dynamic> j) => ShiftMini(
    id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
    date: (j['date'] ?? '').toString(),
    shiftName: (j['shift_name'] ?? '').toString(),
    startTime: (j['start_time'] ?? '').toString(),
    endTime: (j['end_time'] ?? '').toString(),
    active: j['active'] == true || j['active']?.toString() == "true",
    notes: j['notes']?.toString(),
  );
}
/// يوضح ارتباط الحارس بشيفت معين مع هوامش الحضور والانصراف.
class ShiftAssignMini {
  final int id;
  final String? date;            // ISO yyyy-MM-dd أو null (تكرار يومي)
  final String shiftName;
  final String locationName;
  final String? startTime;       // "HH:MM" أو null
  final String? endTime;
  final int? checkinGrace;       // دقائق
  final int? checkoutGrace;      // دقائق
  final double? checkoutGraceHours; // ساعات (قد تكون 1.5)
  final bool unrestricted;
  final bool active;
  final String? notes;

  ShiftAssignMini({
    required this.id,
    required this.date,
    required this.shiftName,
    required this.locationName,
    required this.startTime,
    required this.endTime,
    required this.checkinGrace,
    required this.checkoutGrace,
    required this.checkoutGraceHours,
    required this.unrestricted,
    required this.active,
    required this.notes,
  });

  /// يحوّل بيانات التعيين الخام إلى نموذج قابل للاستخدام في الواجهة.
  factory ShiftAssignMini.fromJson(Map<String, dynamic> j) => ShiftAssignMini(
    id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
    date: j['date']?.toString(),
    shiftName: (j['shift_name'] ?? '').toString(),
    locationName: (j['location_name'] ?? '').toString(),
    startTime: j['start_time']?.toString(),
    endTime: j['end_time']?.toString(),
    checkinGrace: j['checkin_grace'] == null ? null : int.tryParse(j['checkin_grace'].toString()),
    checkoutGrace: j['checkout_grace'] == null ? null : int.tryParse(j['checkout_grace'].toString()),
    checkoutGraceHours: j['checkout_grace_hours'] == null ? null : double.tryParse(j['checkout_grace_hours'].toString()),
    unrestricted: j['unrestricted'] == true,
    active: j['active'] == true,
    notes: j['notes']?.toString(),
  );
}

/// يحفظ تفاصيل كشف الراتب الأخير للحارس.
class SalaryMini {
  final String? baseSalary, bonuses, overtime, deductions, totalSalary;
  final String? payDate; // ISO date

  SalaryMini({
    this.baseSalary,
    this.bonuses,
    this.overtime,
    this.deductions,
    this.totalSalary,
    this.payDate,
  });

  /// يبني نموذج الراتب مع دعم البيانات الناقصة.
  factory SalaryMini.fromJson(Map<String, dynamic>? j) {
    if (j == null) return SalaryMini();
    return SalaryMini(
      baseSalary: j['base_salary']?.toString(),
      bonuses: j['bonuses']?.toString(),
      overtime: j['overtime']?.toString(),
      deductions: j['deductions']?.toString(),
      totalSalary: j['total_salary']?.toString(),
      payDate: j['pay_date']?.toString(),
    );
  }
}

/// نموذج شامل لملف الحارس المعروض في التطبيق.
class EmployeeMe {
  final int id;
  final String username;
  final String? email;
  final String? role;       // قد تكون id أو نص – نخزّنها كنص
  final String? roleLabel;  // الاسم المقروء
  final String fullName;
  final String? nationalId;
  final String? phoneNumber;
  final String? hireDate;   // ISO
  final String? bankName;
  final String? bankAccount;
  final List<ShiftAssignMini> shiftAssignments;
  // جديد من الـ Serializer
  final String? idExpiryDate;
  final String? dateOfBirthGregorian;
  final String? employeeInstructions;
  final List<String> locationInstructions; // تُعاد كقائمة
  final String? supervisorName;
  final String? supervisorPhone;

  final List<LocationMini> locations;
  final SalaryMini salary;
  final List<TaskMini> tasks;
  final List<ShiftMini> shifts;
  EmployeeMe({
    required this.id,
    required this.username,
    required this.fullName,
    this.email,
    this.role,
    this.roleLabel,
    this.nationalId,
    this.phoneNumber,
    this.hireDate,
    this.bankName,
    this.bankAccount,
    this.idExpiryDate,
    this.dateOfBirthGregorian,
    this.employeeInstructions,
    this.locationInstructions = const [],
    this.supervisorName,
    this.supervisorPhone,
    required this.locations,
    required this.salary,
    this.tasks = const [],
    this.shifts = const [],
    required this.shiftAssignments
  });

  /// يدمج الحقول المتنوعة القادمة من الـ API في كائن واحد منظم.
  factory EmployeeMe.fromJson(Map<String, dynamic> j) {
    // role قد تأتي كنص/رقم أو كائن { name: ... }
    String? roleText;
    final rv = j['role'];
    if (rv is Map) {
      roleText = (rv['name'] ?? rv['title'] ?? rv.toString()).toString();
    } else if (rv != null) {
      roleText = rv.toString();
    }
    final roleLabelText = (j['role_label'] ?? j['roleLabel'] ?? roleText ?? '').toString();

    // المواقع
    final locList = (j['locations'] as List? ?? [])
        .whereType<dynamic>()
        .map((e) => LocationMini.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    // تعليمات المواقع: قائمة نصوص
    final rawLocInstr = j['location_instructions'] ?? j['locationInstructions'];
    final locInstr = (rawLocInstr is List)
        ? rawLocInstr
        .map((e) => e?.toString())
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList()
        : <String>[];
    // المهام
    final taskList = (j['tasks'] as List? ?? [])
        .map((e) => TaskMini.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // الورديات
    final shiftList = (j['shifts'] as List? ?? [])
        .map((e) => ShiftMini.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final assigns = <ShiftAssignMini>[];
    if (j['shift_assignments'] is List) {
      for (final x in (j['shift_assignments'] as List)) {
        if (x is Map<String, dynamic>) {
          assigns.add(ShiftAssignMini.fromJson(x));
        } else if (x is Map) {
          assigns.add(ShiftAssignMini.fromJson(Map<String, dynamic>.from(x)));
        }
      }
    }
    return EmployeeMe(
      id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
      username: (j['username'] ?? '').toString(),
      email: j['email']?.toString(),
      role: roleText,
      roleLabel: roleLabelText,
      fullName: (j['full_name'] ?? j['fullName'] ?? '').toString(),
      nationalId: j['national_id']?.toString(),
      phoneNumber: j['phone_number']?.toString(),
      hireDate: j['hire_date']?.toString(),
      bankName: j['bank_name']?.toString(),
      bankAccount: j['bank_account']?.toString(),

      // الحقول الجديدة (تاريخ/تعليمات/مشرف)
      idExpiryDate: j['id_expiry_date']?.toString(),
      dateOfBirthGregorian: j['date_of_birth_gregorian']?.toString(),
      employeeInstructions: (j['employee_instructions'] ?? j['instructions'])?.toString(),
      locationInstructions: locInstr,
      supervisorName: (j['supervisor_name'] ?? j['supervisorName'])?.toString(),
      supervisorPhone: (j['supervisor_phone'] ?? j['supervisorPhone'])?.toString(),

      locations: locList,
      salary: SalaryMini.fromJson(
        (j['salary'] is Map) ? Map<String, dynamic>.from(j['salary']) : null,

      ),
      tasks: taskList,
      shifts: shiftList,
      shiftAssignments: assigns,
    );
  }
}
