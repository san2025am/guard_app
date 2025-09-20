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

  @override
  void dispose() { _u.dispose(); _p.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final r = await ApiService.guardLogin(_u.text.trim(), _p.text);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.login)),
      );
      Navigator.of(context).pushReplacementNamed(HomeGuard.route);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r['message'] ?? 'Error')),
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
