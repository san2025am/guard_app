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
  final _email = TextEditingController();
  bool _loading = false;
  bool _useEmail = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(()=>_loading=true);
    final r = _useEmail
        ? await ApiService.forgotByEmail(_email.text.trim())
        : await ApiService.forgotByUsername(_username.text.trim());
    setState(()=>_loading=false);
    if (!mounted) return;
    if (r['ok']==true && r['session_id'] != null) {
      final sid = r['session_id'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r['detail'] ??
            (_useEmail
                ? AppLocalizations.of(context)!.email_sent_success
                : AppLocalizations.of(context)!.send_code),
          ),
        ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ToggleButtons(
                isSelected: [!_useEmail, _useEmail],
                onPressed: (index) {
                  setState(() {
                    _useEmail = index == 1;
                  });
                },
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(t.forgot_via_username),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(t.forgot_via_email),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!_useEmail)
                TextFormField(
                  controller: _username,
                  decoration: InputDecoration(labelText: t.username),
                  validator: (v) => (v==null || v.trim().isEmpty) ? t.username : null,
                  onFieldSubmitted: (_) => _send(),
                )
              else
                TextFormField(
                  controller: _email,
                  decoration: InputDecoration(labelText: t.email),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return t.email_required;
                    final email = v.trim();
                    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!re.hasMatch(email)) return t.email_invalid;
                    return null;
                  },
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
