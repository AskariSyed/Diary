import '/mixin/taskstatus.dart';

class Task {
  final String id;
  final String title;
  TaskStatus status;

  Task({required this.id, required this.title, required this.status});
}
