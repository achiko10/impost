import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'task_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  final bool embedded;

  const CalendarScreen({super.key, this.embedded = false});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _loading = true;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  List<TaskModel> _allTasks = [];
  List<AppUser> _inspectors = [];
  List<ScheduleModel> _schedules = [];

  int? _filterInspectorId;
  String _filterStatus = '';

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final role = context.read<AppState>().currentUser?.role;
    try {
      final tasks = await ApiService.getTasks();
      List<AppUser> inspectors = [];
      List<ScheduleModel> schedules = [];
      if (role == 'manager') {
        inspectors = await ApiService.getUsers(role: 'inspector');
        schedules = await ApiService.getSchedules();
      }
      setState(() {
        _allTasks = tasks;
        _inspectors = inspectors;
        _schedules = schedules;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TaskModel> get _filteredTasks {
    return _allTasks.where((t) {
      if (_filterInspectorId != null && t.assignedToId != _filterInspectorId) {
        return false;
      }
      if (_filterStatus.isNotEmpty && t.status != _filterStatus) {
        return false;
      }
      return true;
    }).toList();
  }

  List<TaskModel> _tasksForDay(DateTime day) {
    return _filteredTasks.where((t) {
      try {
        final dt = DateTime.parse(t.scheduledDate).toLocal();
        return dt.year == day.year &&
            dt.month == day.month &&
            dt.day == day.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  int _countByStatus(String st) =>
      _allTasks.where((t) => t.status == st).length;

  void _openAddTaskModal({DateTime? initialDate}) {
    if (_schedules.isEmpty || _inspectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'დავალების შესაქმნელად საჭიროა მინიმუმ 1 გრაფიკი და 1 ინსპექტორი',
          ),
        ),
      );
      return;
    }
    int selectedScheduleId = _schedules.first.id;
    int selectedInspectorId = _inspectors.first.id;
    DateTime chosenDate = initialDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('ახალი დავალება'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedScheduleId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'დანადგარი და შემოწმება *',
                    ),
                    items: _schedules
                        .map(
                          (s) => DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(
                              '${s.siteName} → ${s.equipmentName} → ${s.taskName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setModalState(() => selectedScheduleId = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedInspectorId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'ინსპექტორი *'),
                    items: _inspectors
                        .map(
                          (i) => DropdownMenuItem<int>(
                            value: i.id,
                            child: Text(
                              i.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setModalState(() => selectedInspectorId = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: chosenDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setModalState(() {
                          chosenDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            9,
                            0,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      'თარიღი: ${DateFormat('dd.MM.yyyy 09:00').format(chosenDate)}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('გაუქმება'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ImpostiColors.success,
              ),
              onPressed: () async {
                try {
                  await ApiService.createTask(
                    scheduleId: selectedScheduleId,
                    inspectorId: selectedInspectorId,
                    scheduledDate: chosenDate.toIso8601String(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('დავალება შეიქმნა!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('შეცდომა: $e')),
                    );
                  }
                }
              },
              child: const Text('შექმნა'),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditTaskModal(TaskModel task) {
    final isManager = context.read<AppState>().currentUser?.role == 'manager';
    String selectedStatus = task.status;
    int? selectedInspector = task.assignedToId;
    DateTime scheduledDt =
        DateTime.tryParse(task.scheduledDate)?.toLocal() ?? DateTime.now();

    final allowedStatuses = isManager
        ? ['pending', 'in_progress', 'completed', 'approved', 'rejected']
        : ['pending', 'in_progress', 'completed'];
    if (!allowedStatuses.contains(selectedStatus)) {
      allowedStatuses.add(selectedStatus);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          actionsOverflowButtonSpacing: 8,
          title: const Text('დავალების რედაქტირება'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ობიექტი: ${task.siteName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text('დანადგარი: ${task.equipmentName}'),
                  const SizedBox(height: 4),
                  Text('შემოწმება: ${task.scheduleName}'),
                  const Divider(height: 24),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: scheduledDt,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setModalState(() {
                          scheduledDt = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            scheduledDt.hour,
                            scheduledDt.minute,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      'თარიღი: ${DateFormat('dd.MM.yyyy HH:mm').format(scheduledDt)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isManager && _inspectors.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      initialValue:
                          _inspectors.any((i) => i.id == selectedInspector)
                              ? selectedInspector
                              : _inspectors.first.id,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'ინსპექტორი'),
                      items: _inspectors
                          .map(
                            (i) => DropdownMenuItem<int>(
                              value: i.id,
                              child: Text(
                                i.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => selectedInspector = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'სტატუსი'),
                    items: allowedStatuses
                        .map(
                          (st) => DropdownMenuItem<String>(
                            value: st,
                            child: Text(ImpostiColors.statusLabel(st)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedStatus = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TaskDetailScreen(taskId: task.id),
                  ),
                );
                _loadData();
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('დეტალურად'),
            ),
            if (isManager)
              TextButton(
                onPressed: () async {
                  await ApiService.deleteTask(task.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadData();
                },
                child: const Text(
                  'წაშლა',
                  style: TextStyle(color: ImpostiColors.danger),
                ),
              ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.updateTask(task.id, {
                    'scheduled_date': scheduledDt.toIso8601String(),
                    'status': selectedStatus,
                    if (isManager && selectedInspector != null)
                      'assigned_to': selectedInspector,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('შეცდომა: $e')),
                    );
                  }
                }
              },
              child: const Text('შენახვა'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isManager = context.watch<AppState>().currentUser?.role == 'manager';
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final leadingEmptyDays = firstDayOfMonth.weekday - 1; // Mon=1..Sun=7
    final selectedDayTasks =
        _selectedDay != null ? _tasksForDay(_selectedDay!) : <TaskModel>[];

    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ინტერაქტიული კალენდარი',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'აირჩიეთ დღე დავალებების სანახავად ან შესაქმნელად',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    if (isManager)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ImpostiColors.success,
                        ),
                        onPressed: () =>
                            _openAddTaskModal(initialDate: _selectedDay),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('ახალი დავალება'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats Bar (Responsive 2 or 3 cols on mobile)
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final maxW = constraints.maxWidth;
                    final cols = maxW < 450 ? 2 : (maxW < 750 ? 3 : 5);
                    final pillW = (maxW - (cols - 1) * 10) / cols;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _statPill(
                          'მოლოდინში',
                          _countByStatus('pending'),
                          ImpostiColors.secondary,
                          pillW,
                        ),
                        _statPill(
                          'მიმდინარე',
                          _countByStatus('in_progress'),
                          ImpostiColors.warning,
                          pillW,
                          darkText: true,
                        ),
                        _statPill(
                          'დასრულებული',
                          _countByStatus('completed'),
                          ImpostiColors.success,
                          pillW,
                        ),
                        _statPill(
                          'დამტკიცებული',
                          _countByStatus('approved'),
                          const Color(0xFF17A2B8),
                          pillW,
                        ),
                        _statPill(
                          'უარყოფილი',
                          _countByStatus('rejected'),
                          ImpostiColors.danger,
                          pillW,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Filters
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isMobile = constraints.maxWidth < 500;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (isManager)
                              SizedBox(
                                width: isMobile ? constraints.maxWidth : 200,
                                child: DropdownButtonFormField<int?>(
                                  initialValue: _filterInspectorId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'ინსპექტორი',
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('ყველა ინსპექტორი'),
                                    ),
                                    ..._inspectors.map(
                                      (i) => DropdownMenuItem<int?>(
                                        value: i.id,
                                        child: Text(
                                          i.displayName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _filterInspectorId = v),
                                ),
                              ),
                            SizedBox(
                              width: isMobile ? constraints.maxWidth : 190,
                              child: DropdownButtonFormField<String>(
                                initialValue: _filterStatus,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'სტატუსი',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: '',
                                    child: Text('ყველა სტატუსი'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'pending',
                                    child: Text('მოლოდინში'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'in_progress',
                                    child: Text('მიმდინარე'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'completed',
                                    child: Text('დასრულებული'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'approved',
                                    child: Text('დამტკიცებული'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'rejected',
                                    child: Text('უარყოფილი'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _filterStatus = v ?? ''),
                              ),
                            ),
                            if (_filterInspectorId != null ||
                                _filterStatus.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _filterInspectorId = null;
                                    _filterStatus = '';
                                  });
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('გასუფთავება'),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Calendar Month Grid Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _focusedMonth = DateTime(
                                    _focusedMonth.year,
                                    _focusedMonth.month - 1,
                                  );
                                });
                              },
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Text(
                                DateFormat('MMMM yyyy').format(_focusedMonth),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _focusedMonth = DateTime(
                                    _focusedMonth.year,
                                    _focusedMonth.month + 1,
                                  );
                                });
                              },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(
                              'ორშ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'სამ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'ოთხ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'ხუთ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'პარ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'შაბ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'კვი',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 0.92,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          itemCount: leadingEmptyDays + daysInMonth,
                          itemBuilder: (ctx, index) {
                            if (index < leadingEmptyDays) {
                              return const SizedBox.shrink();
                            }
                            final dayNum = index - leadingEmptyDays + 1;
                            final date = DateTime(
                              _focusedMonth.year,
                              _focusedMonth.month,
                              dayNum,
                            );
                            final dayTasks = _tasksForDay(date);
                            final isSelected = _selectedDay != null &&
                                _selectedDay!.year == date.year &&
                                _selectedDay!.month == date.month &&
                                _selectedDay!.day == date.day;

                            return InkWell(
                              onTap: () {
                                setState(() => _selectedDay = date);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ImpostiColors.primary.withValues(
                                          alpha: 0.14,
                                        )
                                      : const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? ImpostiColors.primary
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.all(3),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$dayNum',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    if (dayTasks.isNotEmpty)
                                      Wrap(
                                        spacing: 2,
                                        runSpacing: 2,
                                        children: dayTasks.take(4).map((t) {
                                          return Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: ImpostiColors.statusColor(
                                                t.status,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Selected Day Tasks
                if (_selectedDay != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'არჩეული დღის დავალებები (${DateFormat('dd.MM.yyyy').format(_selectedDay!)})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isManager)
                        TextButton.icon(
                          onPressed: () =>
                              _openAddTaskModal(initialDate: _selectedDay),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('დამატება ამ დღეს'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (selectedDayTasks.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('ამ დღეს დავალებები არ არის ჩანიშნული'),
                        ),
                      ),
                    )
                  else
                    ...selectedDayTasks.map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            onTap: () => _openEditTaskModal(task),
                            leading: CircleAvatar(
                              backgroundColor: ImpostiColors.statusColor(
                                task.status,
                              ).withValues(alpha: 0.2),
                              child: Icon(
                                Icons.build_circle_outlined,
                                color: ImpostiColors.statusColor(task.status),
                              ),
                            ),
                            title: Text(
                              '${task.equipmentName} — ${task.scheduleName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${task.siteName} • ინსპექტორი: ${task.inspectorDisplay}',
                            ),
                            trailing: StatusBadge(
                              status: task.status,
                              label: task.statusDisplay,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('კალენდარი')),
      body: content,
    );
  }

  Widget _statPill(
    String label,
    int count,
    Color color,
    double width, {
    bool darkText = false,
  }) {
    final fg = darkText ? Colors.black87 : Colors.white;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: fg,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fg, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
