class CreatePageDto {
  final int diaryNo;
  final DateTime pageDate;

  CreatePageDto({
    required this.diaryNo,
    required this.pageDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'diaryNo': diaryNo,
      'pageDate': pageDate.toIso8601String(),
    };
  }
}