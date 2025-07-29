import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '/models/task_dto.dart';
import '/mixin/taskstatus.dart';
import '/models/create_page_dto.dart';
import '../models/task_history_dto.dart';

class TaskProvider with ChangeNotifier {
  List<TaskDto> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  final String _tasksBaseUrl = 'https://430e9003f511.ngrok-free.app/api/Tasks';
  final String _pagesBaseUrl = 'https://430e9003f511.ngrok-free.app/api/Pages';

  List<TaskDto> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  TaskProvider() {
    fetchTasks();
  }
  void clearErrorMessage() {
    _clearErrorMessage();
  }

  void _setErrorMessage(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearErrorMessage() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> fetchTasks() async {
    _isLoading = true;
    _clearErrorMessage();
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$_tasksBaseUrl/allpagetasks'));

      if (response.statusCode == 200) {
        List<dynamic> taskJson = json.decode(response.body);
        _tasks = taskJson.map((json) => TaskDto.fromJson(json)).toList();
        _tasks.sort((a, b) {
          int pageIdComparison = b.pageId.compareTo(a.pageId);
          if (pageIdComparison != 0) {
            return pageIdComparison;
          }
          int statusComparison = a.status.index.compareTo(b.status.index);
          if (statusComparison != 0) {
            return statusComparison;
          }
          return a.id.compareTo(b.id);
        });
      } else {
        _setErrorMessage(
          'Failed to load tasks: Server responded with status ${response.statusCode}. Body: ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      String userMessage =
          'Network error: Could not connect to the backend server.';
      if (e is http.ClientException &&
          e.message.contains('Connection refused')) {
        userMessage =
            'Server is unreachable. Please ensure the backend is running and accessible at $_tasksBaseUrl.';
      } else if (e is http.ClientException &&
          e.message.contains('Failed host lookup')) {
        userMessage =
            'Could not resolve server address. Check your internet connection or server URL: $_tasksBaseUrl.';
      } else if (e is http.ClientException &&
          e.message.contains(
            'Connection closed before full header was received',
          )) {
        userMessage = 'Connection lost unexpectedly. Please try again.';
      } else {
        userMessage = 'An unexpected error occurred: ${e.toString()}';
      }
      _setErrorMessage(userMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTask(
    String title,
    TaskStatus status, {
    required int pageId,
  }) async {
    _isLoading = true;
    _clearErrorMessage();
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_tasksBaseUrl/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'status': status.toApiString(),
          'pageId': pageId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchTasks();
      } else {
        _setErrorMessage(
          'Failed to add task: Server responded with status ${response.statusCode}. Body: ${response.body}',
        );
      }
    } catch (e) {
      print('Error adding task: $e');
      _setErrorMessage(
        'Failed to add task due to network error or server issue. Please try again.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateTaskStatus(int pageTaskId, TaskStatus newStatus) async {
    _isLoading = true;
    _clearErrorMessage();
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('$_tasksBaseUrl/pagetask/$pageTaskId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'Status': newStatus.toApiString()}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchTasks();
      } else {
        _setErrorMessage(
          'Failed to update task status: Server responded with status ${response.statusCode}. Body: ${response.body}',
        );
      }
    } catch (e) {
      print('Error updating task status: $e');
      _setErrorMessage(
        'Failed to update task status due to network error or server issue.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateTaskTitle(int pageTaskId, String newTitle) async {
    _isLoading = true;
    _clearErrorMessage();
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('$_tasksBaseUrl/pagetask/$pageTaskId/title'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'Title': newTitle}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchTasks();
      } else {
        _setErrorMessage(
          'Failed to update task title: Server responded with status ${response.statusCode}. Body: ${response.body}',
        );
      }
    } catch (e) {
      print('Error updating task title: $e');
      _setErrorMessage(
        'Failed to update task title due to network error or server issue.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateTask(
    int pageTaskId,
    String newTitle,
    TaskStatus newStatus,
  ) async {
    final originalTask = _tasks.firstWhere((task) => task.id == pageTaskId);

    List<Future<void>> updateOperations = [];

    if (originalTask.title != newTitle) {
      updateOperations.add(updateTaskTitle(pageTaskId, newTitle));
    }
    if (originalTask.status != newStatus) {
      updateOperations.add(updateTaskStatus(pageTaskId, newStatus));
    }

    if (updateOperations.isNotEmpty) {
      try {
        await Future.wait(updateOperations);
      } catch (e) {
        print('Error in combined updateTask: $e');
      }
    }
  }

  Future<void> deleteTask(int pageTaskId) async {
    _isLoading = true;
    _clearErrorMessage();
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('$_tasksBaseUrl/pagetask/$pageTaskId'),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchTasks();
      } else {
        _setErrorMessage(
          'Failed to delete task: Server responded with status ${response.statusCode}. Body: ${response.body}',
        );
      }
    } catch (e) {
      print('Error deleting task: $e');
      _setErrorMessage(
        'Failed to delete task due to network error or server issue.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> createNewPage(int diaryNo, DateTime pageDate) async {
    _isLoading = true;
    _clearErrorMessage();
    notifyListeners();
    int newPageId = -1;

    try {
      final createPageDto = CreatePageDto(diaryNo: diaryNo, pageDate: pageDate);
      final response = await http.post(
        Uri.parse('$_pagesBaseUrl/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(createPageDto.toJson()),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        newPageId = responseData['pageId'] as int;
        await fetchTasks();
      } else {
        String errorMessage = 'Failed to create new page.';
        if (response.statusCode == 404) {
          errorMessage = 'Diary with ID $diaryNo not found.';
        } else if (response.statusCode == 409) {
          errorMessage =
              'A page already exists for Diary ID $diaryNo on ${pageDate.toLocal().toIso8601String().split('T').first}.';
        } else {
          errorMessage =
              'Server responded with status ${response.statusCode}. Body: ${response.body}';
        }
        _setErrorMessage(errorMessage);
        // You can optionally throw or just return -1
        return -1;
      }
    } catch (e) {
      print('Error creating new page: $e');
      _setErrorMessage(
        'Failed to create new page due to network error or server issue. Check if backend is running.',
      );
      return -1;
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return newPageId;
  }

  int? getCurrentMostRecentPageId() {
    if (_tasks.isEmpty) {
      return null;
    }
    return _tasks.map((task) => task.pageId).reduce((a, b) => a > b ? a : b);
  }

  Future<int> getTargetPageIdForNewTask() async {
    final currentMostRecent = getCurrentMostRecentPageId();
    return currentMostRecent ?? 1;
  }
  // At the top of TaskProvider file

  Future<List<TaskHistoryDto>> getTaskHistoryByParentId(
    int parentTaskId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_tasksBaseUrl/task-history/by-parent/$parentTaskId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => TaskHistoryDto.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to fetch task history. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching task history by parentId: $e');
      rethrow;
    }
  }

  Future<List<TaskHistoryDto>> getTaskHistoryByPageTaskId(
    int pageTaskId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_tasksBaseUrl/task-history/by-page-task/$pageTaskId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => TaskHistoryDto.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to fetch task history. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching task history by pageTaskId: $e');
      rethrow;
    }
  }

  Future<int?> getPagebyDate(int diaryId, DateTime date) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final url = Uri.parse(
      '$_pagesBaseUrl/by-date?diaryId=$diaryId&date=$formattedDate',
    );

    print('Requesting page by date with URL: $url');

    try {
      final response = await http.get(url);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        print('Parsed pageId from response: ${jsonData['pageId']}');
        return jsonData['pageId'] as int;
      } else if (response.statusCode == 404) {
        print('No page found for Diary ID $diaryId on $formattedDate.');
        return null;
      } else {
        final errorMsg = 'Failed to fetch page: Status ${response.statusCode}';
        print(errorMsg);
        _setErrorMessage(errorMsg);
        return null;
      }
    } catch (e) {
      print('Error fetching page by date: $e');
      _setErrorMessage('Network error while fetching page for $formattedDate');
      return null;
    }
  }
}
