import 'package:flutter/material.dart';
import '../core/api_client.dart';
void showFailure(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(error is ApiException ? error.message : 'Something went wrong. Please try again.')));
}
class ErrorPanel extends StatelessWidget {
  final VoidCallback retry;
  final String message;
  const ErrorPanel({super.key, required this.retry,
    this.message = 'Unable to load data. Check your connection.'});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_outlined, size: 40),
      const SizedBox(height: 16), Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton(onPressed: retry, child: const Text('Try again')),
    ])));
}
class BusyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  final String label;
  const BusyButton({super.key, required this.busy, required this.onPressed, required this.label});
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy ? const SizedBox(width: 20, height: 20,
      child: CircularProgressIndicator(strokeWidth: 2)) : Text(label));
}
