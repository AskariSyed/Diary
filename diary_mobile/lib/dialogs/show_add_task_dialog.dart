import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void showAddTaskDialog(BuildContext context, int targetPageId) {
  final TextEditingController taskTitleController = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) {
      final navigator = Navigator.of(dialogContext);
      final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);

      return AlertDialog(
        title: const Text('Add New Task'),
        content: TextField(
          controller: taskTitleController,
          decoration: InputDecoration(
            labelText: 'Task Title',
            hintText: 'Add to Page $targetPageId',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (taskTitleController.text.isNotEmpty) {
                try {
                  await Provider.of<TaskProvider>(
                    dialogContext,
                    listen: false,
                  ).addTask(
                    taskTitleController.text,
                    TaskStatus.backlog,
                    pageId: targetPageId,
                  );

                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Task added successfully!')),
                  );
                  navigator.pop();
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to add task: $e')),
                  );
                }
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Task title cannot be empty.')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
}
