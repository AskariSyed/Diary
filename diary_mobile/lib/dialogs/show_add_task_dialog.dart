import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

void showAddTaskDialog(BuildContext context) {
  final TextEditingController taskTitleController = TextEditingController();
  DateTime? selectedDate;

  showDialog(
    context: context,
    builder: (dialogContext) {
      final navigator = Navigator.of(dialogContext);
      final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add New Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: taskTitleController,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );

                    if (picked != null) {
                      final today = DateTime.now();
                      final pickedDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                      );
                      final currentDate = DateTime(
                        today.year,
                        today.month,
                        today.day,
                      );

                      if (pickedDate.isBefore(currentDate)) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cannot select a past date. Please pick today or a future date.',
                            ),
                          ),
                        );
                      } else {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    }
                  },
                  child: Text(
                    selectedDate == null
                        ? 'Pick Task Date'
                        : 'Date: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => navigator.pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (taskTitleController.text.isEmpty) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Task title cannot be empty.'),
                      ),
                    );
                    return;
                  }

                  if (selectedDate == null) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Please pick a date first.'),
                      ),
                    );
                    return;
                  }

                  // Check again here to prevent older date submission
                  final today = DateTime.now();
                  final pickedDate = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                  );
                  final currentDate = DateTime(
                    today.year,
                    today.month,
                    today.day,
                  );

                  if (pickedDate.isBefore(currentDate)) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Cannot add task for past dates.'),
                      ),
                    );
                    return;
                  }

                  try {
                    final taskProvider = Provider.of<TaskProvider>(
                      dialogContext,
                      listen: false,
                    );

                    int? pageId = await taskProvider.getPagebyDate(
                      1,
                      selectedDate!,
                    );
                    if (pageId == null) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('No page found for this date.'),
                        ),
                      );
                      return;
                    }

                    await taskProvider.addTask(
                      taskTitleController.text,
                      TaskStatus.backlog,
                      pageId: pageId,
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
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
}
