import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @app_title.
  ///
  /// In en, this message translates to:
  /// **'Sanam Security'**
  String get app_title;

  /// No description provided for @theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get theme_light;

  /// No description provided for @theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get theme_dark;

  /// No description provided for @toggle_theme.
  ///
  /// In en, this message translates to:
  /// **'Toggle Theme'**
  String get toggle_theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @language_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Language preferences'**
  String get language_settings_title;

  /// No description provided for @language_settings_hint.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language below'**
  String get language_settings_hint;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @session_timeout_title.
  ///
  /// In en, this message translates to:
  /// **'Session timeout'**
  String get session_timeout_title;

  /// No description provided for @session_timeout_message.
  ///
  /// In en, this message translates to:
  /// **'No activity detected. You will be logged out in {seconds} seconds.'**
  String session_timeout_message(int seconds);

  /// No description provided for @session_timeout_keep.
  ///
  /// In en, this message translates to:
  /// **'Keep working'**
  String get session_timeout_keep;

  /// No description provided for @session_timeout_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout now'**
  String get session_timeout_logout;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgot_password.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgot_password;

  /// No description provided for @device_untrusted_title.
  ///
  /// In en, this message translates to:
  /// **'Unregistered Device'**
  String get device_untrusted_title;

  /// No description provided for @device_untrusted_message.
  ///
  /// In en, this message translates to:
  /// **'Dear user, this device is not trusted yet. If you want to continue, you need to add it to your trusted devices list.'**
  String get device_untrusted_message;

  /// No description provided for @device_untrusted_accept.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get device_untrusted_accept;

  /// No description provided for @device_untrusted_decline.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get device_untrusted_decline;

  /// No description provided for @device_otp_instructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code sent to {destination}.'**
  String device_otp_instructions(Object destination);

  /// No description provided for @device_otp_label.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get device_otp_label;

  /// No description provided for @device_otp_confirm.
  ///
  /// In en, this message translates to:
  /// **'Verify device'**
  String get device_otp_confirm;

  /// No description provided for @device_otp_destination_email.
  ///
  /// In en, this message translates to:
  /// **'your email'**
  String get device_otp_destination_email;

  /// No description provided for @device_verification_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Device verification cancelled'**
  String get device_verification_cancelled;

  /// No description provided for @device_verification_required.
  ///
  /// In en, this message translates to:
  /// **'Device verification is required to complete the login.'**
  String get device_verification_required;

  /// No description provided for @biometric_login_button.
  ///
  /// In en, this message translates to:
  /// **'Log in with {method}'**
  String biometric_login_button(Object method);

  /// No description provided for @biometric_auth_reason.
  ///
  /// In en, this message translates to:
  /// **'Confirm your identity using {method}.'**
  String biometric_auth_reason(Object method);

  /// No description provided for @biometric_enable_title.
  ///
  /// In en, this message translates to:
  /// **'Enable biometric login?'**
  String get biometric_enable_title;

  /// No description provided for @biometric_enable_message.
  ///
  /// In en, this message translates to:
  /// **'Would you like to use {method} for faster logins?'**
  String biometric_enable_message(Object method);

  /// No description provided for @biometric_enable_confirm.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get biometric_enable_confirm;

  /// No description provided for @biometric_enable_skip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get biometric_enable_skip;

  /// No description provided for @biometric_enabled_confirmation.
  ///
  /// In en, this message translates to:
  /// **'Biometric login with {method} has been enabled.'**
  String biometric_enabled_confirmation(Object method);

  /// No description provided for @biometric_not_configured.
  ///
  /// In en, this message translates to:
  /// **'Biometric login is not configured yet.'**
  String get biometric_not_configured;

  /// No description provided for @biometric_auth_failed.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication failed.'**
  String get biometric_auth_failed;

  /// No description provided for @biometric_method_face.
  ///
  /// In en, this message translates to:
  /// **'Face ID'**
  String get biometric_method_face;

  /// No description provided for @biometric_method_fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get biometric_method_fingerprint;

  /// No description provided for @biometric_method_iris.
  ///
  /// In en, this message translates to:
  /// **'Iris'**
  String get biometric_method_iris;

  /// No description provided for @biometric_method_generic.
  ///
  /// In en, this message translates to:
  /// **'Biometric'**
  String get biometric_method_generic;

  /// No description provided for @send_code.
  ///
  /// In en, this message translates to:
  /// **'Send code to email'**
  String get send_code;

  /// No description provided for @reset_password.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get reset_password;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code (6 digits)'**
  String get code;

  /// No description provided for @new_password.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get new_password;

  /// No description provided for @change_password.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get change_password;

  /// No description provided for @guard_home.
  ///
  /// In en, this message translates to:
  /// **'Guard Dashboard'**
  String get guard_home;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcome;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @reports_requests.
  ///
  /// In en, this message translates to:
  /// **'Reports & Requests'**
  String get reports_requests;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get sync;

  /// No description provided for @sync_hint.
  ///
  /// In en, this message translates to:
  /// **'Pull latest username/role from device'**
  String get sync_hint;

  /// No description provided for @checked_in.
  ///
  /// In en, this message translates to:
  /// **'You are checked in'**
  String get checked_in;

  /// No description provided for @checked_out.
  ///
  /// In en, this message translates to:
  /// **'You are checked out'**
  String get checked_out;

  /// No description provided for @check_in.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get check_in;

  /// No description provided for @check_out.
  ///
  /// In en, this message translates to:
  /// **'Check out'**
  String get check_out;

  /// No description provided for @attendance_history.
  ///
  /// In en, this message translates to:
  /// **'Attendance history'**
  String get attendance_history;

  /// No description provided for @attendance_history_hint.
  ///
  /// In en, this message translates to:
  /// **'View your past check-ins'**
  String get attendance_history_hint;

  /// No description provided for @create_report.
  ///
  /// In en, this message translates to:
  /// **'Create report'**
  String get create_report;

  /// No description provided for @create_report_hint.
  ///
  /// In en, this message translates to:
  /// **'Send a new report to supervisor'**
  String get create_report_hint;

  /// No description provided for @report_subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get report_subject;

  /// No description provided for @report_subject_required.
  ///
  /// In en, this message translates to:
  /// **'Subject is required'**
  String get report_subject_required;

  /// No description provided for @report_details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get report_details;

  /// No description provided for @report_details_required.
  ///
  /// In en, this message translates to:
  /// **'Details are required'**
  String get report_details_required;

  /// No description provided for @report_type_label.
  ///
  /// In en, this message translates to:
  /// **'Report type'**
  String get report_type_label;

  /// No description provided for @report_type_required.
  ///
  /// In en, this message translates to:
  /// **'Please choose the report type'**
  String get report_type_required;

  /// No description provided for @report_type_daily.
  ///
  /// In en, this message translates to:
  /// **'Daily report'**
  String get report_type_daily;

  /// No description provided for @report_type_monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly report'**
  String get report_type_monthly;

  /// No description provided for @report_type_security.
  ///
  /// In en, this message translates to:
  /// **'Security incident'**
  String get report_type_security;

  /// No description provided for @report_type_complaint.
  ///
  /// In en, this message translates to:
  /// **'Complaint'**
  String get report_type_complaint;

  /// No description provided for @report_add_attachment.
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get report_add_attachment;

  /// No description provided for @report_attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get report_attachments;

  /// No description provided for @report_attachment_image_camera.
  ///
  /// In en, this message translates to:
  /// **'Capture photo'**
  String get report_attachment_image_camera;

  /// No description provided for @report_attachment_image_gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose photo from gallery'**
  String get report_attachment_image_gallery;

  /// No description provided for @report_attachment_video_camera.
  ///
  /// In en, this message translates to:
  /// **'Record video'**
  String get report_attachment_video_camera;

  /// No description provided for @report_attachment_video_gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose video from gallery'**
  String get report_attachment_video_gallery;

  /// No description provided for @report_attachment_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get report_attachment_remove;

  /// No description provided for @report_attachment_pick_error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t pick attachment'**
  String get report_attachment_pick_error;

  /// No description provided for @submit_report.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get submit_report;

  /// No description provided for @report_submit_success.
  ///
  /// In en, this message translates to:
  /// **'Report submitted successfully'**
  String get report_submit_success;

  /// No description provided for @report_submit_error.
  ///
  /// In en, this message translates to:
  /// **'Could not submit the report'**
  String get report_submit_error;

  /// No description provided for @open_requests.
  ///
  /// In en, this message translates to:
  /// **'Open requests'**
  String get open_requests;

  /// No description provided for @open_requests_hint.
  ///
  /// In en, this message translates to:
  /// **'View and track your requests'**
  String get open_requests_hint;

  /// No description provided for @requests_empty_state.
  ///
  /// In en, this message translates to:
  /// **'No open requests yet.'**
  String get requests_empty_state;

  /// No description provided for @requests_load_error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load requests'**
  String get requests_load_error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @open_advances.
  ///
  /// In en, this message translates to:
  /// **'Advance requests'**
  String get open_advances;

  /// No description provided for @open_advances_hint.
  ///
  /// In en, this message translates to:
  /// **'Review submitted salary advances'**
  String get open_advances_hint;

  /// No description provided for @request_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get request_type;

  /// No description provided for @request_status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get request_status;

  /// No description provided for @request_submitted_on.
  ///
  /// In en, this message translates to:
  /// **'Submitted on'**
  String get request_submitted_on;

  /// No description provided for @create_request.
  ///
  /// In en, this message translates to:
  /// **'Create request'**
  String get create_request;

  /// No description provided for @create_request_hint.
  ///
  /// In en, this message translates to:
  /// **'Send a new request'**
  String get create_request_hint;

  /// No description provided for @request_type_required.
  ///
  /// In en, this message translates to:
  /// **'Please choose a request type'**
  String get request_type_required;

  /// No description provided for @request_type_coverage.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get request_type_coverage;

  /// No description provided for @request_type_leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get request_type_leave;

  /// No description provided for @request_type_transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get request_type_transfer;

  /// No description provided for @request_type_materials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get request_type_materials;

  /// No description provided for @request_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get request_description;

  /// No description provided for @request_description_required.
  ///
  /// In en, this message translates to:
  /// **'Description is required'**
  String get request_description_required;

  /// No description provided for @leave_start_datetime.
  ///
  /// In en, this message translates to:
  /// **'Leave start'**
  String get leave_start_datetime;

  /// No description provided for @leave_end_datetime.
  ///
  /// In en, this message translates to:
  /// **'Leave end'**
  String get leave_end_datetime;

  /// No description provided for @leave_start_not_selected.
  ///
  /// In en, this message translates to:
  /// **'No start selected'**
  String get leave_start_not_selected;

  /// No description provided for @leave_end_not_selected.
  ///
  /// In en, this message translates to:
  /// **'No end selected'**
  String get leave_end_not_selected;

  /// No description provided for @leave_pick_dates_required.
  ///
  /// In en, this message translates to:
  /// **'Please select start and end for the leave'**
  String get leave_pick_dates_required;

  /// No description provided for @leave_end_must_follow_start.
  ///
  /// In en, this message translates to:
  /// **'End must be after start'**
  String get leave_end_must_follow_start;

  /// No description provided for @leave_range.
  ///
  /// In en, this message translates to:
  /// **'Leave period'**
  String get leave_range;

  /// No description provided for @leave_hours_label.
  ///
  /// In en, this message translates to:
  /// **'Leave hours'**
  String get leave_hours_label;

  /// No description provided for @create_advance.
  ///
  /// In en, this message translates to:
  /// **'New advance request'**
  String get create_advance;

  /// No description provided for @create_advance_short.
  ///
  /// In en, this message translates to:
  /// **'New advance'**
  String get create_advance_short;

  /// No description provided for @create_advance_hint.
  ///
  /// In en, this message translates to:
  /// **'Submit a salary advance request'**
  String get create_advance_hint;

  /// No description provided for @advance_amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get advance_amount;

  /// No description provided for @advance_amount_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get advance_amount_required;

  /// No description provided for @advance_reason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get advance_reason;

  /// No description provided for @advance_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit advance'**
  String get advance_submit;

  /// No description provided for @advance_submit_success.
  ///
  /// In en, this message translates to:
  /// **'Advance request submitted'**
  String get advance_submit_success;

  /// No description provided for @advance_submit_error.
  ///
  /// In en, this message translates to:
  /// **'Could not submit the advance request'**
  String get advance_submit_error;

  /// No description provided for @advances_load_error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load advances'**
  String get advances_load_error;

  /// No description provided for @advances_empty_state.
  ///
  /// In en, this message translates to:
  /// **'No advances yet.'**
  String get advances_empty_state;

  /// No description provided for @advance_requested_on.
  ///
  /// In en, this message translates to:
  /// **'Requested on'**
  String get advance_requested_on;

  /// No description provided for @advance_approved_on.
  ///
  /// In en, this message translates to:
  /// **'Approved on'**
  String get advance_approved_on;

  /// No description provided for @currency_short_symbol.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get currency_short_symbol;

  /// No description provided for @submit_request.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get submit_request;

  /// No description provided for @request_submit_success.
  ///
  /// In en, this message translates to:
  /// **'Request submitted successfully'**
  String get request_submit_success;

  /// No description provided for @request_submit_error.
  ///
  /// In en, this message translates to:
  /// **'Could not submit the request'**
  String get request_submit_error;

  /// No description provided for @request_approval_notes.
  ///
  /// In en, this message translates to:
  /// **'Decision notes'**
  String get request_approval_notes;

  /// No description provided for @request_approver.
  ///
  /// In en, this message translates to:
  /// **'Handled by'**
  String get request_approver;

  /// No description provided for @coming_soon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get coming_soon;

  /// No description provided for @request_leave.
  ///
  /// In en, this message translates to:
  /// **'Leave request'**
  String get request_leave;

  /// No description provided for @request_leave_hint.
  ///
  /// In en, this message translates to:
  /// **'Submit a leave request to your supervisor'**
  String get request_leave_hint;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sign out of the account'**
  String get logoutTooltip;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
