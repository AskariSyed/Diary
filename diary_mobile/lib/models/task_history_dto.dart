class TaskHistoryDto {
  final int pageTaskId;
  final int pageId;
  final DateTime pageDate;
  final String title;
  final String status;

  TaskHistoryDto({
    required this.pageTaskId,
    required this.pageId,
    required this.pageDate,
    required this.title,
    required this.status,
  });

  factory TaskHistoryDto.fromJson(Map<String, dynamic> json) {
    return TaskHistoryDto(
      pageTaskId: json['pageTaskId'],
      pageId: json['pageId'],
      pageDate: DateTime.parse(json['pageDate']),
      title: json['title'],
      status: json['status'],
    );
  }
}
