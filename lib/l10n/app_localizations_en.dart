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
  String get splash_tagline => 'A digital companion for security guards.';

  @override
  String get splash_loading => 'Preparing your workspace...';

  @override
  String get theme_light => 'Light';

  @override
  String get theme_dark => 'Dark';

  @override
  String get toggle_theme => 'Toggle Theme';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'Arabic';

  @override
  String get english => 'English';

  @override
  String get language_settings_title => 'Language settings';

  @override
  String get language_settings_hint => 'Choose the language you prefer to use in the app.';

  @override
  String get login => 'Login';

  @override
  String get username => 'Username';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get email_required => 'Please enter your email';

  @override
  String get email_invalid => 'Enter a valid email address';

  @override
  String get forgot_password => 'Forgot password?';

  @override
  String get forgot_via_username => 'Use username';

  @override
  String get forgot_via_email => 'Use email';

  @override
  String get send_code => 'Send reset code';

  @override
  String get email_sent_success => "We've sent a reset link to your email.";

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
  String get open_requests => 'Open requests';

  @override
  String get open_requests_hint => 'View and track your requests';

  @override
  String get request_leave => 'Request leave';

  @override
  String get request_leave_hint => 'Submit a leave request';

  @override
  String get coming_soon => 'Coming soon';

  @override
  String get logout => 'Logout';

  @override
  String get logoutTooltip => 'Sign out of the account';
}
