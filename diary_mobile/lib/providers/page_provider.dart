import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:diary_mobile/providers/paget_dto.dart';

class PageProvider with ChangeNotifier {
  final String _baseUrl = 'http://192.168.137.1:5158/api/Pages';

  List<PageDto> _pages = [];
  bool _isLoading = false;
  String? _errorMessage;
  PageProvider() {
    fetchPagesByDiary(1);
  }
  List<PageDto> get pages => _pages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPagesByDiary(int diaryId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/by-diary/$diaryId');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        _pages = data.map((json) {
          final page = PageDto.fromJson(json);

          return page;
        }).toList();

        if (_pages.isEmpty) {
          if (kDebugMode) {
            print('[DEBUG] No pages received.');
          }
        }
      } else {
        _errorMessage = 'Failed to load pages: ${response.statusCode}';
        if (kDebugMode) {
          print('[ERROR] $_errorMessage');
        }
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      if (kDebugMode) {
        print('[EXCEPTION] $_errorMessage');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DateTime? getPageDateById(int pageId) {
    try {
      final page = _pages.firstWhere(
        (p) => p.pageId == pageId,
        orElse: () {
          return PageDto(pageId: -1, diaryNo: -1, pageDate: DateTime.now());
        },
      );

      if (page.pageId == -1) {
        return null;
      }

      return page.pageDate;
    } catch (e) {
      return null;
    }
  }

  void printAllPageIdsWithDates() {
    if (_pages.isEmpty) {
      return;
    }
    for (final page in _pages) {
      if (kDebugMode) {
        print('Page ID: ${page.pageId}, Date: ${page.pageDate}');
      }
    }
  }
}
