import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:diary_mobile/providers/pagetDto.dart';

class PageProvider with ChangeNotifier {
  final String _baseUrl = 'http://192.168.137.1:5158/api/Pages';

  List<PageDto> _pages = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PageDto> get pages => _pages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPagesByDiary(int diaryId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/by-diary/$diaryId');
      print('[DEBUG] Fetching pages from: $url');

      final response = await http.get(url);

      print('[DEBUG] Response status: ${response.statusCode}');
      print('[DEBUG] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        _pages = data.map((json) {
          final page = PageDto.fromJson(json);
          print(
            '[DEBUG] Mapped PageDto: id=${page.pageId}, date=${page.pageDate}',
          );
          return page;
        }).toList();

        if (_pages.isEmpty) {
          print('[DEBUG] No pages received.');
        }
      } else {
        _errorMessage = 'Failed to load pages: ${response.statusCode}';
        print('[ERROR] $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      print('[EXCEPTION] $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DateTime? getPageDateById(int pageId) {
    print('[DEBUG] Looking for page with ID: $pageId');

    try {
      final page = _pages.firstWhere(
        (p) => p.pageId == pageId,
        orElse: () {
          print('[WARNING] No page found with ID: $pageId');
          return PageDto(pageId: -1, diaryNo: -1, pageDate: DateTime.now());
        },
      );

      if (page.pageId == -1) {
        return null;
      }

      print(
        '[DEBUG] Found page with ID: ${page.pageId}, Date: ${page.pageDate}',
      );
      return page.pageDate;
    } catch (e) {
      print('[EXCEPTION] Error finding page by ID: $e');
      return null;
    }
  }

  void printAllPageIdsWithDates() {
    if (_pages.isEmpty) {
      print('[INFO] No pages available to print.');
      return;
    }

    print('[INFO] Printing all page IDs with their dates:');
    for (final page in _pages) {
      print('Page ID: ${page.pageId}, Date: ${page.pageDate}');
    }
  }
}
