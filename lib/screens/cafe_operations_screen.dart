import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/cafe_operations_service.dart';
import '../widgets/theme_mode_button.dart';

class CafeOperationsScreen extends StatefulWidget {
  const CafeOperationsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<CafeOperationsScreen> createState() => _CafeOperationsScreenState();
}

class _CafeOperationsScreenState extends State<CafeOperationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _profiles;
  late Future<List<Map<String, dynamic>>> _shifts;
  late Future<List<Map<String, dynamic>>> _attendance;
  late Future<List<Map<String, dynamic>>> _feedback;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    _profiles = CafeOperationsService.getProfiles();
    _shifts = CafeOperationsService.getShifts();
    _attendance = CafeOperationsService.getAttendance();
    _feedback = CafeOperationsService.getFeedback();
  }

  Future<void> _perform(Future<void> Function() action, String success) async {
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: Colors.green),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save changes: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = TabBar(
      controller: _tabs,
      isScrollable: true,
      tabs: const [
        Tab(icon: Icon(Icons.badge_outlined), text: 'Staff'),
        Tab(icon: Icon(Icons.event_note), text: 'Shifts'),
        Tab(icon: Icon(Icons.fact_check_outlined), text: 'Attendance'),
        Tab(icon: Icon(Icons.feedback_outlined), text: 'Feedback'),
      ],
    );
    final tabView = TabBarView(
      controller: _tabs,
      children: [
        _buildStaff(),
        _buildShifts(),
        _buildAttendance(),
        _buildFeedback(),
      ],
    );
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Staff & Cafe Operations'),
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              bottom: tabs,
              actions: [
                const ThemeModeButton(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      body: widget.embedded
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(child: tabs),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () => setState(_reload),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_saving) const LinearProgressIndicator(),
                Expanded(child: tabView),
              ],
            )
          : _saving
              ? const LinearProgressIndicator()
              : tabView,
    );
  }

  Widget _buildStaff() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _profiles,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error);
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final profiles = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Assign cafe roles to registered customers. Role access is controlled by the cafe database.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              ...profiles.map((profile) {
                final role = profile['role'] as String? ?? 'customer';
                final isAdmin = role == 'cafe_admin';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                          isAdmin ? Icons.admin_panel_settings : Icons.person),
                    ),
                    title: Text(profile['full_name'] as String? ?? 'Cafe user'),
                    subtitle: Text(
                      '${profile['email'] ?? ''}\n${profile['department'] ?? 'Customer'}',
                    ),
                    isThreeLine: true,
                    trailing: isAdmin
                        ? const Chip(label: Text('Cafe Admin'))
                        : DropdownButton<String>(
                            value: CafeOperationsService.staffRoles
                                    .containsKey(role)
                                ? role
                                : 'customer',
                            items: [
                              const DropdownMenuItem(
                                value: 'customer',
                                child: Text('Customer'),
                              ),
                              ...CafeOperationsService.staffRoles.entries.map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              ),
                            ],
                            onChanged: (nextRole) {
                              if (nextRole == null || nextRole == role) return;
                              _perform(
                                () => CafeOperationsService.updateStaffRole(
                                  userId: profile['id'] as String,
                                  role: nextRole,
                                ),
                                'Staff role updated.',
                              );
                            },
                          ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShifts() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait([_profiles, _shifts]).then((values) => values[1]),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error);
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final shifts = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _createShift,
                  icon: const Icon(Icons.add),
                  label: const Text('Schedule staff shift'),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(_reload),
                child: shifts.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('No shifts scheduled yet.')),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: shifts.length,
                        itemBuilder: (context, index) {
                          final shift = shifts[index];
                          final employee =
                              shift['user_profiles'] as Map<String, dynamic>?;
                          final starts =
                              DateTime.parse(shift['starts_at'] as String)
                                  .toLocal();
                          final ends =
                              DateTime.parse(shift['ends_at'] as String)
                                  .toLocal();
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.schedule),
                              title: Text(
                                  '${shift['title']} • ${employee?['full_name'] ?? 'Staff'}'),
                              subtitle: Text(
                                '${DateFormat('EEE, d MMM • h:mm a').format(starts)} - ${DateFormat('h:mm a').format(ends)}'
                                '${shift['notes'] == null ? '' : '\n${shift['notes']}'}',
                              ),
                              isThreeLine: shift['notes'] != null,
                              trailing: IconButton(
                                tooltip: 'Delete shift',
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => _perform(
                                  () => CafeOperationsService.deleteShift(
                                      shift['id'] as String),
                                  'Shift removed.',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAttendance() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait([_profiles, _attendance]).then((values) => values[1]),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error);
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _recordCheckIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Record staff check-in'),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(_reload),
                child: rows.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('No attendance recorded today.')),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: rows.map((row) {
                          final employee =
                              row['user_profiles'] as Map<String, dynamic>?;
                          final checkIn =
                              DateTime.parse(row['check_in'] as String)
                                  .toLocal();
                          final checkOut = row['check_out'] as String?;
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.person_pin_circle),
                              title: Text(
                                  employee?['full_name'] as String? ?? 'Staff'),
                              subtitle: Text(
                                'In: ${DateFormat('h:mm a').format(checkIn)}'
                                '${checkOut == null ? '' : ' • Out: ${DateFormat('h:mm a').format(DateTime.parse(checkOut).toLocal())}'}',
                              ),
                              trailing: checkOut == null
                                  ? TextButton(
                                      onPressed: () => _perform(
                                        () => CafeOperationsService
                                            .recordCheckOut(
                                                row['id'] as String),
                                        'Check-out recorded.',
                                      ),
                                      child: const Text('Check out'),
                                    )
                                  : const Chip(label: Text('Complete')),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeedback() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _feedback,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error);
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
              child: Text('No customer feedback received yet.'));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final customer = item['user_profiles'] as Map<String, dynamic>?;
              final status = item['status'] as String? ?? 'new';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['subject'] as String? ?? 'Customer feedback',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text('${item['rating']} ★'),
                        ],
                      ),
                      Text(
                          'From ${customer?['full_name'] ?? 'Customer'} • $status'),
                      const SizedBox(height: 8),
                      Text(item['message'] as String? ?? ''),
                      if (item['admin_note'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Admin note: ${item['admin_note']}'),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: DropdownButton<String>(
                          value: status,
                          items: const [
                            DropdownMenuItem(value: 'new', child: Text('New')),
                            DropdownMenuItem(
                                value: 'in_review', child: Text('In review')),
                            DropdownMenuItem(
                                value: 'resolved', child: Text('Resolved')),
                          ],
                          onChanged: (next) {
                            if (next == null || next == status) return;
                            _perform(
                              () => CafeOperationsService.updateFeedback(
                                feedbackId: item['id'] as String,
                                status: next,
                              ),
                              'Feedback status updated.',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _createShift() async {
    final profiles = await _profiles;
    if (!mounted) return;
    final staff = profiles
        .where((profile) =>
            CafeOperationsService.staffRoles.containsKey(profile['role']))
        .toList();
    if (staff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Assign a staff role before scheduling a shift.')),
      );
      _tabs.animateTo(0);
      return;
    }
    final title = TextEditingController(text: 'Regular shift');
    final notes = TextEditingController();
    String employeeId = staff.first['id'] as String;
    DateTime starts = DateTime.now();
    DateTime ends = starts.add(const Duration(hours: 8));
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule a shift'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: employeeId,
                  decoration: const InputDecoration(labelText: 'Employee'),
                  items: staff
                      .map((profile) => DropdownMenuItem(
                            value: profile['id'] as String,
                            child: Text(
                                '${profile['full_name']} (${profile['role']})'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => employeeId = value);
                  },
                ),
                TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Shift name')),
                TextField(
                    controller: notes,
                    decoration:
                        const InputDecoration(labelText: 'Notes (optional)')),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starts'),
                  subtitle:
                      Text(DateFormat('EEE, d MMM • h:mm a').format(starts)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final value = await _pickDateTime(starts);
                    if (value != null) setDialogState(() => starts = value);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ends'),
                  subtitle:
                      Text(DateFormat('EEE, d MMM • h:mm a').format(ends)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final value = await _pickDateTime(ends);
                    if (value != null) setDialogState(() => ends = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty || !ends.isAfter(starts)) return;
                Navigator.pop(context, {
                  'employeeId': employeeId,
                  'title': title.text.trim(),
                  'notes': notes.text.trim(),
                  'starts': starts,
                  'ends': ends,
                });
              },
              child: const Text('Save shift'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    notes.dispose();
    if (result == null) return;
    await _perform(
      () => CafeOperationsService.createShift(
        employeeId: result['employeeId'] as String,
        title: result['title'] as String,
        notes: (result['notes'] as String).isEmpty
            ? null
            : result['notes'] as String,
        startsAt: result['starts'] as DateTime,
        endsAt: result['ends'] as DateTime,
      ),
      'Shift scheduled.',
    );
  }

  Future<void> _recordCheckIn() async {
    final profiles = await _profiles;
    if (!mounted) return;
    final staff = profiles
        .where((profile) =>
            CafeOperationsService.staffRoles.containsKey(profile['role']))
        .toList();
    if (staff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Assign a staff role before recording attendance.')),
      );
      _tabs.animateTo(0);
      return;
    }
    String employeeId = staff.first['id'] as String;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record check-in'),
          content: DropdownButtonFormField<String>(
            value: employeeId,
            items: staff
                .map((profile) => DropdownMenuItem(
                      value: profile['id'] as String,
                      child:
                          Text('${profile['full_name']} (${profile['role']})'),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) setDialogState(() => employeeId = value);
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, employeeId),
                child: const Text('Check in')),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _perform(
      () => CafeOperationsService.recordCheckIn(selected),
      'Staff check-in recorded.',
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _error(Object? error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Unable to load cafe operations: $error'),
        ),
      );
}
