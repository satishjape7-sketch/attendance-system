import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../shared/widgets.dart';
import '../auth/user.dart';

class UsersScreen extends StatefulWidget {
  final AppController controller;
  const UsersScreen({super.key, required this.controller});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}
class _UsersScreenState extends State<UsersScreen> {
  final List<AppUser> _users = [];
  int _page = 1;
  bool _busy = false, _hasMore = true;
  Object? _error;
  @override
  void initState() { super.initState(); _load(reset: true); }
  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final page = reset ? 1 : _page;
      final result = await widget.controller.call('/users', query: {'page': page});
      final users = (result['data'] as List).map((v) =>
        AppUser.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (!mounted) return;
      setState(() {
        if (reset) _users.clear();
        _users.addAll(users); _page = page + 1; _hasMore = result['hasMore'] as bool;
      });
    } catch (error) { if (mounted) setState(() => _error = error); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _toggle(AppUser user) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) =>
      AlertDialog(title: Text('${user.active ? 'Deactivate' : 'Activate'} ${user.name}?'),
        content: Text(user.active ? 'This employee will lose access immediately. Attendance records are retained.' : 'This employee will be able to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ]));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.controller.call('/users/${user.id}/status', method: 'PATCH',
        data: {'active': !user.active});
      if (mounted) { setState(() => _busy = false); await _load(reset: true); }
    } catch (error) { if (mounted) showFailure(context, error); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _create() async {
    final created = await showDialog<bool>(context: context,
      barrierDismissible: false,
      builder: (_) => CreateUserDialog(controller: widget.controller));
    if (created == true && mounted) await _load(reset: true);
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Expanded(child: Text('Team members', style: Theme.of(context).textTheme.titleLarge)),
      FilledButton.icon(onPressed: _busy ? null : _create,
        icon: const Icon(Icons.person_add_alt), label: const Text('Add')),
    ])),
    Expanded(child: RefreshIndicator(onRefresh: () => _load(reset: true),
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
        for (final user in _users) Card(child: ListTile(
          leading: CircleAvatar(child: Text(user.name.substring(0, 1).toUpperCase())),
          title: Text(user.name), subtitle: Text('${user.email}\n${user.role} · ${user.active ? 'Active' : 'Inactive'}'),
          isThreeLine: true,
          trailing: user.isAdmin ? const Icon(Icons.admin_panel_settings_outlined) :
            Switch(value: user.active, onChanged: _busy ? null : (_) => _toggle(user)))),
        if (_error != null) ErrorPanel(retry: () => _load(reset: _users.isEmpty)),
        if (_busy) const Center(child: CircularProgressIndicator()),
        if (!_busy && _users.isEmpty && _error == null) const Center(child: Text('No team members yet.')),
        if (!_busy && _hasMore && _error == null)
          TextButton(onPressed: () => _load(), child: const Text('Load more')),
      ]))),
  ]);
}

class CreateUserDialog extends StatefulWidget {
  final AppController controller;
  const CreateUserDialog({super.key, required this.controller});
  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}
class _CreateUserDialogState extends State<CreateUserDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController(), _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() { _name.dispose(); _email.dispose(); _password.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.controller.call('/users', method: 'POST', data: {
        'name': _name.text.trim(), 'email': _email.text.trim(),
        'password': _password.text, 'role': 'employee',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: AlertDialog(
    title: const Text('Add employee'),
    content: SizedBox(width: 400, child: SingleChildScrollView(child: Form(key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _name, maxLength: 100, decoration: const InputDecoration(labelText: 'Full name'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null),
        TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Work email'),
          validator: (v) => v != null && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()) ? null : 'Enter a valid email'),
        const SizedBox(height: 16),
        TextFormField(controller: _password, obscureText: true,
          decoration: const InputDecoration(labelText: 'Initial password', helperText: '12–72 characters; share securely'),
          validator: (v) => v == null || v.length < 12 || utf8.encode(v).length > 72 ? 'Use 12–72 bytes' : null),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!)),
      ])))),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      BusyButton(busy: _busy, onPressed: _save, label: 'Create'),
    ],
  ));
}
