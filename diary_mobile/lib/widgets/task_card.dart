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
  Widget cardContent = Card(
    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
    child: ListTile(
      title: Text(task.title),
      subtitle: Text(
        task.parentTaskCreatedAt != null
            ? 'Created At: ${task.parentTaskCreatedAt!.toLocal().toString().split('.').first}'
            : 'Created At: Unknown',
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.blueGrey),
            tooltip: 'View Report',
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
            onPressed: () => _confirmDeleteTask(context, taskProvider, task),
          ),
        ],
      ),
      onTap: () => showEditTaskDialog(context, taskProvider, task),
    ),
  );
  return LongPressDraggable<TaskDto>(
    data: task,
    feedback: Material(
      elevation: 8.0,
      shadowColor: Colors.black.withOpacity(0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: Theme.of(context).primaryColor, width: 2.0),
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
    childWhenDragging: Opacity(opacity: 0.5, child: cardContent),
    child: cardContent,
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
