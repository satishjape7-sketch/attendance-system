import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/app/app_controller.dart';
import 'package:attendance_app/app/attendance_app.dart';
import 'package:attendance_app/core/api_client.dart';
import 'package:attendance_app/features/attendance/attendance_record.dart';
import 'package:attendance_app/features/attendance/attendance_dashboard.dart';

void main() {
  testWidgets('login validates empty form without sending a request',
      (tester) async {
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
      'id': 'shift',
      'work_date': '2026-11-11',
      'check_in': '2026-11-11T22:00:00Z',
      'check_out': '2026-11-12T06:30:00Z',
    });
    expect(record.duration, '8h 30m');
    expect(record.workDate, '2026-11-11');
  });

  testWidgets('monthly calendar shows the selected day status', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: AttendanceDashboard(controller: _AttendanceFixture()),
    )));
    await tester.pumpAndSettle();
    expect(find.text('My attendance'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('16 · Half Day'));
    await tester.tap(find.byTooltip('16 · Half Day'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('4h 0m'), 180);
    expect(find.text('4h 0m'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('team roster shows a user without a check-in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AttendanceDashboard(controller: _AttendanceFixture(), team: true),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Team attendance'), findsOneWidget);
    expect(find.text('1 of 1 users'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Attendance actions for Asha'));
    await tester.tap(find.byTooltip('Attendance actions for Asha'));
    await tester.pumpAndSettle();
    expect(find.text('View monthly calendar'), findsOneWidget);
    expect(find.text('Correct status'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _AttendanceFixture extends AppController {
  _AttendanceFixture() : super(ApiClient());

  @override
  Future<Map<String, dynamic>> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async =>
      {
        'month': '2026-11',
        'today': '2026-11-18',
        'date': '2026-11-18',
        'data': [
          {
            'user_id': 'employee',
            'name': 'Asha',
            'email': 'asha@example.com',
            'role': 'employee',
            'work_date':
                path.endsWith('team-day') ? '2026-11-18' : '2026-11-16',
            'status': path.endsWith('team-day') ? 'pending' : 'half_day',
            if (path.endsWith('calendar')) 'check_in': '2026-11-16T09:00:00Z',
            if (path.endsWith('calendar')) 'check_out': '2026-11-16T13:00:00Z',
          },
        ],
      };
}
