import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app_controller.dart';
import '../../core/api_client.dart';
import '../../shared/widgets.dart';
import 'attendance_status.dart';

final _dateFormat = DateFormat('yyyy-MM-dd');
final _monthFormat = DateFormat('yyyy-MM');
const _ink = Color(0xFF153C32);

class AttendanceDashboard extends StatefulWidget {
  final AppController controller;
  final bool team;
  final AttendanceDay? person;
  const AttendanceDashboard({
    super.key,
    required this.controller,
    this.team = false,
    this.person,
  });

  @override
  State<AttendanceDashboard> createState() => _AttendanceDashboardState();
}

class _AttendanceDashboardState extends State<AttendanceDashboard> {
  late Future<Map<String, dynamic>> _request;
  DateTime? _period, _selectedDay;
  String _search = '';
  AttendanceStatus? _filter;

  @override
  void initState() {
    super.initState();
    _period = widget.person?.date;
    _selectedDay = _period;
    _load();
  }

  void _load() {
    final period = _period;
    _request = widget.controller.call(
      widget.team ? '/attendance/team-day' : '/attendance/calendar',
      query: {
        if (widget.team && period != null) 'date': _dateFormat.format(period),
        if (!widget.team && period != null)
          'month': _monthFormat.format(period),
        if (widget.person != null) 'userId': widget.person!.userId,
      },
    );
  }

  void _changePeriod(DateTime? value) => setState(() {
        _period = value;
        _selectedDay = null;
        _load();
      });

  Future<void> _pickDay(DateTime day, DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      currentDate: today,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) _changePeriod(picked);
  }

  Future<void> _openPerson(AttendanceDay person) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Employee attendance')),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: AttendanceDashboard(
              controller: widget.controller, person: person),
        ))),
      ),
    ));
    if (mounted) setState(_load);
  }

  Future<void> _correct(AttendanceDay day) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _CorrectionDialog(controller: widget.controller, day: day),
    );
    if (changed == true && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _request,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorPanel(retry: () => setState(_load));
          }
          final response = snapshot.requireData;
          final today = DateTime.parse(response['today'] as String);
          final period = widget.team
              ? DateTime.parse(response['date'] as String)
              : DateTime.parse('${response['month']}-01');
          final days = (response['data'] as List)
              .map((item) => AttendanceDay.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList();
          final loading = snapshot.connectionState != ConnectionState.done;
          return RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              try {
                await _request;
              } catch (_) {/* FutureBuilder displays the error. */}
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverList(
                      delegate: SliverChildListDelegate([
                    _hero(period, today, loading),
                    if (loading) const LinearProgressIndicator(),
                    const SizedBox(height: 14),
                    _summary(days),
                    const SizedBox(height: 18),
                    if (widget.team)
                      ..._teamContent(days)
                    else
                      ..._calendar(period, today, days),
                  ])),
                ),
              ],
            ),
          );
        },
      );

  Widget _hero(DateTime period, DateTime today, bool loading) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_ink, Color(0xFF266957)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
              widget.team
                  ? Icons.groups_outlined
                  : Icons.calendar_month_outlined,
              color: const Color(0xFFBCE7D2),
              size: 29),
          const SizedBox(height: 12),
          Text(
              widget.team
                  ? 'Team attendance'
                  : widget.person?.name ?? 'My attendance',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              widget.team
                  ? DateFormat.yMMMMEEEEd().format(period)
                  : DateFormat.yMMMM().format(period),
              style: const TextStyle(color: Color(0xFFD5EDE3), fontSize: 15)),
          if (widget.team) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(
                onPressed: loading ? null : () => _pickDay(period, today),
                icon: const Icon(Icons.date_range_outlined),
                label: const Text('Choose date'),
              ),
              if (period != today)
                TextButton(
                  onPressed: loading ? null : () => _changePeriod(null),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Back to today'),
                ),
            ]),
          ],
        ]),
      );

  Widget _summary(List<AttendanceDay> days) {
    final counts = <AttendanceStatus, int>{};
    for (final day in days) {
      counts.update(day.status, (count) => count + 1, ifAbsent: () => 1);
    }
    final statuses = [
      AttendanceStatus.present,
      AttendanceStatus.halfDay,
      AttendanceStatus.absent,
      if (widget.team) AttendanceStatus.checkedIn,
      if (widget.team) AttendanceStatus.pending,
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 760 ? (widget.team ? 6 : 3) : 2;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        if (widget.team)
          _metric(width, 'All users', days.length, Icons.people_outline, _ink),
        for (final status in statuses)
          _metric(width, status.label, counts[status] ?? 0, status.icon,
              status.color),
      ]);
    });
  }

  Widget _metric(
          double width, String label, int count, IconData icon, Color color) =>
      SizedBox(
          width: width,
          child: _Panel(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 8),
              Text('$count',
                  style: TextStyle(
                      fontSize: 25, color: color, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          )));

  List<Widget> _teamContent(List<AttendanceDay> days) {
    final query = _search.trim().toLowerCase();
    final filtered = days
        .where((day) =>
            (_filter == null || day.status == _filter) &&
            (day.name.toLowerCase().contains(query) ||
                day.email.toLowerCase().contains(query)))
        .toList();
    return [
      Text('Daily roster', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      TextField(
        onChanged: (value) => setState(() => _search = value),
        decoration: const InputDecoration(
          labelText: 'Search name or email',
          prefixIcon: Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _filter?.code ?? '',
        isExpanded: true,
        decoration: const InputDecoration(
            labelText: 'Status', filled: true, fillColor: Colors.white),
        items: [
          const DropdownMenuItem(value: '', child: Text('All statuses')),
          for (final status in AttendanceStatus.values)
            DropdownMenuItem(value: status.code, child: Text(status.label)),
        ],
        onChanged: (value) => setState(() => _filter =
            value == null || value.isEmpty
                ? null
                : AttendanceStatus.parse(value)),
      ),
      const SizedBox(height: 12),
      Text('${filtered.length} of ${days.length} users'),
      const SizedBox(height: 8),
      if (filtered.isEmpty)
        const _Panel(child: Text('No users match this date and filter.')),
      for (final day in filtered)
        Padding(
            padding: const EdgeInsets.only(bottom: 8), child: _rosterRow(day)),
    ];
  }

  Widget _rosterRow(AttendanceDay day) => _Panel(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 680;
          final identity = Row(children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE4F0E9),
              foregroundColor: _ink,
              child: Text(day.name.characters.first.toUpperCase()),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: InkWell(
                    onTap: () => _openPerson(day),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(day.name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                          Text(day.email,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]))),
          ]);
          final actions = PopupMenuButton<String>(
            tooltip: 'Attendance actions for ${day.name}',
            onSelected: (action) =>
                action == 'calendar' ? _openPerson(day) : _correct(day),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'calendar', child: Text('View monthly calendar')),
              PopupMenuItem(value: 'correct', child: Text('Correct status')),
            ],
          );
          if (wide) {
            return Row(children: [
              Expanded(flex: 4, child: identity),
              const SizedBox(width: 12),
              Expanded(
                  flex: 3,
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(day.status))),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: _Times(day)),
              actions,
            ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: identity), actions]),
                const SizedBox(height: 8),
                StatusChip(day.status),
                const SizedBox(height: 12),
                _Times(day),
              ]);
        }),
      );

  List<Widget> _calendar(
      DateTime month, DateTime today, List<AttendanceDay> days) {
    final byDay = {for (final day in days) day.date.day: day};
    final selected = _selectedDay != null &&
            _selectedDay!.year == month.year &&
            _selectedDay!.month == month.month
        ? byDay[_selectedDay!.day]
        : month.year == today.year && month.month == today.month
            ? byDay[today.day]
            : null;
    final firstColumn = month.weekday - 1;
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final weeks = (firstColumn + lastDay + 6) ~/ 7;
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return [
      _Panel(
          child: Column(children: [
        Row(children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: month.year == 1 && month.month == 1
                ? null
                : () => _changePeriod(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
              child: Text(DateFormat.yMMMM().format(month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
            tooltip: 'Next month',
            onPressed: DateTime(month.year, month.month + 1).isAfter(today)
                ? null
                : () => _changePeriod(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (final weekday in weekdays)
            Expanded(
                child: Center(
                    child: Text(weekday,
                        style: const TextStyle(
                            color: Color(0xFF526075),
                            fontWeight: FontWeight.w700)))),
        ]),
        const SizedBox(height: 6),
        for (var week = 0; week < weeks; week++)
          Row(children: [
            for (var column = 0; column < 7; column++)
              Expanded(
                  child: _calendarCell(
                week * 7 + column - firstColumn + 1,
                lastDay,
                byDay,
                selected,
              )),
          ]),
      ])),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final status in AttendanceStatus.values)
          if (days.any((day) => day.status == status)) StatusChip(status),
      ]),
      const SizedBox(height: 12),
      if (selected == null)
        _Panel(
            child: Text(days.isEmpty
                ? 'No attendance days in this month.'
                : 'Select a date to see its attendance.'))
      else
        _Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat.yMMMMEEEEd().format(selected.date),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StatusChip(selected.status),
          const SizedBox(height: 12),
          _Times(selected),
          if (selected.correctionReason != null &&
              widget.controller.user?.isAdmin == true) ...[
            const SizedBox(height: 8),
            Text('Correction reason · ${selected.correctionReason}'),
          ],
          if (widget.person != null)
            TextButton.icon(
                onPressed: () => _correct(selected),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Correct status')),
        ])),
    ];
  }

  Widget _calendarCell(int number, int last, Map<int, AttendanceDay> byDay,
      AttendanceDay? selected) {
    if (number < 1 || number > last) return const SizedBox(height: 46);
    final day = byDay[number];
    final status = day?.status;
    final active = day != null && day == selected;
    final color = status?.color ?? const Color(0xFF59656A);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Tooltip(
        message: status == null
            ? '$number · No attendance'
            : '$number · ${status.label}',
        child: Material(
          color: active ? color : status?.background ?? const Color(0xFFF4F6F5),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: day == null
                ? null
                : () => setState(() => _selectedDay = day.date),
            child: SizedBox(
                height: 44,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$number',
                          style: TextStyle(
                            color: active ? Colors.white : color,
                            fontWeight: FontWeight.w800,
                          )),
                      if (status != null)
                        Icon(status.icon,
                            size: 12, color: active ? Colors.white : color),
                    ])),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDCE6E0)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
}

class _Times extends StatelessWidget {
  final AttendanceDay day;
  const _Times(this.day);

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 24, runSpacing: 8, children: [
        _item('Check-in', day.inTime),
        _item('Check-out', day.outTime),
        _item('Worked', day.duration),
      ]);

  Widget _item(String label, String time) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF526075), fontSize: 12)),
          Text(time, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}

class _CorrectionDialog extends StatefulWidget {
  final AppController controller;
  final AttendanceDay day;
  const _CorrectionDialog({required this.controller, required this.day});

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  static const _choices = [
    AttendanceStatus.present,
    AttendanceStatus.halfDay,
    AttendanceStatus.absent,
    AttendanceStatus.leave,
    AttendanceStatus.holiday,
    AttendanceStatus.dayOff,
  ];
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late String _status = widget.day.correctionReason != null &&
          _choices.contains(widget.day.status)
      ? widget.day.status.code
      : '';
  DateTime? _checkOut;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickCheckout() async {
    final start = widget.day.checkIn!;
    final now = DateTime.now();
    final initial = _checkOut ?? start;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start,
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    final checkout =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (checkout.isBefore(start) || checkout.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a time between check-in and now.');
      return;
    }
    setState(() {
      _checkOut = checkout;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final day = widget.day;
      await widget.controller.call(
          '/attendance/correction/${day.userId}/${_dateFormat.format(day.date)}',
          method: 'PUT',
          data: {
            'status': _status.isEmpty ? null : _status,
            'reason': _reason.text.trim(),
            if (_checkOut != null)
              'checkOut': _checkOut!.toUtc().toIso8601String(),
          });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is ApiException
              ? error.message
              : 'Unable to save the correction. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Correct attendance'),
        scrollable: true,
        content: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  '${widget.day.name} · ${DateFormat.yMMMd().format(widget.day.date)}'),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem(
                      value: '', child: Text('Use automatic status')),
                  for (final status in _choices)
                    DropdownMenuItem(
                        value: status.code, child: Text(status.label)),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _status = value ?? ''),
              ),
              if (widget.day.checkIn != null && widget.day.checkOut == null)
                TextButton.icon(
                  onPressed: _saving ? null : _pickCheckout,
                  icon: const Icon(Icons.schedule),
                  label: Text(_checkOut == null
                      ? 'Add missing checkout'
                      : DateFormat('MMM d, h:mm a').format(_checkOut!)),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                enabled: !_saving,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Reason'),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Enter a reason for this change.'
                    : null,
              ),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ])),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          BusyButton(busy: _saving, onPressed: _save, label: 'Save correction'),
        ],
      );
}
