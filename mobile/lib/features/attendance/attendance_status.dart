import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum AttendanceStatus {
  present('present', 'Present', Icons.check_circle_outline, Color(0xFF176747)),
  halfDay('half_day', 'Half Day', Icons.timelapse, Color(0xFF855000)),
  absent('absent', 'Absent', Icons.cancel_outlined, Color(0xFFAB3346)),
  checkedIn('checked_in', 'Checked In', Icons.login, Color(0xFF245CB4)),
  pending('pending', 'Pending', Icons.schedule, Color(0xFF526075)),
  missingCheckout('missing_checkout', 'Missing Checkout', Icons.warning_amber,
      Color(0xFF9C4520)),
  leave('leave', 'Leave', Icons.event_busy, Color(0xFF7543A0)),
  holiday('holiday', 'Holiday', Icons.celebration_outlined, Color(0xFF7543A0)),
  dayOff('day_off', 'Day Off', Icons.weekend_outlined, Color(0xFF526075)),
  inactive(
      'inactive', 'Inactive', Icons.person_off_outlined, Color(0xFF526075));

  final String code, label;
  final IconData icon;
  final Color color;
  const AttendanceStatus(this.code, this.label, this.icon, this.color);

  static AttendanceStatus parse(String code) =>
      values.firstWhere((status) => status.code == code);

  Color get background => Color.alphaBlend(color.withAlpha(22), Colors.white);
}

class AttendanceDay {
  final String userId, name, email, role;
  final DateTime date;
  final DateTime? checkIn, checkOut;
  final AttendanceStatus status;
  final String? correctionReason;

  AttendanceDay.fromJson(Map<String, dynamic> json)
      : userId = json['user_id'] as String,
        name = json['name'] as String,
        email = json['email'] as String,
        role = json['role'] as String,
        date = DateTime.parse(json['work_date'] as String),
        checkIn = _instant(json['check_in'] as String?),
        checkOut = _instant(json['check_out'] as String?),
        status = AttendanceStatus.parse(json['status'] as String),
        correctionReason = json['correction_reason'] as String?;

  static DateTime? _instant(String? value) =>
      value == null ? null : DateTime.parse(value).toLocal();

  String get inTime => _time(checkIn);
  String get outTime => _time(checkOut);
  static String _time(DateTime? value) =>
      value == null ? '—' : DateFormat.jm().format(value);

  String get duration {
    if (checkIn == null || checkOut == null) return '—';
    final minutes = checkOut!.difference(checkIn!).inMinutes;
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}

class StatusChip extends StatelessWidget {
  final AttendanceStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: status.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(status.icon, size: 15, color: status.color),
          const SizedBox(width: 5),
          Flexible(
              child: Text(status.label,
                  style: TextStyle(
                      color: status.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12))),
        ]),
      );
}
