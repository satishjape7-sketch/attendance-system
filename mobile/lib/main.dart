import 'package:flutter/material.dart';
import 'app/app_controller.dart';
import 'app/attendance_app.dart';
import 'core/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(ApiClient());
  runApp(AttendanceApp(controller: controller));
  controller.initialize();
}
