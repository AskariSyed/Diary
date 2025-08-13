import 'package:diary_mobile/widgets/status_drop_target.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task_history_dto.dart';
import '../providers/task_provider.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';

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
              final DateTime? parentTaskCreationDate = history.isNotEmpty
                  ? history.first.parentTaskCreatedAt
                  : null;

              final String formattedParentTaskCreationDate =
                  parentTaskCreationDate != null
                  ? DateFormat('yyyy-MM-dd').format(parentTaskCreationDate)
                  : 'N/A';

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "Creation Date: $formattedParentTaskCreationDate",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        // Format the page date
                        final String formattedPageDate = DateFormat(
                          'yyyy-MM-dd',
                        ).format(item.pageDate);
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
                              color: statusColor,
                              size: 30,
                            ),
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ), // Make title bold
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(text: "Status: "),
                                      TextSpan(
                                        text: item.status,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text("Page Date: $formattedPageDate"),
                              ],
                            ),
                            isThreeLine: false,
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
