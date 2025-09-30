// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get app_title => 'سنام الأمن';

  @override
  String get theme_light => 'نهاري';

  @override
  String get theme_dark => 'ليلي';

  @override
  String get toggle_theme => 'تبديل الثيم';

  @override
  String get language => 'اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'الإنجليزية';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get forgot_password => 'نسيت كلمة المرور؟';

  @override
  String get send_code => 'إرسال الرمز للبريد';

  @override
  String get reset_password => 'استعادة كلمة المرور';

  @override
  String get code => 'الرمز (6 أرقام)';

  @override
  String get new_password => 'كلمة المرور الجديدة';

  @override
  String get change_password => 'تغيير كلمة المرور';

  @override
  String get guard_home => 'لوحة حارس الأمن';

  @override
  String get welcome => 'مرحبًا بك!';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get attendance => 'التحضير';

  @override
  String get reports_requests => 'التقارير والطلبات';

  @override
  String get role => 'الدور';

  @override
  String get sync => 'تحديث البيانات';

  @override
  String get sync_hint => 'يجلب أحدث اسم المستخدم/الدور من الجهاز';

  @override
  String get checked_in => 'تم تسجيل حضورك';

  @override
  String get checked_out => 'أنت خارج الدوام';

  @override
  String get check_in => 'تسجيل حضور';

  @override
  String get check_out => 'تسجيل انصراف';

  @override
  String get attendance_history => 'سجل التحضير';

  @override
  String get attendance_history_hint => 'اعرض سجلات حضورك السابقة';

  @override
  String get create_report => 'إنشاء تقرير';

  @override
  String get create_report_hint => 'ارسال تقرير جديد للمشرف';

  @override
  String get report_subject => 'الموضوع';

  @override
  String get report_subject_required => 'حقل الموضوع مطلوب';

  @override
  String get report_details => 'التفاصيل';

  @override
  String get report_details_required => 'حقل التفاصيل مطلوب';

  @override
  String get report_type_label => 'نوع التقرير';

  @override
  String get report_type_required => 'يرجى اختيار نوع التقرير';

  @override
  String get report_type_daily => 'تقرير يومي';

  @override
  String get report_type_monthly => 'تقرير شهري';

  @override
  String get report_type_security => 'بلاغ أمني';

  @override
  String get report_type_complaint => 'شكوى';

  @override
  String get report_add_attachment => 'إضافة مرفق';

  @override
  String get report_attachments => 'المرفقات';

  @override
  String get report_attachment_image_camera => 'التقاط صورة بالكاميرا';

  @override
  String get report_attachment_image_gallery => 'اختيار صورة من المعرض';

  @override
  String get report_attachment_video_camera => 'تسجيل فيديو';

  @override
  String get report_attachment_video_gallery => 'اختيار فيديو من المعرض';

  @override
  String get report_attachment_remove => 'إزالة';

  @override
  String get report_attachment_pick_error => 'تعذر اختيار المرفق';

  @override
  String get submit_report => 'إرسال التقرير';

  @override
  String get report_submit_success => 'تم إرسال التقرير بنجاح';

  @override
  String get report_submit_error => 'تعذر إرسال التقرير';

  @override
  String get open_requests => 'الطلبات المفتوحة';

  @override
  String get open_requests_hint => 'اعرض وتتبع طلباتك';

  @override
  String get requests_empty_state => 'لا توجد طلبات مفتوحة بعد.';

  @override
  String get requests_load_error => 'تعذر تحميل الطلبات';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get request_type => 'النوع';

  @override
  String get request_status => 'الحالة';

  @override
  String get request_submitted_on => 'تاريخ التقديم';

  @override
  String get create_request => 'إنشاء طلب';

  @override
  String get create_request_hint => 'إرسال طلب جديد';

  @override
  String get request_type_required => 'يرجى اختيار نوع الطلب';

  @override
  String get request_type_coverage => 'تغطية';

  @override
  String get request_type_leave => 'إجازة';

  @override
  String get request_type_transfer => 'نقل';

  @override
  String get request_type_materials => 'مواد';

  @override
  String get request_description => 'التفاصيل';

  @override
  String get request_description_required => 'حقل التفاصيل مطلوب';

  @override
  String get leave_start_datetime => 'بداية الإجازة';

  @override
  String get leave_end_datetime => 'نهاية الإجازة';

  @override
  String get leave_start_not_selected => 'لم يتم اختيار البداية';

  @override
  String get leave_end_not_selected => 'لم يتم اختيار النهاية';

  @override
  String get leave_pick_dates_required =>
      'يرجى اختيار وقت البداية والنهاية للإجازة';

  @override
  String get leave_end_must_follow_start => 'يجب أن تكون النهاية بعد البداية';

  @override
  String get leave_range => 'مدة الإجازة';

  @override
  String get leave_hours_label => 'ساعات الإجازة';

  @override
  String get submit_request => 'إرسال الطلب';

  @override
  String get request_submit_success => 'تم إرسال الطلب بنجاح';

  @override
  String get request_submit_error => 'تعذّر إرسال الطلب';

  @override
  String get request_approval_notes => 'ملاحظات القرار';

  @override
  String get request_approver => 'تمت المعالجة بواسطة';

  @override
  String get coming_soon => 'قريبًا';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutTooltip => 'خروج من الحساب';
}
