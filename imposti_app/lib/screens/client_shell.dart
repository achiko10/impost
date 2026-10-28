import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'reports_screens.dart';
import 'task_detail_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  bool _loading = true;
  String? _error;
  CompanyModel? _company;
  Map<String, dynamic> _stats = {};
  List<EquipmentModel> _equipment = [];
  List<TaskModel> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getClientDashboard();
      if (data['error'] != null && data['company'] == null) {
        setState(() {
          _error = data['error'].toString();
          _company = null;
        });
        return;
      }
      setState(() {
        _company = data['company'] != null
            ? CompanyModel.fromJson(Map<String, dynamic>.from(data['company']))
            : null;
        _stats = Map<String, dynamic>.from(data['stats'] ?? {});
        _equipment = (data['equipment'] as List<dynamic>? ?? [])
            .map((e) => EquipmentModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _tasks = (data['tasks'] as List<dynamic>? ?? [])
            .map((t) => TaskModel.fromJson(Map<String, dynamic>.from(t)))
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveTask(TaskModel task) async {
    try {
      await ApiService.approveTask(task.id);
      await _loadDashboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ImpostiColors.success,
            content: Text('დავალება დადასტურებულია!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('შეცდომა: $e')),
        );
      }
    }
  }

  Future<void> _openRejectModal(TaskModel task) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('სერვისის უარყოფა'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'დავალება: ${task.equipmentName} — ${task.scheduleName}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'უარყოფის მიზეზი / შენიშვნა *',
                  hintText:
                      'მიუთითეთ რატომ არ ეთანხმებით შესრულებულ სამუშაოს...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('გაუქმება'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ImpostiColors.danger,
            ),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('უარყოფა'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.rejectTask(task.id, reasonCtrl.text.trim());
      await _loadDashboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ImpostiColors.warning,
            content: Text('დავალება უარყოფილია!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('შეცდომა: $e')),
        );
      }
    }
  }

  void _openReportModal(TaskModel task) {
    final report = task.report;
    if (report == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text('${task.equipmentName} — ${task.scheduleName}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'კომენტარი:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.comment.isNotEmpty
                        ? report.comment
                        : 'კომენტარი არ არის',
                  ),
                ),
                if (report.photos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'ფოტოები (${report.photos.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: report.photos.map((p) {
                      final url = ApiService.resolveMediaUrl(p.imageUrl);
                      return InkWell(
                        onTap: () => showPhotoLightbox(context, p.imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('დახურვა'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const ImpostiLogo(height: 30),
        actions: [
          const NotificationsBellButton(),
          IconButton(
            tooltip: 'გასვლა',
            onPressed: () => appState.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: ImpostiColors.danger,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header & Export Buttons
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.business,
                                    color: ImpostiColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _company?.name ?? 'კლიენტის პანელი',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                'ტექნიკური მომსახურების მართვის პანელი',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (_company != null)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ImpostiColors.danger,
                                  ),
                                  onPressed: () => openReportUrl(
                                    context,
                                    '/reports/pdf/${_company!.id}/',
                                    downloadPdf: true,
                                  ),
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    size: 18,
                                  ),
                                  label: const Text('PDF რეპორტი'),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ImpostiColors.success,
                                  ),
                                  onPressed: () => openReportUrl(
                                    context,
                                    '/reports/excel/',
                                  ),
                                  icon: const Icon(
                                    Icons.table_view_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Excel რეპორტი'),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // KPI Cards (2x2 on mobile)
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final maxW = constraints.maxWidth;
                          final cols = maxW < 600 ? 2 : 4;
                          final cardW = (maxW - (cols - 1) * 12) / cols;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _kpiCard(
                                'მოწყობილობები',
                                _stats['equipment'] ?? _equipment.length,
                                ImpostiColors.primary,
                                cardW,
                              ),
                              _kpiCard(
                                'სულ სერვისები',
                                _stats['tasks_total'] ?? _tasks.length,
                                ImpostiColors.info,
                                cardW,
                              ),
                              _kpiCard(
                                'დასადასტურებელი',
                                _stats['tasks_completed'] ?? 0,
                                ImpostiColors.success,
                                cardW,
                              ),
                              _kpiCard(
                                'დადასტურებული',
                                _stats['tasks_approved'] ?? 0,
                                ImpostiColors.warning,
                                cardW,
                                darkText: true,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Services History Section
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              color: Colors.white,
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.assignment_outlined,
                                    color: ImpostiColors.primary,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'სერვისების ისტორია',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            if (_tasks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text('სერვისები ჯერ არ არის'),
                                ),
                              )
                            else
                              ..._tasks.map(
                                (task) => Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFE9ECEF),
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                  'ფილიალი: ${task.siteName} • ინსპექტორი: ${task.inspectorDisplay}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                                Text(
                                                  'თარიღი: ${formatIsoDate(task.scheduledDate)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusBadge(
                                            status: task.status,
                                            label: task.statusDisplay,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          if (task.report != null)
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _openReportModal(task),
                                              icon: const Icon(
                                                Icons.description_outlined,
                                                size: 16,
                                              ),
                                              label: Text(
                                                task.report!.photos.isNotEmpty
                                                    ? 'რეპორტი (${task.report!.photos.length})'
                                                    : 'რეპორტი',
                                              ),
                                            ),
                                          if (task.status == 'completed') ...[
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    ImpostiColors.success,
                                              ),
                                              onPressed: () =>
                                                  _approveTask(task),
                                              icon: const Icon(
                                                Icons.check,
                                                size: 16,
                                              ),
                                              label: const Text('დადასტურება'),
                                            ),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    ImpostiColors.danger,
                                              ),
                                              onPressed: () =>
                                                  _openRejectModal(task),
                                              icon: const Icon(
                                                Icons.close,
                                                size: 16,
                                              ),
                                              label: const Text('უარყოფა'),
                                            ),
                                          ],
                                          if (task.status == 'completed' ||
                                              task.status == 'approved')
                                            OutlinedButton.icon(
                                              onPressed: () => openReportUrl(
                                                context,
                                                '/reports/task/${task.id}/pdf/',
                                                downloadPdf: true,
                                              ),
                                              icon: const Icon(
                                                Icons.picture_as_pdf,
                                                color: ImpostiColors.danger,
                                                size: 16,
                                              ),
                                              label: const Text('PDF'),
                                            ),
                                          IconButton(
                                            tooltip: 'დეტალურად',
                                            onPressed: () async {
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      TaskDetailScreen(
                                                    taskId: task.id,
                                                  ),
                                                ),
                                              );
                                              _loadDashboard();
                                            },
                                            icon: const Icon(
                                              Icons.open_in_new,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Our Equipment Section
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              color: Colors.white,
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.settings_outlined,
                                    color: ImpostiColors.primary,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'ჩვენი მოწყობილობები',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: LayoutBuilder(
                                builder: (ctx, constraints) {
                                  final isMobile = constraints.maxWidth < 550;
                                  final itemW = isMobile
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 12) / 2;
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: _equipment.map((eq) {
                                      return SizedBox(
                                        width: itemW,
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFFDEE2E6),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      eq.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
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
                                                'ფილიალი: ${eq.siteName}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              if (eq.brand.isNotEmpty ||
                                                  eq.modelNumber.isNotEmpty)
                                                Text(
                                                  'ბრენდი/მოდელი: ${eq.brand} ${eq.modelNumber}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              const SizedBox(height: 8),
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: TextButton.icon(
                                                  onPressed: () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            EquipmentHistoryScreen(
                                                          equipmentId: eq.id,
                                                          equipmentName:
                                                              eq.name,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.history,
                                                    size: 16,
                                                  ),
                                                  label: const Text('ისტორია'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _kpiCard(
    String label,
    int value,
    Color bg,
    double width, {
    bool darkText = false,
  }) {
    final fg = darkText ? Colors.black87 : Colors.white;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: fg,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fg.withValues(alpha: 0.9), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
