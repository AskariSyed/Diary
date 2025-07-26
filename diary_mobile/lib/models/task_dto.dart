import '/mixin/taskstatus.dart';

class TaskDto {
  final int id;
  final int pageId;
  final int? parentTaskId; // Nullable as per typical API designs
  final String title;
  final TaskStatus status;

  TaskDto({
    required this.id,
    required this.pageId,
    this.parentTaskId,
    required this.title,
    required this.status,
  });

  factory TaskDto.fromJson(Map<String, dynamic> json) {
    return TaskDto(
      id: json['id'] as int,
      pageId: json['pageId'] as int,
      parentTaskId: json['parentTaskId'] as int?,
      title: json['title'] as String,
      status: (json['status'] as String).fromApiString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pageId': pageId,
      'parentTaskId': parentTaskId,
      'title': title,
      'status': status.toApiString(),
    };
  }

  TaskDto copyWith({
    int? id,
    int? pageId,
    int? parentTaskId,
    String? title,
    TaskStatus? status,
  }) {
    return TaskDto(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      status: status ?? this.status,
    );
  }
}
