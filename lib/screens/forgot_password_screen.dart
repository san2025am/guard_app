import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const route = '/forgot';
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _username.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(()=>_loading=true);
    final r = await ApiService.forgotByUsername(_username.text.trim());
    setState(()=>_loading=false);
    if (!mounted) return;
    if (r['ok']==true) {
      final sid = r['session_id'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r['detail'] ?? AppLocalizations.of(context)!.send_code)),
      );
      Navigator.of(context).pushNamed(
        ResetPasswordScreen.route,
        arguments: {'session_id': sid},
      );
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
      appBar: AppBar(title: Text(t.reset_password)),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _username,
                decoration: InputDecoration(labelText: t.username),
                validator: (v) => (v==null || v.trim().isEmpty) ? t.username : null,
                onFieldSubmitted: (_) => _send(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _send,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Text(t.send_code),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
