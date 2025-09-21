// ------- LocationMini -------
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

  factory LocationMini.fromJson(Map<String, dynamic> j) => LocationMini(
    id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
    name: (j['name'] ?? '').toString(),
    clientName: (j['client_name'] ?? j['clientName'] ?? '').toString(),
    instructions: (j['instructions'] ?? j['locationInstructions'])?.toString(),
  );
}

// ------- SalaryMini -------
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

// ------- EmployeeMe -------
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

  // جديد من الـ Serializer
  final String? idExpiryDate;
  final String? dateOfBirthGregorian;
  final String? employeeInstructions;
  final List<String> locationInstructions; // تُعاد كقائمة
  final String? supervisorName;
  final String? supervisorPhone;

  final List<LocationMini> locations;
  final SalaryMini salary;

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
  });

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
      employeeInstructions: (j['employee_instructions'] ?? j['employeeInstructions'])?.toString(),
      locationInstructions: locInstr,
      supervisorName: (j['supervisor_name'] ?? j['supervisorName'])?.toString(),
      supervisorPhone: (j['supervisor_phone'] ?? j['supervisorPhone'])?.toString(),

      locations: locList,
      salary: SalaryMini.fromJson(
        (j['salary'] is Map) ? Map<String, dynamic>.from(j['salary']) : null,
      ),
    );
  }
}
