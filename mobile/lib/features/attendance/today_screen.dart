import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app_controller.dart';
import '../../shared/widgets.dart';
import 'attendance_record.dart';
import 'attendance_status.dart';

typedef _TodayData = ({
  AttendanceRecord? record,
  DateTime date,
  AttendanceStatus? status
});

class TodayScreen extends StatefulWidget {
  final AppController controller;
  const TodayScreen({super.key, required this.controller});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Future<_TodayData> _future;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.controller.today();
  }

  Future<void> _mark(bool checkout) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.markAttendance(checkout);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        showFailure(context, error);
        setState(_reload);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_TodayData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorPanel(retry: () => setState(_reload));
        }
        final today = snapshot.requireData;
        final record = today.record;
        final open = record != null && record.checkOut == null;
        return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              try {
                await _future;
              } catch (_) {/* FutureBuilder displays the error. */}
            },
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF153C32), Color(0xFF266957)]),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hello, ${widget.controller.user!.name}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(
                              DateFormat('EEEE, d MMMM yyyy')
                                  .format(today.date),
                              style: const TextStyle(color: Color(0xFFD5EDE3))),
                          if (today.status != null) ...[
                            const SizedBox(height: 12),
                            StatusChip(today.status!),
                          ],
                        ]),
                  ),
                  const SizedBox(height: 16),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(children: [
                            Icon(
                                open
                                    ? Icons.work_history_outlined
                                    : Icons.schedule,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 16),
                            Text(
                                record == null
                                    ? 'Ready for your day?'
                                    : open
                                        ? 'You are checked in'
                                        : 'Your shift is complete',
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            Text(record == null
                                ? 'Check in when you start work.'
                                : 'Attendance date: ${record.workDate}'),
                            if (record != null) ...[
                              const SizedBox(height: 20),
                              ListTile(
                                  title: const Text('Check in'),
                                  trailing: Text(record.inTime)),
                              ListTile(
                                  title: const Text('Check out'),
                                  trailing: Text(record.outTime)),
                              ListTile(
                                  title: const Text('Total time'),
                                  trailing: Text(record.duration)),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                                width: double.infinity,
                                child: BusyButton(
                                    busy: _busy,
                                    onPressed: record == null || open
                                        ? () => _mark(open)
                                        : null,
                                    label: open
                                        ? 'Check out'
                                        : record == null
                                            ? 'Check in'
                                            : 'Completed')),
                          ]))),
                  const SizedBox(height: 16),
                  const Text(
                      'Times use your device timezone. Attendance dates use your organization’s timezone.'),
                ]));
      });
}
