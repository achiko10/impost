import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'task_detail_screen.dart';

class EquipmentHistoryScreen extends StatefulWidget {
  final int equipmentId;
  final String equipmentName;

  const EquipmentHistoryScreen({
    super.key,
    required this.equipmentId,
    required this.equipmentName,
  });

  @override
  State<EquipmentHistoryScreen> createState() => _EquipmentHistoryScreenState();
}

class _EquipmentHistoryScreenState extends State<EquipmentHistoryScreen> {
  bool _loading = true;
  String? _error;
  EquipmentModel? _equipment;
  List<TaskModel> _tasks = [];

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
      final data = await ApiService.getEquipmentHistoryJson(widget.equipmentId);
      final eq = EquipmentModel.fromJson(
        Map<String, dynamic>.from(data['equipment']),
      );
      final tasksList = (data['tasks'] as List<dynamic>? ?? [])
          .map((t) => TaskModel.fromJson(Map<String, dynamic>.from(t)))
          .toList();
      setState(() {
        _equipment = eq;
        _tasks = tasksList;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.equipmentName} — ისტორია',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'ბეჭდვა / ვებ-ხედი',
            onPressed: () => openReportUrl(
              context,
              '/reports/equipment/${widget.equipmentId}/',
            ),
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('შეცდომა: $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_equipment != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _equipment!.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    EquipmentStatusBadge(
                                      status: _equipment!.status,
                                      label: _equipment!.statusDisplay,
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Wrap(
                                  spacing: 24,
                                  runSpacing: 10,
                                  children: [
                                    _infoItem(
                                      'კომპანია',
                                      _equipment!.companyName,
                                    ),
                                    _infoItem('ობიექტი', _equipment!.siteName),
                                    _infoItem(
                                      'ბრენდი',
                                      _equipment!.brand.isNotEmpty
                                          ? _equipment!.brand
                                          : '-',
                                    ),
                                    _infoItem(
                                      'მოდელი',
                                      _equipment!.modelNumber.isNotEmpty
                                          ? _equipment!.modelNumber
                                          : '-',
                                    ),
                                    _infoItem(
                                      'სერიული №',
                                      _equipment!.serialNumber.isNotEmpty
                                          ? _equipment!.serialNumber
                                          : '-',
                                    ),
                                    _infoItem(
                                      'სისტემა',
                                      _equipment!.systemTypeDisplay,
                                    ),
                                    _infoItem(
                                      'სულ სერვისები',
                                      '${_tasks.length}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'შესრულებული და დაგეგმილი სამუშაოები',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_tasks.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('სერვისის ისტორია ცარიელია'),
                            ),
                          ),
                        )
                      else
                        ..._tasks.map(
                          (task) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
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
                                  task.scheduleName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'ინსპექტორი: ${task.inspectorDisplay} • დაგეგმილი: ${formatIsoDate(task.scheduledDate)}',
                                    ),
                                    if (task.completedDate != null)
                                      Text(
                                        'დასრულდა: ${formatIsoDate(task.completedDate, withTime: true)}',
                                        style: const TextStyle(
                                          color: ImpostiColors.success,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (task.report != null &&
                                        task.report!.comment.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'კომენტარი: ${task.report!.comment}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
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
                  ),
                ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  bool _loading = true;
  String? _error;
  String _month = '';
  int _totalTasks = 0;
  Map<String, dynamic> _companiesData = {};

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
      final data = await ApiService.getMonthlyReportJson();
      setState(() {
        _month = data['month'] ?? '';
        _totalTasks = data['total_tasks'] ?? 0;
        _companiesData = Map<String, dynamic>.from(
          data['companies_data'] ?? {},
        );
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ყოველთვიური რეპორტი — $_month',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'ბეჭდვა / ვებ-ხედი',
            onPressed: () => openReportUrl(context, '/reports/monthly/'),
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('შეცდომა: $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: ImpostiColors.primary,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'თვის ჯამური დავალებები',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _month,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$_totalTasks',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_companiesData.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('ამ თვეში დავალებები არ მოიძებნა'),
                            ),
                          ),
                        )
                      else
                        ..._companiesData.entries.map((entry) {
                          final companyName = entry.key;
                          final stats = Map<String, dynamic>.from(entry.value);
                          final total = (stats['total'] ?? 0) as int;
                          final completed = (stats['completed'] ?? 0) as int;
                          final pending = (stats['pending'] ?? 0) as int;
                          final ratio = total > 0 ? completed / total : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            companyName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(ratio * 100).round()}% შესრულებული',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: ImpostiColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                      color: ImpostiColors.success,
                                      backgroundColor: const Color(0xFFE9ECEF),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _statCol('სულ', total, Colors.black87),
                                        _statCol(
                                          'დასრულებული',
                                          completed,
                                          ImpostiColors.success,
                                        ),
                                        _statCol(
                                          'მოლოდინში',
                                          pending,
                                          ImpostiColors.warning,
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
                ),
    );
  }

  Widget _statCol(String label, int val, Color color) {
    return Column(
      children: [
        Text(
          '$val',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
