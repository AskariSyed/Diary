import '/mixin/taskstatus.dart';

class TaskDto {
  final int id;
  final int pageId;
  final int? parentTaskId;
  final String title;
  final TaskStatus status;
  final DateTime? pageDate;
  final DateTime? parentTaskCreatedAt;

  TaskDto({
    required this.id,
    required this.pageId,
    this.parentTaskId,
    required this.title,
    required this.status,
    this.pageDate,
    this.parentTaskCreatedAt,
  });

  factory TaskDto.fromJson(Map<String, dynamic> json) {
    return TaskDto(
      id: json['id'] as int,
      pageId: json['pageId'] as int,
      parentTaskId: json['parentTaskId'] as int?,
      title: json['title'] as String,
      status: (json['status'] as String).fromApiString(),
      pageDate: json['pageDate'] != null
          ? DateTime.tryParse(json['pageDate'])
          : null,
      parentTaskCreatedAt: json['parentTaskCreatedAt'] != null
          ? DateTime.tryParse(json['parentTaskCreatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pageId': pageId,
      'parentTaskId': parentTaskId,
      'title': title,
      'status': status.toApiString(),
      'pageDate': pageDate?.toIso8601String(),
      'parentTaskCreatedAt': parentTaskCreatedAt?.toIso8601String(),
    };
  }

  TaskDto copyWith({
    int? id,
    int? pageId,
    int? parentTaskId,
    String? title,
    TaskStatus? status,
    DateTime? pageDate,
    DateTime? parentTaskCreatedAt,
  }) {
    return TaskDto(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      status: status ?? this.status,
      pageDate: pageDate ?? this.pageDate,
      parentTaskCreatedAt: parentTaskCreatedAt ?? this.parentTaskCreatedAt,
    );
  }
}
