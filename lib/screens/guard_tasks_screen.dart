<<<<<<< HEAD
/// شاشة لعرض مهام الحارس مع إمكانية تحديث حالتها.
=======
>>>>>>> 405cf15 (توثيق الجهاز وتفعيل البصمه والتتبع للحارس)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/employee.dart';
import '../services/api.dart';

<<<<<<< HEAD
/// تعرض بطاقات المهام والعمليات المرتبطة بها.
=======
>>>>>>> 405cf15 (توثيق الجهاز وتفعيل البصمه والتتبع للحارس)
class GuardTasksScreen extends StatefulWidget {
  const GuardTasksScreen({super.key});

  @override
  State<GuardTasksScreen> createState() => _GuardTasksScreenState();
}

<<<<<<< HEAD
/// يدير تحميل المهام، التحديث، وإظهار الحوارات.
=======
>>>>>>> 405cf15 (توثيق الجهاز وتفعيل البصمه والتتبع للحارس)
class _GuardTasksScreenState extends State<GuardTasksScreen> {
  late Future<List<TaskMini>> _future;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TaskMini>> _load() async {
    final result = await ApiService.fetchGuardTasks();
    if (!result.ok) {
      throw Exception(result.message);
    }

    final data = result.data;
    final List<dynamic> rawList;
    if (data != null && data['results'] is List) {
      rawList = List<dynamic>.from(data['results'] as List);
    } else {
      rawList = const [];
    }

    return rawList
        .whereType<Map>()
        .map((e) => TaskMini.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _advanceTask(TaskMini task) async {
    if (!task.canAdvance) return;
    final t = AppLocalizations.of(context)!;
    final targetLabel = (task.nextStatusLabel != null && task.nextStatusLabel!.isNotEmpty)
        ? task.nextStatusLabel!
        : (task.nextStatus ?? '');

    final note = await _promptForNote(task: task, statusLabel: targetLabel);
    if (!mounted || note == null) return;

    setState(() => _updating = true);
    final result = await ApiService.updateGuardTask(
      taskId: task.id,
      status: task.nextStatus!,
      statusNote: note.trim().isEmpty ? null : note.trim(),
    );
    setState(() => _updating = false);

    if (!mounted) return;

    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.task_update_success)),
      );
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : t.task_update_failure)),
      );
    }
  }

  Future<String?> _promptForNote({required TaskMini task, required String statusLabel}) async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: task.statusNote ?? '');

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t.task_note_dialog_title(statusLabel)),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: t.task_status_note_label,
              hintText: t.task_note_hint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(t.task_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(t.task_confirm),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard(TaskMini task, AppLocalizations t, ThemeData theme) {
    final due = task.dueDateTime;
    final formatter = DateFormat.yMMMd().add_Hm();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  label: Text(
                    task.statusLabel.isNotEmpty ? task.statusLabel : task.status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondary,
                    ),
                  ),
                  backgroundColor: theme.colorScheme.secondary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (task.description.isNotEmpty)
              Text(
                task.description,
                style: theme.textTheme.bodyMedium,
              ),
            Text(
              '${t.task_location_label}: ${task.locationName}',
            ),
            if (due != null)
              Text(
                t.task_due_date(formatter.format(due.toLocal())),
              ),
            if (task.statusNote != null && task.statusNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${t.task_status_note_label}: ${task.statusNote}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            if (task.canAdvance)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: _updating ? null : () => _advanceTask(task),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    t.task_update_button((task.nextStatusLabel != null && task.nextStatusLabel!.isNotEmpty)
                        ? task.nextStatusLabel!
                        : (task.nextStatus ?? '')),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.tasks_screen_title)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<TaskMini>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.tasks_load_error,
                          style: theme.textTheme.titleMedium,
                        ),
                            const SizedBox(height: 8),
                            Text(snapshot.error.toString()),
                            const SizedBox(height: 12),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: FilledButton(
                                onPressed: _refresh,
                                child: Text(t.retry),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              final tasks = snapshot.data ?? const [];
              if (tasks.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Text(
                        t.task_no_items,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) =>
                    _buildTaskCard(tasks[index], t, theme),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: tasks.length,
              );
            },
          ),
        ),
      ),
    );
  }
}
