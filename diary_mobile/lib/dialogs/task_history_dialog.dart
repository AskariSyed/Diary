import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_history_dto.dart';
import '../providers/task_provider.dart';

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
              return ListView.builder(
                shrinkWrap: true,
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  final formattedDate =
                      "${item.pageDate.year}-${item.pageDate.month.toString().padLeft(2, '0')}-${item.pageDate.day.toString().padLeft(2, '0')}";
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(item.title),
                    subtitle: Text(
                      "Status: ${item.status}\n"
                      "Page ID: ${item.pageId}\n"
                      "Date: $formattedDate",
                    ),
                    isThreeLine: true,
                  );
                },
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
