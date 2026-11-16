import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../shared/widgets.dart';

class AccountScreen extends StatefulWidget {
  final AppController controller;
  const AccountScreen({super.key, required this.controller});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}
class _AccountScreenState extends State<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(), _next = TextEditingController(), _confirm = TextEditingController();
  bool _busy = false;
  @override
  void dispose() { _current.dispose(); _next.dispose(); _confirm.dispose(); super.dispose(); }
  Future<void> _change() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try { await widget.controller.changePassword(_current.text, _next.text); }
    catch (error) { if (mounted) showFailure(context, error); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await widget.controller.logout(); }
    catch (error) { if (mounted) showFailure(context, error); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
    Text(widget.controller.user!.name, style: Theme.of(context).textTheme.headlineSmall),
    Text(widget.controller.user!.email),
    const SizedBox(height: 32),
    Text('Change password', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    const Text('Changing your password signs out all sessions.'),
    const SizedBox(height: 20),
    Form(key: _form, child: Column(children: [
      TextFormField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password'),
        validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null),
      const SizedBox(height: 16),
      TextFormField(controller: _next, obscureText: true, decoration: const InputDecoration(labelText: 'New password'),
        validator: (v) => v == null || v.length < 12 || utf8.encode(v).length > 72 ? 'Use 12–72 bytes' : null),
      const SizedBox(height: 16),
      TextFormField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password'),
        validator: (v) => v != _next.text ? 'Passwords do not match' : null),
      const SizedBox(height: 20),
      BusyButton(busy: _busy, onPressed: _change, label: 'Update password'),
    ])),
    const SizedBox(height: 32),
    OutlinedButton.icon(onPressed: _busy ? null : _logout,
      icon: const Icon(Icons.logout), label: const Text('Sign out of all sessions')),
  ]);
}
