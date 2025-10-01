import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
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
  final base='http://31.97.158.157/api/v1';
  @override
  void dispose() { _u.dispose(); _p.dispose(); super.dispose(); }


  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);

    // أغلق الكيبورد
    FocusScope.of(context).unfocus();

    // تحقّق يدوي من القيم
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
      // 1) تسجيل الدخول (يحفظ التوكن الخام)
      final login = await ApiService.guardLogin(username, password);

      if (!mounted) return;

      if (login['ok'] == true) {
        // 2) ضمان وجود ملف الموظف في الكاش (سيجلب /auth/guard/me/ إن لم يكن محفوظًا)
        await ApiService.ensureEmployeeCached();

        messenger.showSnackBar(const SnackBar(content: Text("تم تسجيل الدخول")));
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        final msg = (login['message']?.toString() ?? 'فشل تسجيل الدخول');
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
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
