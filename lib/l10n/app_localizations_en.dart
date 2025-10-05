// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_title => 'Sanam Security';

  @override
  String get theme_light => 'Light';

  @override
  String get theme_dark => 'Dark';

  @override
  String get toggle_theme => 'Toggle Theme';

  @override
  String get language => 'Language';

  @override
  String get language_settings_title => 'Language preferences';

  @override
  String get language_settings_hint => 'Choose your preferred language below';

  @override
  String get arabic => 'Arabic';

  @override
  String get english => 'English';

  @override
  String get session_timeout_title => 'Session timeout';

  @override
  String session_timeout_message(int seconds) {
    return 'No activity detected. You will be logged out in $seconds seconds.';
  }

  @override
  String get session_timeout_keep => 'Keep working';

  @override
  String get session_timeout_logout => 'Logout now';

  @override
  String get login => 'Login';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get forgot_password => 'Forgot password?';

  @override
  String get device_untrusted_title => 'Unregistered Device';

  @override
  String get device_untrusted_message =>
      'Dear user, this device is not trusted yet. If you want to continue, you need to add it to your trusted devices list.';

  @override
  String get device_untrusted_accept => 'Yes';

  @override
  String get device_untrusted_decline => 'No';

  @override
  String device_otp_instructions(Object destination) {
    return 'Enter the verification code sent to $destination.';
  }

  @override
  String get device_otp_label => 'Verification code';

  @override
  String get device_otp_confirm => 'Verify device';

  @override
  String get device_otp_destination_email => 'your email';

  @override
  String get device_verification_cancelled => 'Device verification cancelled';

  @override
  String get device_verification_required =>
      'Device verification is required to complete the login.';

  @override
  String biometric_login_button(Object method) {
    return 'Log in with $method';
  }

  @override
  String biometric_auth_reason(Object method) {
    return 'Confirm your identity using $method.';
  }

  @override
  String get biometric_enable_title => 'Enable biometric login?';

  @override
  String biometric_enable_message(Object method) {
    return 'Would you like to use $method for faster logins?';
  }

  @override
  String get biometric_enable_confirm => 'Enable';

  @override
  String get biometric_enable_skip => 'Not now';

  @override
  String biometric_enabled_confirmation(Object method) {
    return 'Biometric login with $method has been enabled.';
  }

  @override
  String get biometric_not_configured =>
      'Biometric login is not configured yet.';

  @override
  String get biometric_auth_failed => 'Biometric authentication failed.';

  @override
  String get biometric_method_face => 'Face ID';

  @override
  String get biometric_method_fingerprint => 'Fingerprint';

  @override
  String get biometric_method_iris => 'Iris';

  @override
  String get biometric_method_generic => 'Biometric';

  @override
  String get guard_tasks_title => 'My tasks';

  @override
  String get guard_tasks_hint =>
      'Track assigned tasks and update their status.';

  @override
  String get tasks_screen_title => 'My Tasks';

  @override
  String get task_location_label => 'Location';

  @override
  String task_due_date(Object date) {
    return 'Due: $date';
  }

  @override
  String get task_status_note_label => 'Note';

  @override
  String get task_note_hint => 'Add details for this status update (optional)';

  @override
  String get task_update_success => 'Task updated successfully.';

  @override
  String get task_update_failure => 'Couldn\'t update the task.';

  @override
  String get tasks_load_error => 'Couldn\'t load tasks.';

  @override
  String task_update_button(Object status) {
    return 'Move to $status';
  }

  @override
  String task_note_dialog_title(Object status) {
    return 'Update to $status';
  }

  @override
  String get task_cancel => 'Cancel';

  @override
  String get task_confirm => 'Confirm';

  @override
  String get task_no_items => 'No tasks assigned at the moment.';

  @override
  String get uniform_request_title => 'Uniform request';

  @override
  String get uniform_request_hint => 'Select the pieces you need to request.';

  @override
  String get uniform_items_empty => 'No pieces selected yet.';

  @override
  String get uniform_items_required => 'Please add at least one uniform piece.';

  @override
  String get uniform_items_load_error =>
      'Couldn\'t load uniform items. Try again later.';

  @override
  String get uniform_add_item => 'Add piece';

  @override
  String get uniform_edit_item => 'Edit piece';

  @override
  String get uniform_select_item => 'Choose a piece';

  @override
  String get uniform_quantity => 'Quantity';

  @override
  String get uniform_quantity_invalid => 'Enter a valid quantity';

  @override
  String get uniform_item_notes => 'Notes';

  @override
  String get uniform_payment_method => 'Payment method';

  @override
  String get uniform_payment_direct => 'Direct payment';

  @override
  String get uniform_payment_deduction => 'Salary deduction';

  @override
  String get uniform_item_remove => 'Remove';

  @override
  String uniform_total_value(Object value) {
    return 'Estimated total: $value';
  }

  @override
  String get send_code => 'Send code to email';

  @override
  String get reset_password => 'Reset password';

  @override
  String get code => 'Code (6 digits)';

  @override
  String get new_password => 'New password';

  @override
  String get change_password => 'Change password';

  @override
  String get guard_home => 'Guard Dashboard';

  @override
  String get welcome => 'Welcome!';

  @override
  String get profile => 'Profile';

  @override
  String get attendance => 'Attendance';

  @override
  String get reports_requests => 'Reports & Requests';

  @override
  String get role => 'Role';

  @override
  String get sync => 'Refresh';

  @override
  String get sync_hint => 'Pull latest username/role from device';

  @override
  String get checked_in => 'You are checked in';

  @override
  String get checked_out => 'You are checked out';

  @override
  String get check_in => 'Check in';

  @override
  String get check_out => 'Check out';

  @override
  String get attendance_history => 'Attendance history';

  @override
  String get attendance_history_hint => 'View your past check-ins';

  @override
  String get create_report => 'Create report';

  @override
  String get create_report_hint => 'Send a new report to supervisor';

  @override
  String get report_subject => 'Subject';

  @override
  String get report_subject_required => 'Subject is required';

  @override
  String get report_details => 'Details';

  @override
  String get report_details_required => 'Details are required';

  @override
  String get report_type_label => 'Report type';

  @override
  String get report_type_required => 'Please choose the report type';

  @override
  String get report_type_daily => 'Daily report';

  @override
  String get report_type_monthly => 'Monthly report';

  @override
  String get report_type_security => 'Security incident';

  @override
  String get report_type_complaint => 'Complaint';

  @override
  String get report_add_attachment => 'Add attachment';

  @override
  String get report_attachments => 'Attachments';

  @override
  String get report_attachment_image_camera => 'Capture photo';

  @override
  String get report_attachment_image_gallery => 'Choose photo from gallery';

  @override
  String get report_attachment_video_camera => 'Record video';

  @override
  String get report_attachment_video_gallery => 'Choose video from gallery';

  @override
  String get report_attachment_remove => 'Remove';

  @override
  String get report_attachment_pick_error => 'Couldn\'t pick attachment';

  @override
  String get submit_report => 'Submit report';

  @override
  String get report_submit_success => 'Report submitted successfully';

  @override
  String get report_submit_error => 'Could not submit the report';

  @override
  String get open_requests => 'Open requests';

  @override
  String get open_requests_hint => 'View and track your requests';

  @override
  String get requests_empty_state => 'No open requests yet.';

  @override
  String get requests_load_error => 'Couldn\'t load requests';

  @override
  String get retry => 'Retry';

  @override
  String get open_advances => 'Advance requests';

  @override
  String get open_advances_hint => 'Review submitted salary advances';

  @override
  String get request_type => 'Type';

  @override
  String get request_status => 'Status';

  @override
  String get request_submitted_on => 'Submitted on';

  @override
  String get create_request => 'Create request';

  @override
  String get create_request_hint => 'Send a new request';

  @override
  String get request_type_required => 'Please choose a request type';

  @override
  String get request_type_coverage => 'Coverage';

  @override
  String get request_type_leave => 'Leave';

  @override
  String get request_type_transfer => 'Transfer';

  @override
  String get request_type_materials => 'Materials';

  @override
  String get request_description => 'Description';

  @override
  String get request_description_required => 'Description is required';

  @override
  String get leave_start_datetime => 'Leave start';

  @override
  String get leave_end_datetime => 'Leave end';

  @override
  String get leave_start_not_selected => 'No start selected';

  @override
  String get leave_end_not_selected => 'No end selected';

  @override
  String get leave_pick_dates_required =>
      'Please select start and end for the leave';

  @override
  String get leave_end_must_follow_start => 'End must be after start';

  @override
  String get leave_range => 'Leave period';

  @override
  String get leave_hours_label => 'Leave hours';

  @override
  String get create_advance => 'New advance request';

  @override
  String get create_advance_short => 'New advance';

  @override
  String get create_advance_hint => 'Submit a salary advance request';

  @override
  String get advance_amount => 'Amount';

  @override
  String get advance_amount_required => 'Please enter a valid amount';

  @override
  String get advance_reason => 'Reason (optional)';

  @override
  String get advance_submit => 'Submit advance';

  @override
  String get advance_submit_success => 'Advance request submitted';

  @override
  String get advance_submit_error => 'Could not submit the advance request';

  @override
  String get advances_load_error => 'Couldn\'t load advances';

  @override
  String get advances_empty_state => 'No advances yet.';

  @override
  String get advance_requested_on => 'Requested on';

  @override
  String get advance_approved_on => 'Approved on';

  @override
  String get currency_short_symbol => 'SAR';

  @override
  String get submit_request => 'Submit request';

  @override
  String get request_submit_success => 'Request submitted successfully';

  @override
  String get request_submit_error => 'Could not submit the request';

  @override
  String get request_approval_notes => 'Decision notes';

  @override
  String get request_approver => 'Handled by';

  @override
  String get coming_soon => 'Coming soon';

  @override
  String get request_leave => 'Leave request';

  @override
  String get request_leave_hint => 'Submit a leave request to your supervisor';

  @override
  String get logout => 'Logout';

  @override
  String get logoutTooltip => 'Sign out of the account';

  @override
  String get environment_violation_title => 'Security Warning';

  @override
  String environment_violation_message(Object issues) {
    return 'We detected $issues. Please disable VPN or mock-location tools before using the app.';
  }

  @override
  String get environment_violation_reason_vpn => 'an active VPN connection';

  @override
  String get environment_violation_reason_mock => 'a mock-location application';

  @override
  String get environment_violation_exit => 'Exit app';
}
