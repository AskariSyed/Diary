enum TaskStatus { backlog, inProgress, toDiscuss, toFollowUp, onHold, complete }

extension TaskStatusExtension on TaskStatus {
  String toApiString() {
    switch (this) {
      case TaskStatus.backlog:
        return 'backlog';
      case TaskStatus.toDiscuss:
        return 'To Discuss';
      case TaskStatus.inProgress:
        return 'in process';
      case TaskStatus.onHold:
        return 'on hold';
      case TaskStatus.toFollowUp:
        return 'To follow up';
      case TaskStatus.complete:
        return 'completed';
    }
  }

  // A static method to create from a string
  static TaskStatus fromApiString(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'backlog':
        return TaskStatus.backlog;
      case 'to discuss':
        return TaskStatus.toDiscuss;
      case 'in process':
        return TaskStatus.inProgress;
      case 'on hold':
        return TaskStatus.onHold;
      case 'to follow up':
        return TaskStatus.toFollowUp;
      case 'completed':
        return TaskStatus.complete;

      default:
        print(
          'Warning: Unknown TaskStatus string received from API: $statusString. Defaulting to backlog.',
        );
        // Optionally, return a default like TaskStatus.backlog if you don't want to crash
        return TaskStatus
            .backlog; // Or throw ArgumentError('Unknown TaskStatus string: $statusString');
    }
  }
}

// Add a convenience method to String to use fromApiString
extension StringToTaskStatusExtension on String {
  TaskStatus fromApiString() {
    return TaskStatusExtension.fromApiString(this);
  }
}
