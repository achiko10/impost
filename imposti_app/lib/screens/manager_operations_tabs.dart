import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'calendar_screen.dart';
import 'manager_assets_tabs.dart';
import 'reports_screens.dart';
import 'task_detail_screen.dart';

// ==================== 5. SCHEDULES TAB ====================

class ManagerSchedulesTab extends StatefulWidget {
  const ManagerSchedulesTab({super.key});

  @override
  State<ManagerSchedulesTab> createState() => _ManagerSchedulesTabState();
}

class _ManagerSchedulesTabState extends State<ManagerSchedulesTab> {
  static const List<String> _presets = [
    'ფილტრების გაწმენდა',
    'ფრეონის წნევის შემოწმება',
    'ელექტრო კავშირების შემოწმება',
    'სადრენაჟო სისტემის გაწმენდა',
    'ვენტილატორის შემოწმება',
    'თერმოსტატის კალიბრაცია',
    'სრული ტექნიკური შემოწმება',
  ];

  bool _loading = true;
  List<ScheduleModel> _schedules = [];
  List<EquipmentModel> _equipment = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        ApiService.getSchedules(),
        ApiService.getEquipment(),
      ]);
      setState(() {
        _schedules = res[0] as List<ScheduleModel>;
        _equipment = res[1] as List<EquipmentModel>;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAddEditModal({ScheduleModel? existing}) {
    if (_equipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ჯერ დაამატეთ მინიმუმ 1 დანადგარი')),
      );
      return;
    }
    int eqId = existing?.equipmentId ?? _equipment.first.id;
    String frequency = existing?.frequency ?? 'monthly';
    final taskNameCtrl = TextEditingController(text: existing?.taskName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(
            existing == null ? 'ახალი შემოწმება' : 'გრაფიკის რედაქტირება',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _equipment.any((e) => e.id == eqId)
                        ? eqId
                        : _equipment.first.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'დანადგარი *'),
                    items: _equipment
                        .map(
                          (e) => DropdownMenuItem<int>(
                            value: e.id,
                            child: Text(
                              '${e.siteName} - ${e.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => eqId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: taskNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'შემოწმების სახელი *',
                      hintText: 'აირჩიეთ ქვემოთ ან ჩაწერეთ სასურველი...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _presets
                        .map(
                          (p) => ActionChip(
                            label: Text(p, style: const TextStyle(fontSize: 11)),
                            onPressed: () =>
                                setModalState(() => taskNameCtrl.text = p),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'სიხშირე *'),
                    items: const [
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('თვეში ერთხელ'),
                      ),
                      DropdownMenuItem(
                        value: 'quarterly',
                        child: Text('კვარტალში ერთხელ'),
                      ),
                      DropdownMenuItem(
                        value: 'biannual',
                        child: Text('წელიწადში 2-ჯერ'),
                      ),
                      DropdownMenuItem(
                        value: 'annual',
                        child: Text('წელიწადში ერთხელ'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => frequency = v);
                    },
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
              onPressed: () async {
                if (taskNameCtrl.text.trim().isEmpty) return;
                if (existing == null) {
                  await ApiService.createSchedule(
                    equipmentId: eqId,
                    taskName: taskNameCtrl.text.trim(),
                    frequency: frequency,
                  );
                } else {
                  await ApiService.updateSchedule(
                    id: existing.id,
                    equipmentId: eqId,
                    taskName: taskNameCtrl.text.trim(),
                    frequency: frequency,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'შემოწმებების გრაფიკი',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddEditModal(),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('დამატება'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._schedules.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: ImpostiColors.info,
                    child: Icon(Icons.schedule, color: Colors.white),
                  ),
                  title: Text(
                    '${s.equipmentName} — ${s.taskName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${s.companyName} (${s.siteName}) • სიხშირე: ${s.frequencyDisplay}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _openAddEditModal(existing: s),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: ImpostiColors.primary,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await ApiService.deleteSchedule(s.id);
                          await _load();
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: ImpostiColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 6. TASKS TAB ====================

class ManagerTasksTab extends StatefulWidget {
  final VoidCallback onOpenCalendar;

  const ManagerTasksTab({super.key, required this.onOpenCalendar});

  @override
  State<ManagerTasksTab> createState() => _ManagerTasksTabState();
}

class _ManagerTasksTabState extends State<ManagerTasksTab> {
  bool _loading = true;
  List<TaskModel> _allTasks = [];
  List<AppUser> _inspectors = [];
  final Set<int> _selectedIds = {};

  String _statusFilter = '';
  int? _inspectorFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        ApiService.getTasks(),
        ApiService.getUsers(role: 'inspector'),
      ]);
      setState(() {
        _allTasks = res[0] as List<TaskModel>;
        _inspectors = res[1] as List<AppUser>;
        _selectedIds.clear();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TaskModel> get _filteredTasks {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _allTasks.where((t) {
      if (_statusFilter.isNotEmpty && t.status != _statusFilter) return false;
      if (_inspectorFilter != null && t.assignedToId != _inspectorFilter) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${t.companyName} ${t.siteName} ${t.equipmentName} ${t.scheduleName}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  int _countStatus(String st) =>
      _allTasks.where((t) => t.status == st).length;

  void _openGenerateModal() {
    if (_inspectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ინსპექტორი არ მოიძებნა')),
      );
      return;
    }
    int selectedInspector = _inspectors.first.id;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('ტასკების გენერაცია გრაფიკიდან'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'სისტემა ავტომატურად შექმნის მომდევნო პერიოდის გეგმიურ დავალებებს ყველა აქტიური გრაფიკის მიხედვით (დუბლირების გარეშე).',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: selectedInspector,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'პასუხისმგებელი ინსპექტორი *',
                  ),
                  items: _inspectors
                      .map(
                        (i) => DropdownMenuItem<int>(
                          value: i.id,
                          child: Text(
                            '${i.displayName} (${i.username})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedInspector = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('გაუქმება'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ImpostiColors.success,
              ),
              onPressed: () async {
                final created = await ApiService.generateTasks(
                  inspectorId: selectedInspector,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: ImpostiColors.success,
                      content: Text('წარმატებით შეიქმნა $created ახალი ტასკი!'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('გენერაცია'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkUpdateStatus(String status) async {
    for (final id in _selectedIds) {
      await ApiService.updateTask(id, {'status': status});
    }
    await _load();
  }

  Future<void> _bulkDelete() async {
    for (final id in _selectedIds) {
      await ApiService.deleteTask(id);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final tasks = _filteredTasks;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'დავალებები',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'ნაჩვენებია: ${tasks.length} დავალება',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MonthlyReportScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bar_chart, size: 18),
                    label: const Text('თვიური რეპორტი'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => openReportUrl(context, '/reports/excel/'),
                    icon: const Icon(
                      Icons.table_view,
                      color: ImpostiColors.success,
                      size: 18,
                    ),
                    label: const Text('Excel რეპორტი'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenCalendar,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('კალენდარი'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ImpostiColors.success,
                    ),
                    onPressed: _openGenerateModal,
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('ტასკების გენერაცია'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 6 Status Filter Cards (Responsive 2 or 3 per row on mobile)
          LayoutBuilder(
            builder: (ctx, constraints) {
              final maxW = constraints.maxWidth;
              final cols = maxW < 450 ? 2 : (maxW < 850 ? 3 : 6);
              final cardW = (maxW - (cols - 1) * 10) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _statFilterBox('სულ', _allTasks.length, '', Colors.black87, cardW),
                  _statFilterBox(
                    'მოლოდინში',
                    _countStatus('pending'),
                    'pending',
                    ImpostiColors.secondary,
                    cardW,
                  ),
                  _statFilterBox(
                    'მიმდინარე',
                    _countStatus('in_progress'),
                    'in_progress',
                    ImpostiColors.warning,
                    cardW,
                  ),
                  _statFilterBox(
                    'დასრულებული',
                    _countStatus('completed'),
                    'completed',
                    ImpostiColors.success,
                    cardW,
                  ),
                  _statFilterBox(
                    'დამტკიცებული',
                    _countStatus('approved'),
                    'approved',
                    const Color(0xFF17A2B8),
                    cardW,
                  ),
                  _statFilterBox(
                    'უარყოფილი',
                    _countStatus('rejected'),
                    'rejected',
                    ImpostiColors.danger,
                    cardW,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Filters Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final isMobile = constraints.maxWidth < 540;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: isMobile ? constraints.maxWidth : 240,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'ძებნა...',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: isMobile ? constraints.maxWidth : 210,
                        child: DropdownButtonFormField<int?>(
                          initialValue: _inspectorFilter,
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
                              setState(() => _inspectorFilter = v),
                        ),
                      ),
                      if (_statusFilter.isNotEmpty ||
                          _inspectorFilter != null ||
                          _searchCtrl.text.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _statusFilter = '';
                              _inspectorFilter = null;
                              _searchCtrl.clear();
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
          const SizedBox(height: 12),

          // Bulk Actions Bar
          if (_selectedIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ImpostiColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${_selectedIds.length} არჩეული',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: () => _bulkUpdateStatus('in_progress'),
                    child: const Text('დაწყება'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: () => _bulkUpdateStatus('completed'),
                    child: const Text('დასრულება'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ImpostiColors.danger,
                    ),
                    onPressed: _bulkDelete,
                    child: const Text('წაშლა'),
                  ),
                ],
              ),
            ),

          // Tasks List (Mobile-friendly fluid cards)
          ...tasks.map((task) {
            final checked = _selectedIds.contains(task.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: checked,
                            visualDensity: VisualDensity.compact,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedIds.add(task.id);
                                } else {
                                  _selectedIds.remove(task.id);
                                }
                              });
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${task.equipmentName} — ${task.scheduleName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${task.companyName} (${task.siteName}) • ${task.inspectorDisplay} • ${formatIsoDate(task.scheduledDate)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          StatusBadge(
                            status: task.status,
                            label: task.statusDisplay,
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) async {
                              if (val == 'delete') {
                                await ApiService.deleteTask(task.id);
                              } else {
                                await ApiService.updateTask(task.id, {
                                  'status': val,
                                });
                              }
                              await _load();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'pending',
                                child: Text('მოლოდინში'),
                              ),
                              PopupMenuItem(
                                value: 'in_progress',
                                child: Text('დაწყება (მიმდინარე)'),
                              ),
                              PopupMenuItem(
                                value: 'completed',
                                child: Text('დასრულება'),
                              ),
                              PopupMenuItem(
                                value: 'approved',
                                child: Text('დამტკიცება'),
                              ),
                              PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'წაშლა',
                                  style: TextStyle(color: ImpostiColors.danger),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: 'ნახვა',
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TaskDetailScreen(taskId: task.id),
                                ),
                              );
                              _load();
                            },
                            icon: const Icon(
                              Icons.visibility_outlined,
                              color: ImpostiColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statFilterBox(
    String label,
    int count,
    String filterVal,
    Color color,
    double width,
  ) {
    final active = _statusFilter == filterVal;
    return InkWell(
      onTap: () => setState(() => _statusFilter = filterVal),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF8FBFF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? ImpostiColors.primary : const Color(0xFFE9ECEF),
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 7. USERS TAB ====================

class ManagerUsersTab extends StatefulWidget {
  const ManagerUsersTab({super.key});

  @override
  State<ManagerUsersTab> createState() => _ManagerUsersTabState();
}

class _ManagerUsersTabState extends State<ManagerUsersTab> {
  bool _loading = true;
  List<AppUser> _users = [];
  List<CompanyModel> _companies = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        ApiService.getUsers(),
        ApiService.getCompanies(),
      ]);
      setState(() {
        _users = res[0] as List<AppUser>;
        _companies = res[1] as List<CompanyModel>;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openUserModal({AppUser? existing}) {
    String role = existing?.role == 'client' ? 'client' : 'inspector';
    int? companyId = existing?.companyId ??
        (_companies.isNotEmpty ? _companies.first.id : null);
    final usernameCtrl = TextEditingController(text: existing?.username ?? '');
    final passwordCtrl = TextEditingController();
    final firstCtrl = TextEditingController(text: existing?.firstName ?? '');
    final lastCtrl = TextEditingController(text: existing?.lastName ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(
            existing == null
                ? 'ახალი მომხმარებლის დამატება'
                : 'მომხმარებლის რედაქტირება',
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'როლი *'),
                    items: const [
                      DropdownMenuItem(
                        value: 'inspector',
                        child: Text('ინსპექტორი'),
                      ),
                      DropdownMenuItem(
                        value: 'client',
                        child: Text('კლიენტი'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => role = v);
                    },
                  ),
                  if (role == 'client' && _companies.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: _companies.any((c) => c.id == companyId)
                          ? companyId
                          : _companies.first.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'კლიენტი კომპანია *',
                      ),
                      items: _companies
                          .map(
                            (c) => DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() => companyId = v),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: firstCtrl,
                    decoration: const InputDecoration(labelText: 'სახელი'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: lastCtrl,
                    decoration: const InputDecoration(labelText: 'გვარი'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'ტელეფონი'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'მომხმარებელი (Username) *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? 'პაროლი *'
                          : 'ახალი პაროლი (ცარიელი = უცვლელი)',
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
              onPressed: () async {
                if (usernameCtrl.text.trim().isEmpty) return;
                if (existing == null && passwordCtrl.text.isEmpty) return;
                final payload = <String, dynamic>{
                  'username': usernameCtrl.text.trim(),
                  'role': role,
                  'first_name': firstCtrl.text.trim(),
                  'last_name': lastCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'company': role == 'client' ? companyId : null,
                  if (passwordCtrl.text.isNotEmpty)
                    'password': passwordCtrl.text,
                };
                if (existing == null) {
                  await ApiService.createUser(payload);
                } else {
                  await ApiService.updateUser(existing.id, payload);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    final currentUserId = context.read<AppState>().currentUser?.id;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'მომხმარებლების მართვა',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _openUserModal(),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('დამატება'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._users.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: u.role == 'inspector'
                        ? ImpostiColors.info
                        : u.role == 'manager'
                            ? ImpostiColors.primary
                            : ImpostiColors.secondary,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    '${u.displayName} (${u.username})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'როლი: ${u.roleDisplay}${u.companyName != null ? " • კომპანია: ${u.companyName}" : ""}${u.phone.isNotEmpty ? " • ტელ: ${u.phone}" : ""}',
                  ),
                  trailing: u.id == currentUserId
                      ? const Chip(label: Text('თქვენ'))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _openUserModal(existing: u),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: ImpostiColors.primary,
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                await ApiService.deleteUser(u.id);
                                await _load();
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: ImpostiColors.danger,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== MANAGER SHELL (SIDEBAR + DRAWER + BOTTOM NAV) ====================

class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int _selectedIndex = 0;

  static const List<({IconData icon, String label})> _navItems = [
    (icon: Icons.speed, label: 'დაშბორდი'),
    (icon: Icons.business, label: 'კომპანიები'),
    (icon: Icons.location_on_outlined, label: 'ობიექტები'),
    (icon: Icons.settings_outlined, label: 'დანადგარები'),
    (icon: Icons.schedule, label: 'გრაფიკები'),
    (icon: Icons.checklist, label: 'დავალებები'),
    (icon: Icons.calendar_month_outlined, label: 'კალენდარი'),
    (icon: Icons.people_outline, label: 'მომხმარებლები'),
  ];

  // Quick bottom navigation mapping on mobile (0: Dashboard, 5: Tasks, 3: Equipment, 6: Calendar, 7: Users)
  static const List<int> _mobileQuickTabs = [0, 5, 3, 6, 7];

  Widget _buildActivePage() {
    switch (_selectedIndex) {
      case 0:
        return ManagerDashboardTab(
          onNavigateTab: (idx) => setState(() => _selectedIndex = idx),
        );
      case 1:
        return const ManagerCompaniesTab();
      case 2:
        return const ManagerSitesTab();
      case 3:
        return const ManagerEquipmentTab();
      case 4:
        return const ManagerSchedulesTab();
      case 5:
        return ManagerTasksTab(
          onOpenCalendar: () => setState(() => _selectedIndex = 6),
        );
      case 6:
        return const CalendarScreen(embedded: true);
      case 7:
        return const ManagerUsersTab();
      default:
        return ManagerDashboardTab(
          onNavigateTab: (idx) => setState(() => _selectedIndex = idx),
        );
    }
  }

  Widget _buildSidebarContent(AppState appState, {bool inDrawer = false}) {
    final user = appState.currentUser;
    return Container(
      width: 240,
      color: ImpostiColors.sidebarBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ImpostiLogo(height: 36),
                  const SizedBox(height: 6),
                  Text(
                    user?.tenantName ?? 'ადმინ პანელი',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _navItems.length,
                itemBuilder: (ctx, i) {
                  final item = _navItems[i];
                  final active = _selectedIndex == i;
                  return ListTile(
                    selected: active,
                    selectedTileColor: Colors.white.withValues(alpha: 0.1),
                    leading: Icon(
                      item.icon,
                      color: active ? Colors.white : Colors.white70,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.white70,
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedIndex = i);
                      if (inDrawer) Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: const Text(
                'გასვლა',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () => appState.logout(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isWide = MediaQuery.of(context).size.width >= 900;
    final quickIndex = _mobileQuickTabs.indexOf(_selectedIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _navItems[_selectedIndex].label,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          const NotificationsBellButton(),
          if (isWide)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  appState.currentUser?.displayName ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      drawer: isWide
          ? null
          : Drawer(child: _buildSidebarContent(appState, inDrawer: true)),
      body: Row(
        children: [
          if (isWide) _buildSidebarContent(appState),
          Expanded(child: _buildActivePage()),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              currentIndex: quickIndex >= 0 ? quickIndex : 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: ImpostiColors.primary,
              unselectedItemColor: Colors.grey,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              onTap: (idx) {
                setState(() => _selectedIndex = _mobileQuickTabs[idx]);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.speed),
                  label: 'დაშბორდი',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.checklist),
                  label: 'დავალებები',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  label: 'დანადგარები',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'კალენდარი',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline),
                  label: 'პერსონალი',
                ),
              ],
            ),
    );
  }
}
