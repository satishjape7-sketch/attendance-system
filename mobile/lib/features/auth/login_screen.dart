import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../shared/widgets.dart';

class LoginScreen extends StatefulWidget {
  final AppController controller;
  const LoginScreen({super.key, required this.controller});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _busy = false, _hidden = true;
  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }
  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try { await widget.controller.login(_email.text, _password.text); }
    catch (error) { if (mounted) showFailure(context, error); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child:
    SingleChildScrollView(padding: const EdgeInsets.all(28), child:
      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child:
        AutofillGroup(child: Form(key: _form, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(Icons.fingerprint, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text('Welcome to Attend', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Your workday, accounted for. Sign in with your team account.'),
          const SizedBox(height: 32),
          TextFormField(controller: _email, autofillHints: const [AutofillHints.username],
            keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Work email', prefixIcon: Icon(Icons.alternate_email)),
            validator: (v) => v != null && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()) ? null : 'Enter a valid email'),
          const SizedBox(height: 16),
          TextFormField(controller: _password, obscureText: _hidden,
            autofillHints: const [AutofillHints.password], onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(tooltip: _hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
            validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null),
          const SizedBox(height: 24),
          BusyButton(busy: _busy, onPressed: _submit, label: 'Sign in'),
          const SizedBox(height: 20),
          const Text('Need an account or password reset? Contact your administrator.',
            textAlign: TextAlign.center),
        ])))))));
}
