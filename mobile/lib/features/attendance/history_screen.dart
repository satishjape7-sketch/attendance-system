import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app_controller.dart';
import '../../shared/widgets.dart';
import 'attendance_record.dart';

class HistoryScreen extends StatefulWidget {
  final AppController controller;
  final bool report;
  const HistoryScreen({super.key, required this.controller, this.report = false});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}
class _HistoryScreenState extends State<HistoryScreen> {
  final List<AttendanceRecord> _items = [];
  bool _busy = false, _hasMore = true;
  Object? _error;
  int _page = 1;
  DateTimeRange? _range;
  @override
  void initState() { super.initState(); _load(reset: true); }
  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final page = reset ? 1 : _page;
      final result = await widget.controller.call(
        widget.report ? '/attendance/report' : '/attendance/history', query: {
          'page': page, 'limit': 30,
          if (_range != null) 'from': DateFormat('yyyy-MM-dd').format(_range!.start),
          if (_range != null) 'to': DateFormat('yyyy-MM-dd').format(_range!.end),
        });
      final records = (result['data'] as List).map((v) =>
        AttendanceRecord.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(records); _page = page + 1; _hasMore = result['hasMore'] as bool;
      });
    } catch (error) { if (mounted) setState(() => _error = error); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _filter() async {
    final range = await showDateRangePicker(context: context,
      firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range);
    if (range == null || !mounted) return;
    setState(() => _range = range);
    await _load(reset: true);
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Row(children: [
      Expanded(child: Text(widget.report ? 'Team attendance' : 'Your attendance',
        style: Theme.of(context).textTheme.titleLarge)),
      IconButton(tooltip: 'Filter dates', onPressed: _busy ? null : _filter, icon: const Icon(Icons.date_range)),
      if (_range != null) IconButton(tooltip: 'Clear filter',
        onPressed: _busy ? null : () { setState(() => _range = null); _load(reset: true); },
        icon: const Icon(Icons.filter_alt_off_outlined)),
    ])),
    if (_range != null) Text('${DateFormat.yMMMd().format(_range!.start)} – ${DateFormat.yMMMd().format(_range!.end)}'),
    Expanded(child: RefreshIndicator(onRefresh: () => _load(reset: true),
      child: ListView(physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16), children: [
        if (_items.isEmpty && !_busy && _error == null)
          const Padding(padding: EdgeInsets.all(40), child: Text('No attendance records found.', textAlign: TextAlign.center)),
        for (final record in _items)
          Card(child: ListTile(leading: const Icon(Icons.event_available_outlined),
            title: Text(record.name == null ? record.workDate : '${record.name} · ${record.workDate}'),
            subtitle: Text('${record.inTime} → ${record.outTime}'),
            trailing: Text(record.duration))),
        if (_error != null) ErrorPanel(retry: () => _load(reset: _items.isEmpty)),
        if (_busy) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
        if (!_busy && _hasMore && _error == null)
          TextButton(onPressed: () => _load(), child: const Text('Load more')),
      ]))),
  ]);
}
