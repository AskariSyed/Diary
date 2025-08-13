import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

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
      final overlay = Overlay.of(context);
      try {
        await taskProvider.updateTaskStatus(draggedTask.id, status);
        showTopSnackBar(
          overlay,
          CustomSnackBar.success(message: 'Status updated'),
          displayDuration: Durations.short1,
        );
      } catch (e) {
        showTopSnackBar(
          overlay,
          CustomSnackBar.error(message: 'Failed to update task status: $e'),
          displayDuration: const Duration(seconds: 2),
        );
      }
    },
    builder: (context, candidateData, rejectedData) {
      final bool isHovering = candidateData.isNotEmpty;
      return Container(
        width: 60,
        height: 60,
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
  final lightColors = {
    TaskStatus.backlog: const Color.fromARGB(255, 225, 225, 221),
    TaskStatus.toDiscuss: const Color.fromARGB(255, 229, 219, 201),
    TaskStatus.inProgress: const Color.fromARGB(255, 154, 194, 213),
    TaskStatus.onHold: const Color.fromARGB(255, 213, 158, 148),
    TaskStatus.complete: const Color.fromARGB(255, 173, 202, 174),
    TaskStatus.toFollowUp: const Color.fromARGB(255, 180, 204, 195),
    TaskStatus.deleted: const Color.fromARGB(255, 251, 0, 0),
  };

  final darkColors = {
    TaskStatus.backlog: const Color.fromARGB(255, 165, 105, 162),
    TaskStatus.toDiscuss: const Color.fromARGB(182, 99, 83, 53),
    TaskStatus.inProgress: const Color.fromARGB(255, 117, 173, 199),
    TaskStatus.onHold: const Color.fromARGB(255, 213, 158, 148),
    TaskStatus.complete: const Color.fromARGB(255, 65, 103, 66),
    TaskStatus.toFollowUp: const Color.fromARGB(255, 89, 152, 128),
    TaskStatus.deleted: const Color.fromARGB(255, 251, 0, 0),
  };

  final isDark = brightness == Brightness.dark;
  final baseColors = isDark ? darkColors : lightColors;

  return baseColors[status] ?? (isDark ? Colors.grey[300]! : Colors.grey[700]!);
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
  }
}
