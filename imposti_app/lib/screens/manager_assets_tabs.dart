import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'reports_screens.dart';
import 'task_detail_screen.dart';

// ==================== 1. MANAGER DASHBOARD TAB ====================

class ManagerDashboardTab extends StatefulWidget {
  final void Function(int navIndex) onNavigateTab;

  const ManagerDashboardTab({super.key, required this.onNavigateTab});

  @override
  State<ManagerDashboardTab> createState() => _ManagerDashboardTabState();
}

class _ManagerDashboardTabState extends State<ManagerDashboardTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _taskStatusData = {};
  Map<String, dynamic> _monthlyData = {};
  List<Map<String, dynamic>> _inspectorStats = [];
  List<TaskModel> _urgentTasks = [];
  List<TaskModel> _recentTasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getManagerDashboard();
      setState(() {
        _stats = Map<String, dynamic>.from(data['stats'] ?? {});
        _taskStatusData = Map<String, dynamic>.from(
          data['task_status_data'] ?? {},
        );
        _monthlyData = Map<String, dynamic>.from(data['monthly_data'] ?? {});
        _inspectorStats = (data['inspector_stats'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _urgentTasks = (data['urgent_tasks'] as List<dynamic>? ?? [])
            .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _recentTasks = (data['recent_tasks'] as List<dynamic>? ?? [])
            .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('შეცდომა: $_error'));

    final statusLabels = List<String>.from(
      _taskStatusData['labels'] ?? const [],
    );
    final statusValues = List<dynamic>.from(
      _taskStatusData['values'] ?? const [],
    );
    final statusColors = List<String>.from(
      _taskStatusData['colors'] ?? const [],
    );

    final monthlyLabels = List<String>.from(_monthlyData['labels'] ?? const []);
    final monthlyValues = List<dynamic>.from(
      _monthlyData['values'] ?? const [],
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth - 32; // padding 16*2
          final isMobile = maxW < 600;
          final kpiWidth = isMobile ? (maxW - 10) / 2 : (maxW - 50) / 6;
          final panelWidth = isMobile ? maxW : (maxW - 16) / 2;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.speed, color: ImpostiColors.primary, size: 26),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'მენეჯერის დაშბორდი',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                        onPressed: () =>
                            openReportUrl(context, '/reports/excel/'),
                        icon: const Icon(
                          Icons.table_view,
                          color: ImpostiColors.success,
                          size: 18,
                        ),
                        label: const Text('Excel'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => widget.onNavigateTab(6),
                        icon: const Icon(Icons.calendar_month, size: 18),
                        label: const Text('კალენდარი'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 6 Main KPI Cards (2-col on mobile, 6-col on wide)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _kpiBox(
                    kpiWidth,
                    'კომპანიები',
                    _stats['companies'] ?? 0,
                    Icons.business,
                    ImpostiColors.primary,
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  _kpiBox(
                    kpiWidth,
                    'ობიექტები',
                    _stats['sites'] ?? 0,
                    Icons.location_on,
                    ImpostiColors.success,
                    onTap: () => widget.onNavigateTab(2),
                  ),
                  _kpiBox(
                    kpiWidth,
                    'დანადგარები',
                    _stats['equipment'] ?? 0,
                    Icons.settings,
                    ImpostiColors.info,
                    onTap: () => widget.onNavigateTab(3),
                  ),
                  _kpiBox(
                    kpiWidth,
                    'მოლოდინში',
                    _stats['tasks_pending'] ?? 0,
                    Icons.hourglass_bottom,
                    ImpostiColors.warning,
                    darkText: true,
                    onTap: () => widget.onNavigateTab(5),
                  ),
                  _kpiBox(
                    kpiWidth,
                    'დასრულებული',
                    _stats['tasks_completed'] ?? 0,
                    Icons.check_circle,
                    ImpostiColors.success,
                    onTap: () => widget.onNavigateTab(5),
                  ),
                  _kpiBox(
                    kpiWidth,
                    'ვადაგასული!',
                    _stats['tasks_overdue'] ?? 0,
                    Icons.warning_amber_rounded,
                    ImpostiColors.danger,
                    onTap: () => widget.onNavigateTab(5),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Distribution & Monthly Chart Row
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  // Task Status Breakdown
                  SizedBox(
                    width: panelWidth,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.pie_chart_outline,
                                  color: ImpostiColors.primary,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ტასკების სტატუსი',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            ...List.generate(statusLabels.length, (i) {
                              final lbl = statusLabels[i];
                              final val = (statusValues.length > i
                                  ? (statusValues[i] as num).toInt()
                                  : 0);
                              final total = (_stats['tasks_total'] ?? 1) as int;
                              final ratio = total > 0
                                  ? (val / total).clamp(0.0, 1.0)
                                  : 0.0;
                              final clr = ImpostiColors.parseHex(
                                statusColors.length > i
                                    ? statusColors[i]
                                    : null,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lbl,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$val',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 8,
                                      color: clr,
                                      backgroundColor: const Color(0xFFE9ECEF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Monthly Completed Chart
                  SizedBox(
                    width: panelWidth,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.bar_chart,
                                  color: ImpostiColors.success,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'დასრულებული ტასკები (თვეებით)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            if (monthlyLabels.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text('ჯერ დასრულებული ტასკები არ არის'),
                                ),
                              )
                            else
                              ...List.generate(monthlyLabels.length, (i) {
                                final m = monthlyLabels[i];
                                final v = (monthlyValues.length > i
                                    ? (monthlyValues[i] as num).toInt()
                                    : 0);
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: ImpostiColors.success,
                                  ),
                                  title: Text(m),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ImpostiColors.success,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$v დასრულებული',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Inspector Performance & Urgent Tasks
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  // Inspector Performance
                  SizedBox(
                    width: panelWidth,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  color: ImpostiColors.primary,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'ინსპექტორების სტატისტიკა',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => widget.onNavigateTab(7),
                                  child: const Text('მართვა'),
                                ),
                              ],
                            ),
                            const Divider(),
                            if (_inspectorStats.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('ინსპექტორები არ მოიძებნა'),
                              )
                            else
                              ..._inspectorStats.map((ins) {
                                final name =
                                    '${ins['first_name'] ?? ''} ${ins['last_name'] ?? ''}'
                                        .trim();
                                final displayName = name.isNotEmpty
                                    ? name
                                    : (ins['username'] ?? '');
                                final total = (ins['total_tasks'] ?? 0) as int;
                                final completed =
                                    (ins['completed_tasks'] ?? 0) as int;
                                final ratio =
                                    total > 0 ? completed / total : 0.0;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '$completed / $total (${(ratio * 100).round()}%)',
                                            style: const TextStyle(
                                              color: ImpostiColors.success,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      LinearProgressIndicator(
                                        value: ratio,
                                        minHeight: 8,
                                        color: ImpostiColors.success,
                                        backgroundColor:
                                            const Color(0xFFE9ECEF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Urgent Tasks
                  SizedBox(
                    width: panelWidth,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.alarm,
                                  color: ImpostiColors.danger,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'უახლოესი 7 დღის ტასკები',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            if (_urgentTasks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('სასწრაფო ტასკები არ არის'),
                              )
                            else
                              ..._urgentTasks.map(
                                (t) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            TaskDetailScreen(taskId: t.id),
                                      ),
                                    );
                                    _load();
                                  },
                                  title: Text(
                                    t.equipmentName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${t.siteName} • ${t.scheduleName}',
                                  ),
                                  trailing: Text(
                                    formatIsoDate(t.scheduledDate),
                                    style: const TextStyle(
                                      color: ImpostiColors.warning,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recent Tasks List
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.history,
                            color: ImpostiColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'ბოლო ტასკები',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => widget.onNavigateTab(5),
                            child: const Text('ყველას ნახვა →'),
                          ),
                        ],
                      ),
                      const Divider(),
                      ..._recentTasks.map(
                        (task) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TaskDetailScreen(taskId: task.id),
                              ),
                            );
                            _load();
                          },
                          title: Text(
                            '${task.equipmentName} — ${task.scheduleName}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${task.companyName} (${task.siteName}) • ${task.inspectorDisplay} • ${formatIsoDate(task.scheduledDate)}',
                          ),
                          trailing: StatusBadge(
                            status: task.status,
                            label: task.statusDisplay,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpiBox(
    double width,
    String label,
    int value,
    IconData icon,
    Color bg, {
    bool darkText = false,
    VoidCallback? onTap,
  }) {
    final fg = darkText ? Colors.black87 : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: fg,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(icon, color: fg.withValues(alpha: 0.65), size: 22),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 2. COMPANIES TAB ====================

class ManagerCompaniesTab extends StatefulWidget {
  const ManagerCompaniesTab({super.key});

  @override
  State<ManagerCompaniesTab> createState() => _ManagerCompaniesTabState();
}

class _ManagerCompaniesTabState extends State<ManagerCompaniesTab> {
  bool _loading = true;
  List<CompanyModel> _companies = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getCompanies();
      setState(() => _companies = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAddEditModal({CompanyModel? existing}) {
    final ctrl = TextEditingController(text: existing?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(
          existing == null ? 'ახალი კომპანია' : 'კომპანიის რედაქტირება',
        ),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'კომპანიის სახელი *'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('გაუქმება'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              try {
                if (existing == null) {
                  await ApiService.createCompany(name);
                } else {
                  await ApiService.updateCompany(existing.id, name);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
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
    );
  }

  Future<void> _deleteCompany(CompanyModel company) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('კომპანიის წაშლა'),
        content: Text('წავშალოთ კომპანია "${company.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('გაუქმება'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ImpostiColors.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('წაშლა'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.deleteCompany(company.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth - 32;
          final cardWidth = maxW < 640 ? maxW : (maxW - 16) / 2;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'კომპანიები',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openAddEditModal(),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('დამატება'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _companies.map((c) {
                  return SizedBox(
                    width: cardWidth,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.business,
                                  color: ImpostiColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'შექმნილია: ${formatIsoDate(c.createdAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ობიექტები: ${c.sitesCount} • დანადგარები: ${c.equipmentCount}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const Divider(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => openReportUrl(
                                    context,
                                    '/reports/pdf/${c.id}/',
                                    downloadPdf: true,
                                  ),
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    color: ImpostiColors.danger,
                                    size: 16,
                                  ),
                                  label: const Text('PDF რეპორტი'),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'რედაქტირება',
                                      onPressed: () =>
                                          _openAddEditModal(existing: c),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: ImpostiColors.primary,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'წაშლა',
                                      onPressed: () => _deleteCompany(c),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: ImpostiColors.danger,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==================== 3. SITES TAB ====================

class ManagerSitesTab extends StatefulWidget {
  const ManagerSitesTab({super.key});

  @override
  State<ManagerSitesTab> createState() => _ManagerSitesTabState();
}

class _ManagerSitesTabState extends State<ManagerSitesTab> {
  bool _loading = true;
  List<SiteModel> _sites = [];
  List<CompanyModel> _companies = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getSites(),
        ApiService.getCompanies(),
      ]);
      setState(() {
        _sites = results[0] as List<SiteModel>;
        _companies = results[1] as List<CompanyModel>;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAddEditModal({SiteModel? existing}) {
    if (_companies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ჯერ დაამატეთ მინიმუმ 1 კომპანია')),
      );
      return;
    }
    int selectedCompanyId = existing?.companyId ?? _companies.first.id;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(
            existing == null ? 'ახალი ობიექტი' : 'ობიექტის რედაქტირება',
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue:
                        _companies.any((c) => c.id == selectedCompanyId)
                            ? selectedCompanyId
                            : _companies.first.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'კომპანია *'),
                    items: _companies
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedCompanyId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ობიექტის სახელი *',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addrCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'მისამართი *'),
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
                if (nameCtrl.text.trim().isEmpty) return;
                if (existing == null) {
                  await ApiService.createSite(
                    companyId: selectedCompanyId,
                    name: nameCtrl.text.trim(),
                    address: addrCtrl.text.trim(),
                  );
                } else {
                  await ApiService.updateSite(
                    id: existing.id,
                    companyId: selectedCompanyId,
                    name: nameCtrl.text.trim(),
                    address: addrCtrl.text.trim(),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'ობიექტები',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddEditModal(),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('დამატება'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._sites.map(
            (site) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: ImpostiColors.primary,
                    child: Icon(Icons.location_on, color: Colors.white),
                  ),
                  title: Text(
                    site.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'კომპანია: ${site.companyName}\nმისამართი: ${site.address} • დანადგარები: ${site.equipmentCount}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _openAddEditModal(existing: site),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: ImpostiColors.primary,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await ApiService.deleteSite(site.id);
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

// ==================== 4. EQUIPMENT TAB ====================

class ManagerEquipmentTab extends StatefulWidget {
  const ManagerEquipmentTab({super.key});

  @override
  State<ManagerEquipmentTab> createState() => _ManagerEquipmentTabState();
}

class _ManagerEquipmentTabState extends State<ManagerEquipmentTab> {
  bool _loading = true;
  List<EquipmentModel> _equipment = [];
  List<CategoryModel> _categories = [];
  List<SiteModel> _sites = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        ApiService.getEquipment(),
        ApiService.getCategories(),
        ApiService.getSites(),
      ]);
      setState(() {
        _equipment = res[0] as List<EquipmentModel>;
        _categories = res[1] as List<CategoryModel>;
        _sites = res[2] as List<SiteModel>;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAddCategoryModal() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String systemType = 'hvac';
    String icon = 'bi-fan';
    String color = '#0d6efd';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('ახალი კატეგორია'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'კატეგორიის სახელი *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'უნიკალური კოდი (მაგ: AHU) *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: systemType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'სისტემის ტიპი',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'hvac',
                        child: Text('გათბობა/გაგრილება (HVAC)'),
                      ),
                      DropdownMenuItem(
                        value: 'ventilation',
                        child: Text('ვენტილაცია'),
                      ),
                      DropdownMenuItem(
                        value: 'refrigeration',
                        child: Text('სამაცივრო'),
                      ),
                      DropdownMenuItem(
                        value: 'electrical',
                        child: Text('ელექტრო'),
                      ),
                      DropdownMenuItem(
                        value: 'plumbing',
                        child: Text('სანტექნიკა'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => systemType = v);
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
                if (nameCtrl.text.trim().isEmpty ||
                    codeCtrl.text.trim().isEmpty) {
                  return;
                }
                await ApiService.createCategory(
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                  systemType: systemType,
                  icon: icon,
                  color: color,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: const Text('შექმნა'),
            ),
          ],
        ),
      ),
    );
  }

  void _openEquipmentModal({EquipmentModel? existing}) {
    if (_sites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ჯერ დაამატეთ მინიმუმ 1 ობიექტი')),
      );
      return;
    }
    int siteId = existing?.siteId ?? _sites.first.id;
    int? categoryId = existing?.categoryId;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final brandCtrl = TextEditingController(text: existing?.brand ?? '');
    final modelCtrl = TextEditingController(text: existing?.modelNumber ?? '');
    final serialCtrl = TextEditingController(
      text: existing?.serialNumber ?? '',
    );
    final locCtrl = TextEditingController(text: existing?.locationDetail ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String systemType = existing?.systemType ?? 'heating_cooling';
    String status = existing?.status ?? 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(
            existing == null ? 'ახალი დანადგარი' : 'დანადგარის რედაქტირება',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _sites.any((s) => s.id == siteId)
                        ? siteId
                        : _sites.first.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'ობიექტი *'),
                    items: _sites
                        .map(
                          (s) => DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(
                              '${s.companyName} - ${s.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => siteId = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: _categories.any((c) => c.id == categoryId)
                        ? categoryId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'კატეგორია'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('კატეგორიის გარეშე'),
                      ),
                      ..._categories.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(
                            '${c.name} (${c.code})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => categoryId = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'დანადგარის სახელი *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: brandCtrl,
                    decoration: const InputDecoration(labelText: 'ბრენდი'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: modelCtrl,
                    decoration: const InputDecoration(labelText: 'მოდელი'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: serialCtrl,
                    decoration: const InputDecoration(
                      labelText: 'სერიული ნომერი',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: systemType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'სისტემის ტიპი',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'heating_cooling',
                        child: Text('გათბობა/გაგრილება'),
                      ),
                      DropdownMenuItem(
                        value: 'ventilation',
                        child: Text('ვენტილაცია'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => systemType = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'სტატუსი'),
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('აქტიური'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('არააქტიური'),
                      ),
                      DropdownMenuItem(
                        value: 'maintenance',
                        child: Text('მომსახურებაში'),
                      ),
                      DropdownMenuItem(
                        value: 'broken',
                        child: Text('გაფუჭებული'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => status = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ზუსტი მდებარეობა',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'შენიშვნები'),
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
                if (nameCtrl.text.trim().isEmpty) return;
                final payload = {
                  'site': siteId,
                  'category': categoryId,
                  'name': nameCtrl.text.trim(),
                  'brand': brandCtrl.text.trim(),
                  'model_number': modelCtrl.text.trim(),
                  'serial_number': serialCtrl.text.trim(),
                  'system_type': systemType,
                  'status': status,
                  'location_detail': locCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                };
                if (existing == null) {
                  await ApiService.createEquipment(payload);
                } else {
                  await ApiService.updateEquipment(existing.id, payload);
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

    final filtered = _selectedCategoryId == null
        ? _equipment
        : _equipment
            .where((e) => e.categoryId == _selectedCategoryId)
            .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                    'დანადგარები',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'სულ: ${_equipment.length} მოწყობილობა',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openAddCategoryModal,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('კატეგორია'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openEquipmentModal(),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('დანადგარი'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category Filter Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('ყველა (${_equipment.length})'),
                selected: _selectedCategoryId == null,
                onSelected: (_) => setState(() => _selectedCategoryId = null),
              ),
              ..._categories.map(
                (cat) => ChoiceChip(
                  label: Text('${cat.name} (${cat.equipmentCount})'),
                  selected: _selectedCategoryId == cat.id,
                  onSelected: (_) =>
                      setState(() => _selectedCategoryId = cat.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ...filtered.map(
            (eq) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            ImpostiColors.bootstrapIcon(eq.categoryIcon),
                            color: ImpostiColors.parseHex(eq.categoryColor),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              eq.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          EquipmentStatusBadge(
                            status: eq.status,
                            label: eq.statusDisplay,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${eq.companyName} — ${eq.siteName}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ბრენდი: ${eq.brand.isEmpty ? "-" : eq.brand} • მოდელი: ${eq.modelNumber.isEmpty ? "-" : eq.modelNumber} • სერიული №: ${eq.serialNumber.isEmpty ? "-" : eq.serialNumber}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EquipmentHistoryScreen(
                                    equipmentId: eq.id,
                                    equipmentName: eq.name,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.history, size: 16),
                            label: const Text('ისტორია'),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'რედაქტირება',
                                onPressed: () =>
                                    _openEquipmentModal(existing: eq),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: ImpostiColors.primary,
                                ),
                              ),
                              IconButton(
                                tooltip: 'წაშლა',
                                onPressed: () async {
                                  await ApiService.deleteEquipment(eq.id);
                                  await _load();
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: ImpostiColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ],
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
