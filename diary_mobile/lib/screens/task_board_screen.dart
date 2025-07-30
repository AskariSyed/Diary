// lib/screens/task_board_screen.dart
import 'package:diary_mobile/dialogs/show_add_page_dialog.dart';
import 'package:diary_mobile/dialogs/show_add_task_dialog.dart'; // Corrected import
import 'package:diary_mobile/screens/build_empty_state.dart';
import 'package:diary_mobile/screens/build_error_state.dart';
import 'package:diary_mobile/screens/build_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/models/task_dto.dart';
import '/mixin/taskstatus.dart'; // This import now brings in ExpansibleController
import '/providers/task_provider.dart';
import '/providers/theme_provider.dart';
import 'package:intl/intl.dart';

// Import the new tab view files
import 'package:diary_mobile/screens/tabs/all_tasks_view.dart'
    hide ExpansibleController;
import 'package:diary_mobile/screens/tabs/status_tasks_view.dart';

class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, bool> _statusExpandedState = {};
  // REMOVED: _pageExpandedState is no longer needed

  // UPDATED: Now _expansionTileControllers only manages status controllers
  final Map<String, ExpansibleController> _expansionTileControllers = {};

  final ScrollController _scrollController = ScrollController();
  String? _fetchErrorMessage;
  int _scrollTrigger = 0;

  int? _pageToScrollTo;
  TaskStatus? _statusToExpand;

  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;
  List<TaskDto> _filteredTasks = [];
  bool _isFiltering = false;
  bool _isScrollingFromSearch = false;
  bool _isDraggingTask = false; // New state variable for global drag status
  bool _isSearching = false; // New state for interactive search bar

  late TabController _tabController;
  int?
  _initialPageIndexForPageView; // New: To set initial page for AllTasksView

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchTasksWithErrorHandling());
    _searchController.addListener(_onSearchChanged);

    _tabController = TabController(
      length:
          TaskStatus.values
              .where((status) => status != TaskStatus.deleted)
              .length +
          1,
      vsync: this,
    );

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          setState(() {
            if (_pageToScrollTo != null) {
              _scrollTrigger++;
            }
          });
        } else {
          setState(() {
            _pageToScrollTo = null;
            _statusToExpand = null;

            _statusExpandedState.clear();
            _isScrollingFromSearch = false;
            for (var controller in _expansionTileControllers.values) {
              if (controller.isExpanded) {
                controller.collapse();
              }
            }
          });
        }
      }
    });
  }

  ExpansibleController _getOrCreateExpansionTileController(String key) {
    return _expansionTileControllers.putIfAbsent(
      key,
      () => ExpansibleController(),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown Date';
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      // Don't call _clearSearch here directly to avoid recursion.
      // Instead, just update the state. The user can explicitly clear.
      _searchTasks();
    } else {
      _searchTasks();
    }
    // We need to call setState to rebuild the AppBar with the clear icon
    setState(() {});
  }

  void _searchTasks() {
    final String searchText = _searchController.text.trim().toLowerCase();
    final allTasks = Provider.of<TaskProvider>(context, listen: false).tasks;

    setState(() {
      if (searchText.isEmpty && _selectedDate == null) {
        _filteredTasks = [];
        _isFiltering = false;
      } else {
        _filteredTasks = allTasks.where((task) {
          final taskTitle = task.title.toLowerCase();
          final formattedDate = _formatDate(task.pageDate).toLowerCase();

          final matchesTitle =
              searchText.isNotEmpty && taskTitle.contains(searchText);
          final matchesDateText =
              searchText.isNotEmpty && formattedDate.contains(searchText);
          final matchesPickedDate =
              _selectedDate != null &&
              task.pageDate != null &&
              task.pageDate!.year == _selectedDate!.year &&
              task.pageDate!.month == _selectedDate!.month &&
              task.pageDate!.day == _selectedDate!.day;

          return (matchesTitle || matchesDateText || matchesPickedDate) &&
              task.status != TaskStatus.deleted;
        }).toList();

        _isFiltering = true;
      }
    });
  }

  // MODIFIED: Patched to prevent recursion from listener.
  void _clearSearch() {
    // Temporarily remove listener to prevent recursion when we clear the controller
    _searchController.removeListener(_onSearchChanged);
    _searchController.clear();
    _searchController.addListener(_onSearchChanged);

    setState(() {
      _selectedDate = null;
      _isFiltering = false;
      _filteredTasks = [];
      if (!_isScrollingFromSearch) {
        _pageToScrollTo = null;
        _statusToExpand = null;
      }
      _statusExpandedState.clear();
      for (var controller in _expansionTileControllers.values) {
        if (controller.isExpanded) {
          controller.collapse();
        }
      }
    });
  }

  Future<void> _selectDateFromCalendar() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _searchController.text = _formatDate(picked);
      });
      // The listener on _searchController will automatically trigger _searchTasks
    }
  }

  Future<void> _fetchTasksWithErrorHandling() async {
    try {
      await Provider.of<TaskProvider>(context, listen: false).fetchTasks();
      setState(() {
        _fetchErrorMessage = null;
        print('Tasks fetched successfully');

        // Logic to determine initial page to display (no scroll animation)
        final List<TaskDto> allTasks = Provider.of<TaskProvider>(
          context,
          listen: false,
        ).tasks;
        final Map<int, List<TaskDto>> tasksByPageTemp = {};
        for (var task in allTasks) {
          tasksByPageTemp.putIfAbsent(task.pageId, () => []).add(task);
        }

        int? initialDisplayPageId;
        final DateTime now = DateTime.now();
        final DateTime today = DateTime(now.year, now.month, now.day);

        for (final pageId in tasksByPageTemp.keys) {
          final pageDate = tasksByPageTemp[pageId]?.first.pageDate;
          if (pageDate != null &&
              DateTime(pageDate.year, pageDate.month, pageDate.day) == today) {
            initialDisplayPageId = pageId;
            break;
          }
        }

        if (initialDisplayPageId == null && tasksByPageTemp.isNotEmpty) {
          DateTime? mostRecentDate;
          int? mostRecentPage;
          tasksByPageTemp.forEach((pageId, tasks) {
            final pageDate = tasks.first.pageDate;
            if (pageDate != null) {
              if (mostRecentDate == null || pageDate.isAfter(mostRecentDate!)) {
                mostRecentDate = pageDate;
                mostRecentPage = pageId;
              }
            }
          });
          initialDisplayPageId = mostRecentPage;
        }
        if (initialDisplayPageId != null) {
          final List<int> currentSortedPageIds = tasksByPageTemp.keys.toList()
            ..sort((a, b) {
              final DateTime? dateA = tasksByPageTemp[a]?.first.pageDate;
              final DateTime? dateB = tasksByPageTemp[b]?.first.pageDate;
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return -1;
              if (dateB == null) return 1;
              return dateA.compareTo(dateB);
            });
          _initialPageIndexForPageView = currentSortedPageIds.indexOf(
            initialDisplayPageId,
          );
          if (_initialPageIndexForPageView == -1) {
            _initialPageIndexForPageView =
                0; // Fallback to first page if not found
          }
        } else {
          _initialPageIndexForPageView = 0; // Default to first page if no tasks
        }
      });
    } catch (e) {
      print('Error fetching tasks from _fetchTaskswithError Handling: $e');
      setState(() {
        _fetchErrorMessage = e.toString();
      });
    }
  }

  final Map<String, GlobalKey> _globalKeys = {};

  GlobalKey _getPageGlobalKey(String viewPrefix, int pageId) {
    final String keyString = '$viewPrefix-$pageId';
    final GlobalKey key = _globalKeys.putIfAbsent(
      keyString,
      () => GlobalObjectKey(keyString),
    );
    print(
      'TaskBoardScreen: _getPageGlobalKey called for $keyString. Key instance: $key',
    );
    return key;
  }

  void _scrollToPageAndStatus(int pageId, TaskStatus status) {
    print(
      'TaskBoardScreen: _scrollToPageAndStatus called with pageId: $pageId, status: $status',
    );
    setState(() {
      _isSearching = false; // Close search UI when navigating
      _isScrollingFromSearch = true;
      _pageToScrollTo = pageId;
      _statusToExpand = status;
      _clearSearch(); // Clear search text and filter state

      _scrollTrigger++;
      print(
        'TaskBoardScreen: After setState in _scrollToPageAndStatus: _pageToScrollTo = $_pageToScrollTo, _scrollTrigger = $_scrollTrigger',
      );
    });

    if (_tabController.index != 0) {
      print('TaskBoardScreen: Switching to All Tasks tab.');
      if (mounted) {
        _tabController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _onScrollAndExpand(int pageId, TaskStatus status) {
    print(
      'TaskBoardScreen: _onScrollAndExpand callback received for page $pageId, status $status',
    );

    setState(() {
      _statusExpandedState.clear();
      _statusExpandedState['status_${pageId}_${status.index}'] = true;
    });

    final String statusKey = 'status_${pageId}_${status.index}';
    final ExpansibleController? statusController =
        _expansionTileControllers[statusKey];
    if (statusController != null && !statusController.isExpanded) {
      print('TaskBoardScreen: Expanding status tile for key: $statusKey');
      Future.microtask(() {
        if (mounted) statusController.expand();
      });
    }

    setState(() {
      _pageToScrollTo = null;
      _statusToExpand = null;
      _isScrollingFromSearch = false;
    });
  }

  // New methods to handle global drag state
  void _handleDragStarted() {
    setState(() {
      _isDraggingTask = true;
    });
  }

  // Corrected signature: removed DragEndDetails parameter
  void _handleDragEnded() {
    setState(() {
      _isDraggingTask = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    for (var controller in _expansionTileControllers.values) {
      controller.dispose();
    }
    _expansionTileControllers.clear();
    super.dispose();
  }

  Color _getStatusColor(TaskStatus status, Brightness brightness) {
    final baseColors = {
      TaskStatus.backlog: Colors.blueGrey,
      TaskStatus.toDiscuss: Colors.amber,
      TaskStatus.inProgress: Colors.deepPurple,
      TaskStatus.onHold: Colors.red,
      TaskStatus.complete: Colors.green,
      TaskStatus.toFollowUp: Colors.teal,
    };

    final baseColor = baseColors[status] ?? Colors.grey;

    // Return the base color directly for both light and dark themes
    return baseColor;
  }

  // Helper method to get an icon for each status
  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.backlog:
        return Icons.assignment;
      case TaskStatus.toDiscuss:
        return Icons.chat;
      case TaskStatus.inProgress:
        return Icons.work;
      case TaskStatus.onHold:
        return Icons.pause_circle_filled;
      case TaskStatus.complete:
        return Icons.check_circle;
      case TaskStatus.toFollowUp:
        return Icons.follow_the_signs;
      case TaskStatus
          .deleted: // Should not be a drop target, but for completeness
        return Icons.delete;
      default:
        return Icons.help_outline;
    }
  }

  // NEW: Helper method for the default AppBar
  AppBar _buildDefaultAppBar(List<Tab> tabs) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    return AppBar(
      title: const Text('Diary Task Board'),
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: tabs,
        indicatorColor: Theme.of(context).colorScheme.onSurface,
        labelColor: Theme.of(context).colorScheme.onSurface,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search Tasks',
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.note_add),
          tooltip: 'Add New Page',
          onPressed: () =>
              showAddPageDialog(context, taskProvider, _pageToScrollTo),
        ),
        IconButton(
          icon: Icon(
            themeProvider.themeMode == ThemeMode.light
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
          ),
          onPressed: themeProvider.toggleTheme,
        ),
      ],
    );
  }

  // NEW: Helper method for the search AppBar
  AppBar _buildSearchAppBar(List<Tab> tabs) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _clearSearch(); // Clears text and resets filter state
          });
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search by title or date...',
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withOpacity(0.6),
          ),
        ),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 18,
        ),
      ),
      actions: [
        // Conditionally show clear button based on text field content
        if (_searchController.text.isNotEmpty)
          IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          tooltip: 'Filter by Date',
          onPressed: _selectDateFromCalendar,
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: tabs,
        indicatorColor: Theme.of(context).colorScheme.onSurface,
        labelColor: Theme.of(context).colorScheme.onSurface,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Brightness currentBrightness = Theme.of(context).brightness;

    final List<TaskDto> tasksToShow = taskProvider.tasks
        .where((task) => task.status != TaskStatus.deleted)
        .toList();

    final Map<int, List<TaskDto>> tasksByPage = {};
    for (var task in tasksToShow) {
      tasksByPage.putIfAbsent(task.pageId, () => []).add(task);
    }
    final List<int> sortedPageIds = tasksByPage.keys.toList()
      ..sort((a, b) {
        final DateTime? dateA = tasksByPage[a]?.first.pageDate;
        final DateTime? dateB = tasksByPage[b]?.first.pageDate;

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return -1;
        if (dateB == null) return 1;
        return dateA.compareTo(dateB);
      });

    if (taskProvider.errorMessage != null) {
      return ErrorStateScreen(
        themeProvider: themeProvider,
        taskProvider: taskProvider,
        scrollToPageId: _pageToScrollTo,
        fetchErrorMessage: _fetchErrorMessage,
      );
    }

    if (taskProvider.isLoading && sortedPageIds.isEmpty) {
      return buildLoadingScreen(
        context,
        themeProvider,
        taskProvider,
        _pageToScrollTo,
      );
    }
    if (sortedPageIds.isEmpty && !_isFiltering) {
      return buildEmptyState(
        themeProvider,
        taskProvider,
        context,
        _pageToScrollTo,
      );
    }

    final List<Tab> tabs = [
      Tab(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.all_inclusive,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ), // Icon for "All Tasks"
            const Text(
              'All Tasks',
              style: TextStyle(fontSize: 9), // Smaller text for tabs
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      ...TaskStatus.values
          .where((status) => status != TaskStatus.deleted)
          .map(
            (status) => Tab(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getStatusIcon(status),
                    size: 18,
                    color: _getStatusColor(status, currentBrightness),
                  ), // Use icon with status color
                  Text(
                    status.toApiString(),
                    style: const TextStyle(
                      fontSize: 9,
                    ), // Smaller text for tabs
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
    ];

    final List<Widget> tabViews = [
      AllTasksView(
        scrollTrigger: _scrollTrigger,
        tasksToShow: tasksToShow,
        tasksByPage: tasksByPage,
        sortedPageIds: sortedPageIds,
        getPageGlobalKey: _getPageGlobalKey,
        statusExpandedState: _statusExpandedState,
        currentBrightness: currentBrightness,
        formatDate: _formatDate,
        getStatusColor: _getStatusColor,
        scrollToPageAndStatus: _scrollToPageAndStatus,
        pageToScrollTo: _pageToScrollTo,
        statusToExpand: _statusToExpand,
        onScrollComplete: () {
          setState(() {
            _pageToScrollTo = null;
            _statusToExpand = null;
            _isScrollingFromSearch = false;
          });
        },
        onScrollAndExpand: _onScrollAndExpand,
        expansionTileControllers: _expansionTileControllers,
      ),
      ...TaskStatus.values
          .where((status) => status != TaskStatus.deleted)
          .map(
            (status) => StatusTasksView(
              tasksToShow: tasksToShow,
              tasksByPage: tasksByPage,
              sortedPageIds: sortedPageIds,
              getPageGlobalKey: _getPageGlobalKey,
              statusExpandedState: _statusExpandedState,
              currentBrightness: currentBrightness,
              formatDate: _formatDate,
              getStatusColor: _getStatusColor,
              scrollToPageAndStatus: _scrollToPageAndStatus,
              scrollController: _scrollController,
              pageToScrollTo: _pageToScrollTo,
              statusToExpand: _statusToExpand,
              filterStatus: status,
              onScrollComplete: () {
                setState(() {
                  _pageToScrollTo = null;
                  _statusToExpand = null;
                  _isScrollingFromSearch = false;
                });
              },
              expansionTileControllers: _expansionTileControllers,
              onDragStarted: _handleDragStarted, // Pass callback
              onDragEnded: _handleDragEnded, // Pass callback
            ),
          ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        // MODIFIED: AppBar is now built dynamically
        appBar: _isSearching
            ? _buildSearchAppBar(tabs)
            : _buildDefaultAppBar(tabs),
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              // Add this line to enable swiping
              physics: const AlwaysScrollableScrollPhysics(),
              children: tabViews,
            ),

            // Floating Action Button - now inside the Stack
            Positioned(
              right: 16.0,
              bottom: 16.0,
              child: FloatingActionButton.extended(
                onPressed: () async {
                  if (!mounted) return;
                  showAddTaskDialog(context);
                },
                label: const Text('Add New Task'),
                icon: const Icon(Icons.add),
              ),
            ),

            // Global drop targets (cans) visible when dragging - positioned above FAB
            if (_isDraggingTask)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Theme.of(context).cardColor.withOpacity(0.9),
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: TaskStatus.values
                        .where((status) => status != TaskStatus.deleted)
                        .map(
                          (status) => _buildStatusDropTarget(
                            context,
                            status,
                            taskProvider,
                            currentBrightness,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),

            if (_isFiltering && _filteredTasks.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withOpacity(0.95),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Search Results (${_filteredTasks.length})',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = _filteredTasks[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 4.0,
                              ),
                              child: ListTile(
                                title: Text(task.title),
                                subtitle: Text(
                                  'Page Date: ${_formatDate(task.pageDate)} | Status: ${task.status.toApiString()}',
                                ),
                                onTap: () {
                                  _scrollToPageAndStatus(
                                    task.pageId,
                                    task.status,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isFiltering && _filteredTasks.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tasks found for "${_searchController.text}"',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear Search'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropTarget(
    BuildContext context,
    TaskStatus status,
    TaskProvider taskProvider,
    Brightness currentBrightness,
  ) {
    return DragTarget<TaskDto>(
      onWillAcceptWithDetails: (data) {
        return data.data.status != status;
      },
      onAcceptWithDetails: (details) async {
        final draggedTask = details.data;
        try {
          final response = await taskProvider.updateTaskStatusForTodayPage(
            draggedTask.id,
            status,
          );

          final message = response?['message'] ?? 'Task status updated.';

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update task status: $e')),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final bool isHovering = candidateData.isNotEmpty;
        return Container(
          width: 60,
          height: 80,
          decoration: BoxDecoration(
            color: isHovering
                ? _getStatusColor(status, currentBrightness).withOpacity(0.7)
                : _getStatusColor(status, currentBrightness).withOpacity(0.4),
            borderRadius: BorderRadius.circular(
              15.0,
            ), // Rounded corners for can look
            border: Border.all(
              color: isHovering
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getStatusIcon(status), // Helper for status icons
                color: isHovering
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
              Text(
                status.toApiString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isHovering
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
