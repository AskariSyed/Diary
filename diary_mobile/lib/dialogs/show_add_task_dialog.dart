import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

void showAddTaskDialog(BuildContext context) {
  final TextEditingController taskTitleController = TextEditingController();
  DateTime selectedDate = DateTime.now();

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
                const SizedBox(height: 20),

                // --- Improved Date Picker UI ---
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate:
                          selectedDate, // Start with the current selection
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );

                    if (picked != null && picked != selectedDate) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('MMMM d, yyyy').format(selectedDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
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
                  if (taskTitleController.text.trim().isEmpty) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Task title cannot be empty.'),
                      ),
                    );
                    return;
                  }

                  if (taskTitleController.text.length > 255) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Task title cannot exceed 255 characters.',
                        ),
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
                      1, // Assuming diaryId is 1
                      selectedDate,
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
                      taskTitleController.text.trim(),
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
