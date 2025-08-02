import 'package:diary_mobile/widgets/status_dropTarget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
import '../models/task_history_dto.dart';
import '../providers/task_provider.dart';
import 'package:diary_mobile/mixin/taskstatus.dart'; // Import the file containing getStatusIcon and getStatusColor

class TaskHistoryDialog extends StatefulWidget {
  final int taskId;

  const TaskHistoryDialog({super.key, required this.taskId});

  @override
  State<TaskHistoryDialog> createState() => _TaskHistoryDialogState();
}

class _TaskHistoryDialogState extends State<TaskHistoryDialog> {
  late Future<List<TaskHistoryDto>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = Provider.of<TaskProvider>(
      context,
      listen: false,
    ).getTaskHistoryByPageTaskId(widget.taskId);
  }

  @override
  Widget build(BuildContext context) {
    // Get the current theme brightness to determine appropriate status colors
    final Brightness currentBrightness = Theme.of(context).brightness;

    return AlertDialog(
      title: const Text("Task History"),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<TaskHistoryDto>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Text("Error: ${snapshot.error}");
            } else if (snapshot.hasData && snapshot.data!.isEmpty) {
              return const Text("No history available for this task.");
            } else {
              final history = snapshot.data!;
              // Get the parent task's creation date from the first history item.
              // It's assumed to be the same for all entries of a single parent task.
              final DateTime? parentTaskCreationDate = history.isNotEmpty
                  ? history.first.parentTaskCreatedAt
                  : null;

              final String formattedParentTaskCreationDate =
                  parentTaskCreationDate != null
                  ? DateFormat('yyyy-MM-dd').format(
                      parentTaskCreationDate,
                    ) // Format including time for creation date
                  : 'N/A'; // Fallback if the date is null

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display the original task creation date at the top of the dialog
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "Creation Date: $formattedParentTaskCreationDate",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(), // A visual separator
                  Flexible(
                    // Allows the ListView to take available space
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        // Format the page date
                        final String formattedPageDate = DateFormat(
                          'yyyy-MM-dd',
                        ).format(item.pageDate);

                        // Convert status string to TaskStatus enum for styling functions
                        final TaskStatus taskStatusEnum = item.status
                            .fromApiString();
                        final Color statusColor = getStatusColor(
                          taskStatusEnum,
                          currentBrightness,
                        );
                        final IconData statusIcon = getStatusIcon(
                          taskStatusEnum,
                        );

                        return Card(
                          // Use Card for a visually distinct item
                          margin: const EdgeInsets.symmetric(
                            vertical: 4.0,
                            horizontal: 0,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: Icon(
                              statusIcon,
                              color:
                                  statusColor, // Apply status-specific color to the icon
                              size: 30,
                            ),
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ), // Make title bold
                            ),
                            subtitle: Column(
                              // Use Column for vertical arrangement within subtitle
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Use Text.rich to apply color and bold to only the status text
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(text: "Status: "),
                                      TextSpan(
                                        text: item.status,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              statusColor, // Apply status-specific color to the status text
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "Page Date: $formattedPageDate",
                                ), // Display page date
                              ],
                            ),
                            isThreeLine:
                                false, // Adjusted as subtitle now fits neatly on two lines
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
