import 'dart:math';

import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

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
                    () => showTopSnackBar(
                      Overlay.of(context),
                      const CustomSnackBar.success(
                        message: 'Task title updated Successfully',
                      ),
                      displayDuration: Durations.short1,
                    ),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  Future.microtask(
                    () => showTopSnackBar(
                      Overlay.of(context),
                      CustomSnackBar.error(
                        message: 'Failed to update task title: $e',
                      ),
                      displayDuration: Durations.short1,
                    ),
                  );
                }
              } else {
                Future.microtask(
                  () => showTopSnackBar(
                    Overlay.of(context),
                    CustomSnackBar.info(message: 'Task title cannot be empty.'),
                    displayDuration: Durations.short1,
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
