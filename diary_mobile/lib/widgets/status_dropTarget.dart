import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:flutter/material.dart';

Widget buildStatusDropTarget(
  BuildContext context,
  TaskStatus status,
  TaskProvider taskProvider,
  Brightness currentBrightness,
) {
  return DragTarget<TaskDto>(
    onWillAcceptWithDetails: (data) {
      return data.data.status != status;
    },
    onAcceptWithDetails: (details) async {
      final draggedTask = details.data;
      try {
        final response = await taskProvider.updateTaskStatusForTodayPage(
          draggedTask.id,
          status,
        );

        final message = response?['message'] ?? 'Task status updated.';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task status: $e')),
        );
      }
    },
    builder: (context, candidateData, rejectedData) {
      final bool isHovering = candidateData.isNotEmpty;
      return Container(
        width: 60,
        height: 80,
        decoration: BoxDecoration(
          color: isHovering
              ? getStatusColor(status, currentBrightness).withOpacity(0.7)
              : getStatusColor(status, currentBrightness).withOpacity(0.4),
          borderRadius: BorderRadius.circular(15.0),
          border: Border.all(
            color: isHovering
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              getStatusIcon(status),
              color: isHovering
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
            Text(
              status.toApiString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isHovering
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    },
  );
}

Color getStatusColor(TaskStatus status, Brightness brightness) {
  final baseColors = {
    TaskStatus.backlog: Colors.blueGrey,
    TaskStatus.toDiscuss: Colors.amber,
    TaskStatus.inProgress: Colors.deepPurple,
    TaskStatus.onHold: Colors.red,
    TaskStatus.complete: Colors.green,
    TaskStatus.toFollowUp: Colors.teal,
  };

  final baseColor = baseColors[status] ?? Colors.grey;
  return baseColor;
}

IconData getStatusIcon(TaskStatus status) {
  switch (status) {
    case TaskStatus.backlog:
      return Icons.assignment;
    case TaskStatus.toDiscuss:
      return Icons.chat;
    case TaskStatus.inProgress:
      return Icons.work;
    case TaskStatus.onHold:
      return Icons.pause_circle_filled;
    case TaskStatus.complete:
      return Icons.check_circle;
    case TaskStatus.toFollowUp:
      return Icons.follow_the_signs;
    case TaskStatus.deleted:
      return Icons.delete;
    default:
      return Icons.help_outline;
  }
}
