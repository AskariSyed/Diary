// lib/screens/tabs/status_tasks_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:diary_mobile/dialogs/show_edit_task_dialog.dart';
import 'package:diary_mobile/dialogs/task_history_dialog.dart';
import 'package:intl/intl.dart';

class StatusTasksView extends StatefulWidget {
  final List<TaskDto> tasksToShow;
  final Map<int, List<TaskDto>> tasksByPage;
  final List<int> sortedPageIds;
  final GlobalKey Function(String viewPrefix, int pageId) getPageGlobalKey;

  final Map<String, bool> statusExpandedState;
  final Brightness currentBrightness;
  final String Function(DateTime?) formatDate;
  final Color Function(TaskStatus, Brightness) getStatusColor;
  final Function(int, TaskStatus) scrollToPageAndStatus;
  final ScrollController scrollController;
  final int? pageToScrollTo;
  final TaskStatus? statusToExpand;
  final TaskStatus filterStatus;
  final VoidCallback? onScrollComplete;
  final Map<String, dynamic> expansionTileControllers;
  // New callbacks for drag and drop
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  const StatusTasksView({
    super.key,
    required this.tasksToShow,
    required this.tasksByPage,
    required this.sortedPageIds,
    required this.getPageGlobalKey,
    required this.statusExpandedState,
    required this.currentBrightness,
    required this.formatDate,
    required this.getStatusColor,
    required this.scrollToPageAndStatus,
    required this.scrollController,
    this.pageToScrollTo,
    this.statusToExpand,
    required this.filterStatus,
    this.onScrollComplete,
    required this.expansionTileControllers,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  @override
  State<StatusTasksView> createState() => _StatusTasksViewState();
}

class _StatusTasksViewState extends State<StatusTasksView> {
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown Date';
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  void _confirmDeleteTask(
    BuildContext context,
    TaskProvider taskProvider,
    TaskDto task,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: Text(
            'Are you sure you want to delete "${task.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await taskProvider.updateTask(
                    task.id,
                    task.title,
                    TaskStatus.deleted,
                  );
                  Future.microtask(
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Task deleted successfully!'),
                      ),
                    ),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  Future.microtask(
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update task status: $e'),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    final Map<int, TaskDto> mostRecentTasksMap = {};
    for (var task in widget.tasksToShow) {
      if (task.status == widget.filterStatus) {
        final int key = task.parentTaskId ?? task.id;
        if (mostRecentTasksMap.containsKey(key)) {
          final existingTask = mostRecentTasksMap[key]!;
          if (task.pageDate != null &&
              (existingTask.pageDate == null ||
                  task.pageDate!.isAfter(existingTask.pageDate!))) {
            mostRecentTasksMap[key] = task;
          }
        } else {
          mostRecentTasksMap[key] = task;
        }
      }
    }

    final List<TaskDto> filteredTasksForTab = mostRecentTasksMap.values.toList()
      ..sort(
        (a, b) => b.parentTaskCreatedAt!.compareTo(a.parentTaskCreatedAt!),
      );

    if (filteredTasksForTab.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks in "${widget.filterStatus.toApiString()}" status.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: filteredTasksForTab.length,
      itemBuilder: (context, index) {
        final task = filteredTasksForTab[index];
        return LongPressDraggable<TaskDto>(
          data: task,
          feedback: Material(
            elevation: 8.0,
            shadowColor: Colors.black.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 2.0,
                ),
              ),
              child: Text(
                task.title,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 1.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(task.title, style: TextStyle()),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.parentTaskCreatedAt != null
                              ? 'Created At: ${_formatDate(task.parentTaskCreatedAt)}'
                              : 'Created At: Unknown',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        if (task.pageDate != null)
                          Text(
                            'Page Date: ${_formatDate(task.pageDate)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.history),
                          tooltip: 'View History',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) =>
                                  TaskHistoryDialog(taskId: task.id),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete Task',
                          onPressed: () =>
                              _confirmDeleteTask(context, taskProvider, task),
                        ),
                      ],
                    ),
                    onTap: () =>
                        showEditTaskDialog(context, taskProvider, task),
                  ),
                ],
              ),
            ),
          ),
          onDragStarted: () {
            widget.onDragStarted(); // Notify parent that dragging has started
          },
          onDragEnd: (details) {
            widget.onDragEnded(); // Notify parent that dragging has ended
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.status == TaskStatus.complete
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.parentTaskCreatedAt != null
                            ? 'Created At: ${_formatDate(task.parentTaskCreatedAt)}'
                            : 'Created At: Unknown',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      if (task.pageDate != null)
                        Text(
                          'Page Date: ${_formatDate(task.pageDate)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history),
                        tooltip: 'View History',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => TaskHistoryDialog(taskId: task.id),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete Task',
                        onPressed: () =>
                            _confirmDeleteTask(context, taskProvider, task),
                      ),
                    ],
                  ),
                  onTap: () => showEditTaskDialog(context, taskProvider, task),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
