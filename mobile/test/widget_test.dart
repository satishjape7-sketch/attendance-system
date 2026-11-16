import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/app/app_controller.dart';
import 'package:attendance_app/app/attendance_app.dart';
import 'package:attendance_app/core/api_client.dart';
import 'package:attendance_app/features/attendance/attendance_record.dart';

void main() {
  testWidgets('login validates empty form without sending a request', (tester) async {
    final controller = AppController(ApiClient())..initializing = false;
    await tester.pumpWidget(AttendanceApp(controller: controller));
    expect(find.text('Welcome to Attend'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
  test('attendance duration uses elapsed instants across midnight', () {
    final record = AttendanceRecord.fromJson({
      'id': 'shift', 'work_date': '2026-11-11',
      'check_in': '2026-11-11T22:00:00Z',
      'check_out': '2026-11-12T06:30:00Z',
    });
    expect(record.duration, '8h 30m');
    expect(record.workDate, '2026-11-11');
  });
}
