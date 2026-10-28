import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'calendar_screen.dart';
import 'task_detail_screen.dart';

class InspectorShell extends StatefulWidget {
  const InspectorShell({super.key});

  @override
  State<InspectorShell> createState() => _InspectorShellState();
}

class _InspectorShellState extends State<InspectorShell> {
  int _tabIndex = 0; // 0 = My Tasks, 1 = Calendar
  bool _loading = true;
  List<TaskModel> _allTasks = [];
  String _statusFilter = ''; // '', 'pending', 'in_progress', 'rejected', 'done'
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final tasks = await ApiService.getTasks();
      setState(() => _allTasks = tasks);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TaskModel> get _filteredTasks {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _allTasks.where((t) {
      if (_statusFilter == 'done') {
        if (t.status != 'completed' && t.status != 'approved') return false;
      } else if (_statusFilter.isNotEmpty) {
        if (t.status != _statusFilter) return false;
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

  int get _pendingCount =>
      _allTasks.where((t) => t.status == 'pending').length;
  int get _inProgressCount =>
      _allTasks.where((t) => t.status == 'in_progress').length;
  int get _rejectedCount =>
      _allTasks.where((t) => t.status == 'rejected').length;
  int get _doneCount => _allTasks
      .where((t) => t.status == 'completed' || t.status == 'approved')
      .length;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: const ImpostiLogo(height: 30),
        actions: [
          if (isWide) ...[
            TextButton.icon(
              onPressed: () => setState(() => _tabIndex = 0),
              icon: Icon(
                Icons.fact_check_outlined,
                color: _tabIndex == 0 ? ImpostiColors.warning : Colors.white70,
                size: 18,
              ),
              label: Text(
                'ჩემი დავალებები',
                style: TextStyle(
                  color: _tabIndex == 0 ? Colors.white : Colors.white70,
                  fontWeight:
                      _tabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _tabIndex = 1),
              icon: Icon(
                Icons.calendar_month_outlined,
                color: _tabIndex == 1 ? ImpostiColors.warning : Colors.white70,
                size: 18,
              ),
              label: Text(
                'კალენდარი',
                style: TextStyle(
                  color: _tabIndex == 1 ? Colors.white : Colors.white70,
                  fontWeight:
                      _tabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
          const NotificationsBellButton(),
          IconButton(
            tooltip: 'გასვლა',
            onPressed: () => appState.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              currentIndex: _tabIndex,
              selectedItemColor: ImpostiColors.primary,
              onTap: (idx) => setState(() => _tabIndex = idx),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.fact_check_outlined),
                  label: 'ჩემი დავალებები',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'კალენდარი',
                ),
              ],
            ),
      body: _tabIndex == 1
          ? const CalendarScreen(embedded: true)
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header & Search
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isMobile = constraints.maxWidth < 550;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.fact_check,
                                        color: ImpostiColors.primary,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'ჩემი დავალებები',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ინსპექტორი: ${user?.displayName ?? ""}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: isMobile ? constraints.maxWidth : 320,
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText:
                                        'ძებნა (ობიექტი, დანადგარი, დავალება)...',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: (_searchCtrl.text.isNotEmpty ||
                                            _statusFilter.isNotEmpty)
                                        ? IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _searchCtrl.clear();
                                                _statusFilter = '';
                                              });
                                            },
                                            icon: const Icon(Icons.clear),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Stats Filter Cards (Responsive grid)
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final maxW = constraints.maxWidth;
                          final cols = maxW < 450 ? 2 : (maxW < 800 ? 3 : 5);
                          final cardW = (maxW - (cols - 1) * 10) / cols;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _filterCard(
                                'სულ',
                                _allTasks.length,
                                '',
                                Colors.black87,
                                cardW,
                              ),
                              _filterCard(
                                'მოლოდინში',
                                _pendingCount,
                                'pending',
                                ImpostiColors.secondary,
                                cardW,
                              ),
                              _filterCard(
                                'მიმდინარე',
                                _inProgressCount,
                                'in_progress',
                                ImpostiColors.warning,
                                cardW,
                              ),
                              _filterCard(
                                'უარყოფილი',
                                _rejectedCount,
                                'rejected',
                                ImpostiColors.danger,
                                cardW,
                              ),
                              _filterCard(
                                'დასრულებული',
                                _doneCount,
                                'done',
                                ImpostiColors.success,
                                cardW,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      if (_filteredTasks.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Center(
                              child: Text('დავალებები არ მოიძებნა'),
                            ),
                          ),
                        )
                      else
                        ..._filteredTasks.map((task) {
                          final headerColor =
                              (task.status == 'completed' ||
                                      task.status == 'approved')
                                  ? ImpostiColors.success
                                  : task.status == 'in_progress'
                                      ? ImpostiColors.warning
                                      : task.status == 'rejected'
                                          ? ImpostiColors.danger
                                          : ImpostiColors.secondary;
                          final isDarkText = task.status == 'in_progress';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    color: headerColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            task.scheduleName,
                                            style: TextStyle(
                                              color: isDarkText
                                                  ? Colors.black87
                                                  : Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            task.statusDisplay,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'კომპანია / ობიექტი: ${task.companyName} — ${task.siteName}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('დანადგარი: ${task.equipmentName}'),
                                        const SizedBox(height: 4),
                                        Text(
                                          'დაგეგმილი თარიღი: ${formatIsoDate(task.scheduledDate, withTime: true)}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 8,
                                          children: [
                                            if (task.status == 'pending' ||
                                                task.status == 'in_progress' ||
                                                task.status == 'rejected')
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      task.status == 'rejected'
                                                          ? ImpostiColors.danger
                                                          : ImpostiColors
                                                              .primary,
                                                ),
                                                onPressed: () async {
                                                  await Navigator.of(context)
                                                      .push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          TaskDetailScreen(
                                                        taskId: task.id,
                                                      ),
                                                    ),
                                                  );
                                                  _loadTasks();
                                                },
                                                icon: const Icon(
                                                  Icons.edit_note,
                                                  size: 18,
                                                ),
                                                label: Text(
                                                  task.status == 'rejected'
                                                      ? 'გამოსწორება'
                                                      : task.status ==
                                                              'in_progress'
                                                          ? 'გაგრძელება'
                                                          : 'შესრულება',
                                                ),
                                              )
                                            else ...[
                                              OutlinedButton.icon(
                                                onPressed: () async {
                                                  await Navigator.of(context)
                                                      .push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          TaskDetailScreen(
                                                        taskId: task.id,
                                                      ),
                                                    ),
                                                  );
                                                  _loadTasks();
                                                },
                                                icon: const Icon(
                                                  Icons.visibility_outlined,
                                                  size: 18,
                                                ),
                                                label: const Text('ნახვა'),
                                              ),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      ImpostiColors.danger,
                                                ),
                                                onPressed: () => openReportUrl(
                                                  context,
                                                  '/reports/task/${task.id}/pdf/',
                                                  downloadPdf: true,
                                                ),
                                                icon: const Icon(
                                                  Icons.picture_as_pdf,
                                                  size: 18,
                                                ),
                                                label: const Text('PDF აქტი'),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }

  Widget _filterCard(
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
            const SizedBox(height: 2),
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
