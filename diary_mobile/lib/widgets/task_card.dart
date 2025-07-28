import 'package:diary_mobile/dialogs/show_edit_task_dialog.dart';
import 'package:diary_mobile/dialogs/task_history_dialog.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:flutter/material.dart';

Widget buildTaskCard(
  TaskDto task,
  TaskProvider taskProvider,
  bool isDraggableAndEditable,
  BuildContext context,
) {
  return Card(
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
          subtitle: Text(
            task.parentTaskCreatedAt != null
                ? 'Created At: ${task.parentTaskCreatedAt!.toLocal().toString().split('.').first}'
                : 'Created At: Unknown',
            style: const TextStyle(color: Colors.grey),
          ),

          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDeleteTask(context, taskProvider, task),
          ),
          onTap: () => showEditTaskDialog(context, taskProvider, task),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => TaskHistoryDialog(taskId: task.id),
              );
            },
            icon: const Icon(Icons.history),
            label: const Text('Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ),
      ],
    ),
  );
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
                    const SnackBar(content: Text('Task deleted successfully!')),
                  ),
                );
                Navigator.pop(context);
              } catch (e) {
                Future.microtask(
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete task: $e')),
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
