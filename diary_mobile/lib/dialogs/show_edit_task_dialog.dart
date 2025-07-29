import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:flutter/material.dart';

void showEditTaskDialog(
  BuildContext context,
  TaskProvider taskProvider,
  TaskDto task,
) {
  final TextEditingController taskTitleController = TextEditingController(
    text: task.title,
  );

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Edit Task Title'),
        content: TextField(
          controller: taskTitleController,
          decoration: const InputDecoration(labelText: 'Task Title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (taskTitleController.text.isNotEmpty) {
                try {
                  await taskProvider.updateTask(
                    task.id,
                    taskTitleController.text,
                    task.status,
                  );
                  Future.microtask(
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Task title updated successfully!'),
                      ),
                    ),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  Future.microtask(
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update task title: $e'),
                      ),
                    ),
                  );
                }
              } else {
                Future.microtask(
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task title cannot be empty.'),
                    ),
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      );
    },
  );
}
