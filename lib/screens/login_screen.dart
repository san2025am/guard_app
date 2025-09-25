import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/auth.dart';
import 'forgot_password_screen.dart';
import 'home_guard.dart';

class LoginScreen extends StatefulWidget {
  static const route = '/login';
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _obscure = true, _loading = false;

  @override
  void dispose() { _u.dispose(); _p.dispose(); super.dispose(); }


  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    // ⚠️ baseUrl = الجذر فقط (بدون /api/v1/)
    const base = "http://31.97.158.157/api/v1";

    // 1) دخول + حفظ التوكن
    final loginRes = await loginAndStoreToken(
      baseUrl: base,
      username: _u.text.trim(),
      password: _p.text,
    );

    if (!mounted) return;

    if (!loginRes.ok) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loginRes.message)),
      );
      return;
    }

    // 2) اقرأ الهيدر المخزَّن "Bearer <access>"
    final token = await getAuthHeader();
    if (token == null || token.isEmpty) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تعذّر قراءة التوكن بعد تسجيل الدخول.")),
      );
      return;
    }

    // 3) نداءك الثاني: إرسال بيانات إضافية/جلب بروفايل مع التوكن
    final r = await ApiService.guardLoginWithToken(
      baseUrl: base,   // هنا يمكنك إضافة /api/v1/ داخل الدالة نفسها
      authHeader: token,
      // مثلاً: deviceId/appVersion إن احتجت
      // deviceId: await _readDeviceId(),
      // appVersion: '1.0.0',
    );

    setState(() => _loading = false);
    if (!mounted) return;

    if (r['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تسجيل الدخول")),
      );
      Navigator.of(context).pushReplacementNamed('/home'); // أو HomeGuard.route
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r['message'] ?? 'خطأ غير معروف')),
      );
    }
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
