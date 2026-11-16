import 'package:intl/intl.dart';
class AttendanceRecord {
  final String id, workDate;
  final String? name;
  final DateTime checkIn;
  final DateTime? checkOut;
  const AttendanceRecord({required this.id, required this.workDate,
    required this.checkIn, this.checkOut, this.name});
  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
    id: json['id'] as String,
    workDate: (json['work_date'] as String).substring(0, 10),
    name: json['name'] as String?,
    checkIn: DateTime.parse(json['check_in'] as String),
    checkOut: json['check_out'] == null ? null : DateTime.parse(json['check_out'] as String));
  String get inTime => DateFormat('h:mm a').format(checkIn.toLocal());
  String get outTime => checkOut == null ? 'In progress' : DateFormat('h:mm a').format(checkOut!.toLocal());
  String get duration {
    if (checkOut == null) return 'Open shift';
    final minutes = checkOut!.difference(checkIn).inMinutes;
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}
