/// شاشة إدخال رمز التحقق وكلمة المرور الجديدة.
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';

/// تنهي عملية استعادة كلمة المرور بعد إدخال الرمز.
class ResetPasswordScreen extends StatefulWidget {
  static const route = '/reset';
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

/// يتابع الجلسة النشطة ويرسل الطلب النهائي للتغيير.
class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _pass = TextEditingController();
  int? _sessionId;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    _sessionId ??= args?['session_id'] as int?;
  }

  @override
  void dispose() { _code.dispose(); _pass.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    if (!_form.currentState!.validate()) return;
    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.reset_password)));
      return;
    }
    setState(()=>_loading=true);
    final r = await ApiService.resetBySession(
      sessionId: _sessionId!,
      code: _code.text.trim(),
      newPassword: _pass.text,
    );
    setState(()=>_loading=false);
    if (!mounted) return;
    if (r['ok']==true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['detail'] ?? t.change_password)));
      Navigator.of(context).popUntil((r)=>r.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['message'] ?? 'Error')));
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
              Text('${t.code} — session: ${_sessionId ?? "-"}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                decoration: InputDecoration(labelText: t.code),
                keyboardType: TextInputType.number,
                validator: (v) => (v==null || v.length<4) ? t.code : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: InputDecoration(labelText: t.new_password),
                validator: (v) => (v==null || v.length<6) ? t.new_password : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Text(t.change_password),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
