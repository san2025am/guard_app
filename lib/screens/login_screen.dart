/// شاشة تسجيل الدخول وتفعيل الدخول البيومتري.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/biometric_auth.dart';
import '../services/device_identity.dart';
import 'forgot_password_screen.dart';

/// تجمع الحقول والإجراءات الخاصة بتسجيل الدخول.
class LoginScreen extends StatefulWidget {
  static const route = '/login';
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// يحتوي على منطق التحقق والاتصال بالـ API.
class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _obscure = true, _loading = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  BiometricMethod? _biometricMethod;

  @override
  void initState() {
    super.initState();
    _initBiometricAvailability();
  }

  @override
  void dispose() { _u.dispose(); _p.dispose(); super.dispose(); }

  void _showLoginError(ScaffoldMessengerState messenger, Map<String, dynamic> payload, String fallback) {
    final status = payload['statusCode'];
    final raw = payload['message'];
    final messageText = raw == null ? '' : raw.toString().trim();
    final message = messageText.isNotEmpty ? messageText : fallback;
    final display = status == null ? message : '$message (رمز $status)';
    messenger.showSnackBar(SnackBar(content: Text(display)));
  }

  Future<void> _initBiometricAvailability() async {
    final canCheck = await BiometricAuthService.isBiometricAvailable();
    final method = canCheck ? await BiometricAuthService.preferredMethod() : null;
    final hasCreds = canCheck ? await BiometricAuthService.hasStoredCredentials() : false;
    if (!mounted) return;
    setState(() {
      _biometricMethod = method;
      _biometricAvailable = canCheck && method != null;
      _biometricEnabled = hasCreds && method != null;
    });
  }

  String _biometricMethodLabel(AppLocalizations t) {
    switch (_biometricMethod) {
      case BiometricMethod.face:
        return t.biometric_method_face;
      case BiometricMethod.fingerprint:
        return t.biometric_method_fingerprint;
      case BiometricMethod.iris:
        return t.biometric_method_iris;
      case BiometricMethod.generic:
        return t.biometric_method_generic;
      case null:
        return t.biometric_method_generic;
    }
  }

  IconData _biometricMethodIcon() {
    switch (_biometricMethod) {
      case BiometricMethod.face:
        return Icons.face;
      case BiometricMethod.fingerprint:
        return Icons.fingerprint;
      case BiometricMethod.iris:
        return Icons.remove_red_eye;
      case BiometricMethod.generic:
        return Icons.verified_user;
      case null:
        return Icons.verified_user;
    }
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);

    FocusScope.of(context).unfocus();

    final username = _u.text.trim();
    final password = _p.text;

    if (username.isEmpty || password.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text("اسم المستخدم/كلمة المرور مطلوبة")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final device = await DeviceIdentityService.load();
      final login = await ApiService.guardLogin(
        username,
        password,
        deviceId: device.id,
        deviceName: device.name,
      );

      if (!mounted) return;

      if (login['ok'] == true) {
        await _completeLogin(
          messenger,
          username: username,
          password: password,
          offerBiometric: true,
        );
        return;
      }

      if (login['requires_verification'] == true) {
        await _handleDeviceChallenge(
          messenger: messenger,
          username: username,
          password: password,
          device: device,
          apiResponse: login,
        );
        return;
      }

      _showLoginError(messenger, login, 'فشل تسجيل الدخول');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithBiometric() async {
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context)!;

    final method = _biometricMethod;
    if (!_biometricEnabled || method == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.biometric_not_configured)));
      return;
    }

    final authorized = await BiometricAuthService.authenticate(
      reason: t.biometric_auth_reason(_biometricMethodLabel(t)),
    );
    if (!authorized) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(t.biometric_auth_failed)));
      return;
    }

    final creds = await BiometricAuthService.readCredentials();
    if (creds == null) {
      await BiometricAuthService.clearCredentials();
      await _initBiometricAvailability();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(t.biometric_not_configured)));
      return;
    }

    setState(() => _loading = true);
    try {
      final device = await DeviceIdentityService.load();
      final login = await ApiService.guardLogin(
        creds.username,
        creds.password,
        deviceId: device.id,
        deviceName: device.name,
      );

      if (!mounted) return;

      if (login['ok'] == true) {
        await _completeLogin(
          messenger,
          username: creds.username,
          password: creds.password,
          offerBiometric: false,
        );
        return;
      }

      if (login['requires_verification'] == true) {
        await _handleDeviceChallenge(
          messenger: messenger,
          username: creds.username,
          password: creds.password,
          device: device,
          apiResponse: login,
        );
        return;
      }

      _showLoginError(messenger, login, t.device_verification_required);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeLogin(
    ScaffoldMessengerState messenger, {
    String? username,
    String? password,
    bool offerBiometric = false,
  }) async {
    await ApiService.ensureEmployeeCached();
    if (!mounted) return;
    if (offerBiometric && !_biometricEnabled && username != null && password != null) {
      await _maybeOfferBiometric(
        messenger: messenger,
        username: username,
        password: password,
      );
    }
    messenger.showSnackBar(const SnackBar(content: Text('تم تسجيل الدخول')));
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _maybeOfferBiometric({
    required ScaffoldMessengerState messenger,
    required String username,
    required String password,
  }) async {
    await _initBiometricAvailability();
    if (!_biometricAvailable || _biometricMethod == null) {
      return;
    }

    final t = AppLocalizations.of(context)!;
    final methodLabel = _biometricMethodLabel(t);
    final shouldEnable = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              title: Text(t.biometric_enable_title),
              content: Text(t.biometric_enable_message(methodLabel)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(t.biometric_enable_skip),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(t.biometric_enable_confirm),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted || !shouldEnable) {
      return;
    }

    await BiometricAuthService.storeCredentials(username, password);
    await _initBiometricAvailability();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(t.biometric_enabled_confirmation(methodLabel))),
    );
  }

  Future<void> _handleDeviceChallenge({
    required ScaffoldMessengerState messenger,
    required String username,
    required String password,
    required DeviceIdentity device,
    required Map<String, dynamic> apiResponse,
  }) async {
    if (!mounted) return;
    final t = AppLocalizations.of(context)!;

    final debugCodeRaw = apiResponse['debug_code']?.toString();
    final debugCode = (debugCodeRaw != null && debugCodeRaw.trim().isNotEmpty)
        ? debugCodeRaw.trim()
        : null;

    final detailBase = (apiResponse['message']?.toString() ?? t.device_verification_required);
    final destinationRaw = apiResponse['destination']?.toString();
    final destination = (destinationRaw == null || destinationRaw.isEmpty)
        ? t.device_otp_destination_email
        : destinationRaw;
    final detail = debugCode == null
        ? detailBase
        : '$detailBase\n\n${t.device_otp_label}: $debugCode';
    final challengeId = apiResponse['challenge_id']?.toString();
    if (challengeId == null || challengeId.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(t.device_verification_required)));
      return;
    }

    setState(() => _loading = false);

    final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              title: Center(child: Text(t.device_untrusted_title)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0xFFE7E9FF),
                    child: Icon(Icons.logout, size: 36, color: Color(0xFF3F51B5)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(t.device_untrusted_decline),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(t.device_untrusted_accept),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted) return;

    if (!proceed) {
      messenger.showSnackBar(SnackBar(content: Text(t.device_verification_cancelled)));
      return;
    }

    final otp = await _promptForOtp(
      instructions: debugCode == null
          ? t.device_otp_instructions(destination)
          : '${t.device_otp_instructions(destination)}\n\n${t.device_otp_label}: $debugCode',
      label: t.device_otp_label,
      confirmLabel: t.device_otp_confirm,
      cancelLabel: t.device_untrusted_decline,
    );

    if (!mounted) return;

    if (otp == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.device_verification_cancelled)));
      return;
    }

    setState(() => _loading = true);
    try {
      final verify = await ApiService.guardLogin(
        username,
        password,
        deviceId: device.id,
        deviceName: device.name,
        challengeId: challengeId,
        otpCode: otp,
      );

      if (!mounted) return;

      if (verify['ok'] == true) {
        await _completeLogin(
          messenger,
          username: username,
          password: password,
          offerBiometric: true,
        );
        return;
      }

      _showLoginError(messenger, verify, t.device_verification_required);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _promptForOtp({
    required String instructions,
    required String label,
    required String confirmLabel,
    required String cancelLabel,
  }) async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Center(child: Text(label)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    instructions,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: label,
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(cancelLabel),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.length < 4) {
                      setState(() => errorText = label);
                      return;
                    }
                    Navigator.of(ctx).pop(value);
                  },
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/logo.png', height: 78),
                      const SizedBox(height: 12),
                      Text(t.login, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _u,
                        decoration: InputDecoration(labelText: t.username),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v==null||v.trim().isEmpty) ? t.username : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _p,
                        decoration: InputDecoration(
                          labelText: t.password,
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            onPressed: ()=>setState(()=>_obscure=!_obscure),
                          ),
                        ),
                        obscureText: _obscure,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) => (v==null||v.isEmpty) ? t.password : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: ()=> Navigator.of(context).pushNamed(ForgotPasswordScreen.route),
                            child: Text(t.forgot_password),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))
                              : const Icon(Icons.lock_open),
                          label: Text(t.login),
                        ),
                      ),
                      if (_biometricAvailable && _biometricEnabled) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _loginWithBiometric,
                            icon: Icon(_biometricMethodIcon()),
                            label: Text(
                              t.biometric_login_button(_biometricMethodLabel(t)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
