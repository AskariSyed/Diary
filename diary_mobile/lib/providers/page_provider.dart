import 'dart:convert';
import 'package:diary_mobile/models/note_dto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:diary_mobile/providers/paget_dto.dart';

class PageProvider with ChangeNotifier {
  final String _baseUrl = 'http://192.168.137.1:5158/api/Pages';

  List<PageDto> _pages = [];
  bool _isLoading = false;
  NoteDto? _note;
  String? _errorMessage;
  PageProvider() {
    fetchPagesByDiary(1);
  }
  List<PageDto> get pages => _pages;
  bool get isLoading => _isLoading;
  NoteDto? get note => _note;
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

  Future<void> fetchNoteByDiary(int diaryId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (kDebugMode) {
      print('DEBUG: Starting fetch for note on diary ID: $diaryId');
    }

    try {
      final url = Uri.parse('http://localhost:5158/api/diaries/$diaryId/note');

      if (kDebugMode) {
        print('DEBUG: Sending HTTP GET request to URL: $url');
      }

      final response = await http.get(url);

      if (kDebugMode) {
        print(
          'DEBUG: Received response with status code: ${response.statusCode}',
        );
        print('DEBUG: Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          _note = NoteDto.fromJson(data);
          if (kDebugMode) {
            print(
              'DEBUG: Successfully parsed note data: ${_note?.description}',
            );
          }
        } else {
          _note = null;
          _errorMessage = 'Invalid data format from API.';
          if (kDebugMode) {
            print('DEBUG: API response was not a valid JSON object.');
          }
        }
      } else if (response.statusCode == 404) {
        _note = null;
        if (kDebugMode) {
          print(
            'DEBUG: No note found (Status 404). This is the expected case for no note.',
          );
        }
      } else {
        _note = null;
        _errorMessage = 'Failed to load note: ${response.statusCode}';
        if (kDebugMode) {
          print(
            'DEBUG: An unexpected status code was received: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      _note = null;
      _errorMessage = 'An error occurred while fetching the note: $e';
      if (kDebugMode) {
        print('DEBUG: An exception occurred: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('DEBUG: Note fetch process finished. Notifying listeners.');
      }
    }
  }

  // Update or create a note for a specific diary
  Future<void> updateOrCreateNote(int diaryId, String description) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = Uri.parse('http://localhost:5158/api/diaries/$diaryId/note');
      final body = json.encode({'description': description});
      final headers = {'Content-Type': 'application/json'};

      final response = await http.put(url, headers: headers, body: body);

      if (response.statusCode == 204) {
        // Successful update (No Content)
        if (kDebugMode) {
          print('Note updated successfully.');
        }
        await fetchNoteByDiary(diaryId);
      } else {
        _errorMessage = 'Failed to update note: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'An error occurred while updating the note: $e';
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
