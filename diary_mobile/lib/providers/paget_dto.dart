import 'package:flutter/foundation.dart';

class PageDto {
  final int pageId;
  final int diaryNo;
  final DateTime pageDate;

  PageDto({
    required this.pageId,
    required this.diaryNo,
    required this.pageDate,
  });
  factory PageDto.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('Parsing page JSON: $json');
    }
    return PageDto(
      pageId: json['pageId'],
      diaryNo: json['diaryNo'],
      pageDate: DateTime.parse(json['pageDate']),
    );
  }
}
