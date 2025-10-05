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
  String get language_settings_title => 'إعدادات اللغة';

  @override
  String get language_settings_hint => 'اختر لغتك المفضلة من الخيارات أدناه';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'الإنجليزية';

  @override
  String get session_timeout_title => 'انتهاء الجلسة';

  @override
  String session_timeout_message(int seconds) {
    return 'لم يتم رصد أي نشاط. سيتم تسجيل الخروج خلال $seconds ثانية.';
  }

  @override
  String get session_timeout_keep => 'متابعة الاستخدام';

  @override
  String get session_timeout_logout => 'تسجيل الخروج الآن';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get forgot_password => 'نسيت كلمة المرور؟';

  @override
  String get device_untrusted_title => 'متصفح غير مسجل';

  @override
  String get device_untrusted_message =>
      'عزيزي العميل، هذا الجهاز غير موثوق. إذا كنت ترغب في استخدامه، يمكنك إضافته إلى قائمة أجهزتك الموثوقة.';

  @override
  String get device_untrusted_accept => 'نعم';

  @override
  String get device_untrusted_decline => 'لا';

  @override
  String device_otp_instructions(Object destination) {
    return 'أدخل رمز التحقق المرسل إلى $destination.';
  }

  @override
  String get device_otp_label => 'رمز التحقق';

  @override
  String get device_otp_confirm => 'توثيق الجهاز';

  @override
  String get device_otp_destination_email => 'بريدك الإلكتروني';

  @override
  String get device_verification_cancelled => 'تم إلغاء توثيق الجهاز';

  @override
  String get device_verification_required =>
      'يجب توثيق الجهاز لإكمال تسجيل الدخول.';

  @override
  String biometric_login_button(Object method) {
    return 'تسجيل الدخول باستخدام $method';
  }

  @override
  String biometric_auth_reason(Object method) {
    return 'يرجى تأكيد هويتك باستخدام $method.';
  }

  @override
  String get biometric_enable_title => 'تفعيل تسجيل الدخول بالبصمة؟';

  @override
  String biometric_enable_message(Object method) {
    return 'هل تود استخدام $method لتسجيل الدخول بشكل أسرع؟';
  }

  @override
  String get biometric_enable_confirm => 'تفعيل';

  @override
  String get biometric_enable_skip => 'لاحقاً';

  @override
  String biometric_enabled_confirmation(Object method) {
    return 'تم تفعيل تسجيل الدخول بواسطة $method.';
  }

  @override
  String get biometric_not_configured =>
      'لم يتم إعداد تسجيل الدخول بالبصمة بعد.';

  @override
  String get biometric_auth_failed => 'فشل التحقق الحيوي.';

  @override
  String get biometric_method_face => 'بصمة الوجه';

  @override
  String get biometric_method_fingerprint => 'بصمة الإصبع';

  @override
  String get biometric_method_iris => 'بصمة العين';

  @override
  String get biometric_method_generic => 'البصمة الحيوية';

  @override
  String get guard_tasks_title => 'مهامي';

  @override
  String get guard_tasks_hint => 'تابع المهام المسندة وحدّث حالتها.';

  @override
  String get tasks_screen_title => 'مهامي';

  @override
  String get task_location_label => 'الموقع';

  @override
  String task_due_date(Object date) {
    return 'تاريخ الاستحقاق: $date';
  }

  @override
  String get task_status_note_label => 'ملاحظة';

  @override
  String get task_note_hint => 'أضف تفاصيل عن هذا التحديث (اختياري)';

  @override
  String get task_update_success => 'تم تحديث المهمة.';

  @override
  String get task_update_failure => 'تعذّر تحديث المهمة.';

  @override
  String get tasks_load_error => 'تعذّر تحميل المهام.';

  @override
  String task_update_button(Object status) {
    return 'تغيير الحالة إلى $status';
  }

  @override
  String task_note_dialog_title(Object status) {
    return 'تحديث إلى $status';
  }

  @override
  String get task_cancel => 'إلغاء';

  @override
  String get task_confirm => 'تأكيد';

  @override
  String get task_no_items => 'لا توجد مهام مسندة حالياً.';

  @override
  String get uniform_request_title => 'طلب زي';

  @override
  String get uniform_request_hint => 'اختر قطع الزي المطلوبة.';

  @override
  String get uniform_items_empty => 'لم تتم إضافة أي قطعة بعد.';

  @override
  String get uniform_items_required => 'يرجى إضافة قطعة واحدة على الأقل.';

  @override
  String get uniform_items_load_error => 'تعذّر تحميل قائمة الزي. حاول لاحقاً.';

  @override
  String get uniform_add_item => 'إضافة قطعة';

  @override
  String get uniform_edit_item => 'تعديل القطعة';

  @override
  String get uniform_select_item => 'اختر قطعة';

  @override
  String get uniform_quantity => 'الكمية';

  @override
  String get uniform_quantity_invalid => 'أدخل كمية صحيحة';

  @override
  String get uniform_item_notes => 'ملاحظات';

  @override
  String get uniform_payment_method => 'طريقة الدفع';

  @override
  String get uniform_payment_direct => 'دفع مباشر';

  @override
  String get uniform_payment_deduction => 'خصم من الراتب';

  @override
  String get uniform_item_remove => 'حذف';

  @override
  String uniform_total_value(Object value) {
    return 'الإجمالي التقريبي: $value';
  }

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
  String get open_advances => 'طلبات السلف';

  @override
  String get open_advances_hint => 'مراجعة طلبات السلف السابقة';

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
  String get create_advance => 'طلب سلفة جديد';

  @override
  String get create_advance_short => 'سلفة جديدة';

  @override
  String get create_advance_hint => 'إرسال طلب سلفة من الراتب';

  @override
  String get advance_amount => 'المبلغ';

  @override
  String get advance_amount_required => 'يرجى إدخال مبلغ صحيح';

  @override
  String get advance_reason => 'السبب (اختياري)';

  @override
  String get advance_submit => 'إرسال طلب السلفة';

  @override
  String get advance_submit_success => 'تم إرسال طلب السلفة';

  @override
  String get advance_submit_error => 'تعذر إرسال طلب السلفة';

  @override
  String get advances_load_error => 'تعذر تحميل السلف';

  @override
  String get advances_empty_state => 'لا توجد طلبات سلف حتى الآن.';

  @override
  String get advance_requested_on => 'تم الطلب في';

  @override
  String get advance_approved_on => 'تمت الموافقة في';

  @override
  String get currency_short_symbol => 'ر.س';

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
  String get request_leave => 'طلب إجازة';

  @override
  String get request_leave_hint => 'قدّم طلب إجازة إلى المشرف';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutTooltip => 'خروج من الحساب';

  @override
  String get environment_violation_title => 'تنبيه أمني';

  @override
  String environment_violation_message(Object issues) {
    return 'تم الكشف عن $issues. يرجى تعطيل برامج VPN أو تزييف الموقع لمتابعة استخدام التطبيق.';
  }

  @override
  String get environment_violation_reason_vpn => 'اتصال VPN نشط';

  @override
  String get environment_violation_reason_mock => 'تطبيق لتزييف الموقع';

  @override
  String get environment_violation_exit => 'إغلاق التطبيق';
}
