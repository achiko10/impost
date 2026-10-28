import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  TaskModel? _task;
  final _commentCtrl = TextEditingController();
  final List<PickedPhotoFile> _pickedPhotos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final task = await ApiService.getTask(widget.taskId);
      setState(() {
        _task = task;
        if (task.report != null && _commentCtrl.text.isEmpty) {
          _commentCtrl.text = task.report!.comment;
        }
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      for (final f in files) {
        final bytes = await f.readAsBytes();
        setState(() {
          _pickedPhotos.add(PickedPhotoFile(name: f.name, bytes: bytes));
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFromCamera() async {
    try {
      final f = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (f != null) {
        final bytes = await f.readAsBytes();
        setState(() {
          _pickedPhotos.add(PickedPhotoFile(name: f.name, bytes: bytes));
        });
      }
    } catch (_) {}
  }

  Future<void> _submitAction(String action) async {
    if (_commentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('გთხოვთ შეავსოთ კომენტარის ველი')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final updated = await ApiService.completeOrSaveTask(
        taskId: widget.taskId,
        comment: _commentCtrl.text.trim(),
        action: action,
        photos: _pickedPhotos,
      );
      setState(() {
        _task = updated;
        _pickedPhotos.clear();
      });
      if (!mounted) return;
      context.read<AppState>().refreshNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              action == 'save' ? ImpostiColors.primary : ImpostiColors.success,
          content: Text(
            action == 'save'
                ? 'სამუშაო პროგრესი შენახულია (სტატუსი: მიმდინარე).'
                : 'დავალება წარმატებით დასრულდა!',
          ),
        ),
      );
      if (action == 'complete') {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ImpostiColors.danger,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteUploadedPhoto(int photoId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ფოტოს წაშლა'),
        content: const Text('დარწმუნებული ხართ, რომ გსურთ ამ ფოტოს წაშლა?'),
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
    if (confirm != true) return;

    try {
      await ApiService.deleteTaskPhoto(
        taskId: widget.taskId,
        photoId: photoId,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ფოტო წაიშალა.')),
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

  Future<void> _approveTask() async {
    setState(() => _submitting = true);
    try {
      final updated = await ApiService.approveTask(widget.taskId);
      setState(() => _task = updated);
      if (mounted) {
        context.read<AppState>().refreshNotifications();
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openRejectModal() async {
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
                'დავალება: ${_task?.equipmentName} — ${_task?.scheduleName}',
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

    setState(() => _submitting = true);
    try {
      final updated = await ApiService.rejectTask(
        widget.taskId,
        reasonCtrl.text.trim(),
      );
      setState(() {
        _task = updated;
        if (updated.report != null) {
          _commentCtrl.text = updated.report!.comment;
        }
      });
      if (mounted) {
        context.read<AppState>().refreshNotifications();
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final task = _task;

    return Scaffold(
      appBar: AppBar(
        title: Text('დავალება #${widget.taskId}'),
        actions: [
          if (task != null &&
              (task.status == 'completed' || task.status == 'approved'))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ImpostiColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => openReportUrl(
                  context,
                  '/reports/task/${task.id}/pdf/',
                  downloadPdf: true,
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('PDF', style: TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('შეცდომა: $_error'))
              : task == null
                  ? const Center(child: Text('დავალება ვერ მოიძებნა'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Main Info Card
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  color: ImpostiColors.primary,
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.assignment_turned_in,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          task.scheduleName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
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
                                      LayoutBuilder(
                                        builder: (ctx, constraints) {
                                          final isMobile =
                                              constraints.maxWidth < 460;
                                          final itemW = isMobile
                                              ? (constraints.maxWidth - 16) / 2
                                              : 200.0;
                                          return Wrap(
                                            spacing: 16,
                                            runSpacing: 14,
                                            children: [
                                              _metaBlock(
                                                Icons.business,
                                                'კომპანია',
                                                task.companyName,
                                                itemW,
                                              ),
                                              _metaBlock(
                                                Icons.location_on_outlined,
                                                'ობიექტი',
                                                task.siteName,
                                                itemW,
                                              ),
                                              _metaBlock(
                                                Icons.settings_outlined,
                                                'დანადგარი',
                                                task.equipmentName,
                                                itemW,
                                              ),
                                              _metaBlock(
                                                Icons.person_outline,
                                                'ინსპექტორი',
                                                task.inspectorDisplay,
                                                itemW,
                                              ),
                                              _metaBlock(
                                                Icons.calendar_today_outlined,
                                                'დაგეგმილი',
                                                formatIsoDate(
                                                  task.scheduledDate,
                                                  withTime: true,
                                                ),
                                                itemW,
                                              ),
                                              if (task
                                                  .frequencyDisplay.isNotEmpty)
                                                _metaBlock(
                                                  Icons.repeat,
                                                  'სიხშირე',
                                                  task.frequencyDisplay,
                                                  itemW,
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                      const Divider(height: 28),
                                      Row(
                                        children: [
                                          const Text(
                                            'სტატუსი: ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusBadge(
                                            status: task.status,
                                            label: task.statusDisplay,
                                          ),
                                        ],
                                      ),
                                      if (task.status == 'rejected') ...[
                                        const SizedBox(height: 14),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: ImpostiColors.danger
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: ImpostiColors.danger
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(
                                                Icons.warning_amber_rounded,
                                                color: ImpostiColors.danger,
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'ეს დავალება უარყოფილია კლიენტის მიერ. გთხოვთ გაასწოროთ ხარვეზი, განაახლოთ კომენტარი/ფოტოები და ხელახლა დაასრულოთ.',
                                                  style: TextStyle(
                                                    color: ImpostiColors.danger,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Client / Manager Approve or Reject Controls when completed
                          if (task.status == 'completed' &&
                              (user?.role == 'client' ||
                                  user?.role == 'manager')) ...[
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'სერვისის ჩაბარება / დადასტურება',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  ImpostiColors.success,
                                            ),
                                            onPressed: _submitting
                                                ? null
                                                : _approveTask,
                                            icon: const Icon(Icons.check),
                                            label: const Text('დადასტურება'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  ImpostiColors.danger,
                                            ),
                                            onPressed: _submitting
                                                ? null
                                                : _openRejectModal,
                                            icon: const Icon(Icons.close),
                                            label: const Text('უარყოფა'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Inspector Execution Form
                          if (user?.role == 'inspector' &&
                              (task.status == 'pending' ||
                                  task.status == 'in_progress' ||
                                  task.status == 'rejected')) ...[
                            const SizedBox(height: 16),
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    color: ImpostiColors.success,
                                    padding: const EdgeInsets.all(14),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'შესრულება',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
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
                                        const Text(
                                          'კომენტარი *',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: _commentCtrl,
                                          maxLines: 4,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'აღწერეთ შესრულებული სამუშაო...',
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'ფოტოები',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: _pickFromGallery,
                                              icon: const Icon(
                                                Icons.photo_library_outlined,
                                              ),
                                              label: const Text(
                                                'ფაილის არჩევა / გალერეა',
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: _pickFromCamera,
                                              icon: const Icon(
                                                Icons.camera_alt_outlined,
                                              ),
                                              label: const Text('კამერა'),
                                            ),
                                          ],
                                        ),
                                        if (_pickedPhotos.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: List.generate(
                                              _pickedPhotos.length,
                                              (idx) {
                                                final p = _pickedPhotos[idx];
                                                return Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        8,
                                                      ),
                                                      child: Image.memory(
                                                        Uint8List.fromList(
                                                          p.bytes,
                                                        ),
                                                        width: 90,
                                                        height: 90,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: -6,
                                                      right: -6,
                                                      child: InkWell(
                                                        onTap: () {
                                                          setState(() {
                                                            _pickedPhotos
                                                                .removeAt(idx);
                                                          });
                                                        },
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(3),
                                                          decoration:
                                                              const BoxDecoration(
                                                            color: ImpostiColors
                                                                .danger,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                          child: const Icon(
                                                            Icons.close,
                                                            color: Colors.white,
                                                            size: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 20),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: _submitting
                                                  ? null
                                                  : () => _submitAction('save'),
                                              icon: const Icon(
                                                Icons.save_outlined,
                                              ),
                                              label: const Text(
                                                'შენახვა (გაგრძელება)',
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    ImpostiColors.success,
                                              ),
                                              onPressed: _submitting
                                                  ? null
                                                  : () =>
                                                      _submitAction('complete'),
                                              icon: const Icon(Icons.check),
                                              label: const Text('დასრულება'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Existing Report & Photos Card
                          if (task.report != null) ...[
                            const SizedBox(height: 16),
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    color: ImpostiColors.info,
                                    padding: const EdgeInsets.all(14),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.description_outlined,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'რეპორტი',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
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
                                        const Text(
                                          'კომენტარი:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8F9FA),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(task.report!.comment),
                                        ),
                                        if (task.report!.photos.isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          Text(
                                            'ფოტოები (${task.report!.photos.length}):',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: task.report!.photos.map((
                                              photo,
                                            ) {
                                              final imgUrl =
                                                  ApiService.resolveMediaUrl(
                                                    photo.imageUrl,
                                                  );
                                              final canDelete =
                                                  task.status != 'approved' &&
                                                  (user?.role == 'inspector' ||
                                                      user?.role == 'manager');
                                              return Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  InkWell(
                                                    onTap: () =>
                                                        showPhotoLightbox(
                                                          context,
                                                          photo.imageUrl,
                                                        ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        8,
                                                      ),
                                                      child: Image.network(
                                                        imgUrl,
                                                        width: 110,
                                                        height: 110,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (_, _, _) =>
                                                                Container(
                                                          width: 110,
                                                          height: 110,
                                                          color: Colors.black12,
                                                          child: const Icon(
                                                            Icons.broken_image,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (canDelete)
                                                    Positioned(
                                                      top: 4,
                                                      right: 4,
                                                      child: InkWell(
                                                        onTap: () =>
                                                            _deleteUploadedPhoto(
                                                              photo.id,
                                                            ),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(4),
                                                          decoration:
                                                              const BoxDecoration(
                                                            color: ImpostiColors
                                                                .danger,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                          child: const Icon(
                                                            Icons.close,
                                                            color: Colors.white,
                                                            size: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Text(
                                          'შექმნილია: ${formatIsoDate(task.report!.createdAt, withTime: true)}',
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
                            ),
                          ],

                          // History Card
                          const SizedBox(height: 16),
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  color: ImpostiColors.secondary,
                                  padding: const EdgeInsets.all(12),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.history,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'ისტორია',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'შექმნილია: ${formatIsoDate(task.createdAt, withTime: true)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      if (task.completedDate != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'დასრულდა: ${formatIsoDate(task.completedDate, withTime: true)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: ImpostiColors.success,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
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

  Widget _metaBlock(IconData icon, String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ImpostiColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
