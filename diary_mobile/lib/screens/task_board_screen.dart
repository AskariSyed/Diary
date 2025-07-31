// lib/screens/task_board_screen.dart
import 'dart:ui';

import 'package:diary_mobile/dialogs/show_add_page_dialog.dart';
import 'package:diary_mobile/dialogs/show_add_task_dialog.dart';
import 'package:diary_mobile/screens/build_empty_state.dart';
import 'package:diary_mobile/screens/build_error_state.dart';
import 'package:diary_mobile/screens/build_loading_screen.dart';
import 'package:diary_mobile/widgets/status_dropTarget.dart'; // Ensure this import is correct
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/models/task_dto.dart';
import '/mixin/taskstatus.dart'; // Ensure this import is correct
import '/providers/task_provider.dart';
import '/providers/theme_provider.dart';
import 'package:intl/intl.dart';

// Import the new tab view files
import 'package:diary_mobile/screens/tabs/all_tasks_view.dart'
    hide
        ExpansibleController; // Ensure ExpansibleController is correctly handled if it's in multiple files
import 'package:diary_mobile/screens/tabs/status_tasks_view.dart';

class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen>
    with TickerProviderStateMixin {
  final Map<String, bool> _statusExpandedState = {};
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
  bool _isDraggingTask = false;
  bool _isSearching = false;

  late TabController _mainTabController;
  late TabController _filterTabController;

  // Keep track of the currently selected status for filtering
  TaskStatus? _currentFilterStatus;

  // This variable will hold the index for the 'Diary' tab's initial view
  // It should be used to directly set the index of _mainTabController
  int _initialMainTabIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchTasksWithErrorHandling());
    _searchController.addListener(_onSearchChanged);

    // Initialize main tab controller (Diary, Filters)
    _mainTabController = TabController(
      length: 2, // 'Diary' and 'Filters'
      vsync: this,
      initialIndex: _initialMainTabIndex, // Set initial index here
    );

    // Initialize filter tab controller (for individual statuses)
    _filterTabController = TabController(
      length: TaskStatus.values
          .where((status) => status != TaskStatus.deleted)
          .length,
      vsync: this,
    );

    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        if (_mainTabController.index == 0) {
          // Switched to Diary tab
          setState(() {
            _currentFilterStatus = null; // Clear any active status filter
            if (_pageToScrollTo != null) {
              _scrollTrigger++;
            }
          });
        } else {
          // Switched to Filters tab
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
            _filterTabController.animateTo(
              TaskStatus.backlog.index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
            _currentFilterStatus = TaskStatus.backlog;
          });
        }
      }
    });

    _filterTabController.addListener(() {
      if (!_filterTabController.indexIsChanging) {
        final filteredStatuses = TaskStatus.values
            .where((status) => status != TaskStatus.deleted)
            .toList();
        setState(() {
          _currentFilterStatus = filteredStatuses[_filterTabController.index];
        });
      }
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown Date';
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      _searchTasks();
    } else {
      _searchTasks();
    }
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

  void _clearSearch() {
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
    }
  }

  Future<void> _fetchTasksWithErrorHandling() async {
    try {
      await Provider.of<TaskProvider>(context, listen: false).fetchTasks();
      setState(() {
        _fetchErrorMessage = null;
        print('Tasks fetched successfully');
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
          // Set the initial index for the main tab controller to 0 (Diary tab)
          // The pageToScrollTo will then handle the specific page within the Diary tab
          _initialMainTabIndex = 0;
        } else {
          _initialMainTabIndex = 0;
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
      _isSearching = false;
      _isScrollingFromSearch = true;
      _pageToScrollTo = pageId;
      _statusToExpand = status;
      _clearSearch();

      _scrollTrigger++;
      print(
        'TaskBoardScreen: After setState in _scrollToPageAndStatus: _pageToScrollTo = $_pageToScrollTo, _scrollTrigger = $_scrollTrigger',
      );
    });

    // If currently on the "Filters" tab, switch to "Diary" tab
    if (_mainTabController.index != 0) {
      print('TaskBoardScreen: Switching to All Tasks tab.');
      if (mounted) {
        _mainTabController.animateTo(
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

  void _handleDragStarted() {
    setState(() {
      _isDraggingTask = true;
    });
  }

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
    _mainTabController.dispose();
    _filterTabController.dispose();
    for (var controller in _expansionTileControllers.values) {
      controller.dispose();
    }
    _expansionTileControllers.clear();
    super.dispose();
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

    return DefaultTabController(
      length: 2, // 'Diary' and 'Filters'
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
              Theme.of(context).appBarTheme.backgroundColor ??
              Theme.of(context).colorScheme.surface,
          title: _isSearching
              ? TextField(
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
                )
              : const Text(
                  'E-Diary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
          leading: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _clearSearch();
                    });
                  },
                )
              : null,
          actions: [
            if (_isSearching && _searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearSearch,
              ),
            if (_isSearching)
              IconButton(
                icon: const Icon(Icons.calendar_today),
                tooltip: 'Filter by Date',
                onPressed: _selectDateFromCalendar,
              ),
            if (!_isSearching)
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
          // This is where the main TabBar will be placed
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(
              _mainTabController.index == 0
                  ? kToolbarHeight
                  : kToolbarHeight * 2,
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _mainTabController,
                  tabs: [
                    Tab(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.book, // A more diary-like icon
                              size: 24, // Bigger icon
                              color: _mainTabController.index == 0
                                  ? Colors
                                        .deepPurple // Purple when selected
                                  : Colors.grey, // Grey when not selected
                            ),
                            Text(
                              'My Diary', // Bigger text
                              style: TextStyle(
                                fontSize: 14,
                                color: _mainTabController.index == 0
                                    ? Colors
                                          .deepPurple // Purple when selected
                                    : Colors.grey, // Grey when not selected
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_list,
                            size: 18,
                            color: _mainTabController.index == 1
                                ? Colors
                                      .deepPurple // Purple when selected
                                : Colors.grey, // Grey when not selected
                          ),
                          Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 9,
                              color: _mainTabController.index == 1
                                  ? Colors
                                        .deepPurple // Purple when selected
                                  : Colors.grey, // Grey when not selected
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                  indicatorColor: Theme.of(context).colorScheme.onSurface,
                  // labelColor and unselectedLabelColor are set directly on Icon and Text
                ),
                // Conditional TabBar for filters with animation
                AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 400,
                  ), // Adjust duration as needed
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, -1.0), // Slide from top
                            end: Offset.zero,
                          ).animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                  child:
                      _mainTabController.index ==
                          1 // Only show when "Filters" tab is selected
                      ? TabBar(
                          key: const ValueKey(
                            'filterTabBar',
                          ), // Important for AnimatedSwitcher to work
                          controller: _filterTabController,
                          isScrollable: true,
                          tabs: TaskStatus.values
                              .where((status) => status != TaskStatus.deleted)
                              .map(
                                (status) => Tab(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        getStatusIcon(status),
                                        size: 18,
                                        color: _currentFilterStatus == status
                                            ? getStatusColor(
                                                status,
                                                currentBrightness,
                                              ) // Use status color when selected
                                            : Colors
                                                  .grey, // Grey when not selected
                                      ),
                                      Text(
                                        status.toApiString(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: _currentFilterStatus == status
                                              ? getStatusColor(
                                                  status,
                                                  currentBrightness,
                                                ) // Use status color when selected
                                              : Colors
                                                    .grey, // Grey when not selected
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          indicatorColor: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                          // labelColor and unselectedLabelColor are set directly on Icon and Text
                        )
                      : const SizedBox.shrink(), // Empty widget when not showing filters
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            // Wrap the TabBarView content for filters with AnimatedSwitcher
            AnimatedSwitcher(
              duration: const Duration(
                milliseconds: 300,
              ), // Duration of the animation
              transitionBuilder: (Widget child, Animation<double> animation) {
                // You can choose different transitions here
                return FadeTransition(opacity: animation, child: child);
              },
              child: TabBarView(
                key: ValueKey(
                  _mainTabController.index,
                ), // Key changes when main tab changes
                controller: _mainTabController,
                physics:
                    const NeverScrollableScrollPhysics(), // Disable swiping on TabBarView directly
                children: [
                  // "Diary" Tab Content (All Tasks View)
                  AllTasksView(
                    scrollTrigger: _scrollTrigger,
                    tasksToShow: tasksToShow,
                    tasksByPage: tasksByPage,
                    sortedPageIds: sortedPageIds,
                    // getPageGlobalKey: _getPageGlobalKey,
                    statusExpandedState: _statusExpandedState,
                    currentBrightness: currentBrightness,
                    formatDate: _formatDate,
                    getStatusColor: getStatusColor,
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
                  // "Filters" Tab Content (Status Tasks View, conditional on selected status)
                  // This is the part that will animate
                  _currentFilterStatus == null
                      ? Center(
                          key: const ValueKey(
                            'noFilterSelected',
                          ), // Unique key for AnimatedSwitcher
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.filter_list,
                                size: 80,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Select a status to filter tasks',
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : StatusTasksView(
                          key: ValueKey(
                            _currentFilterStatus!.index,
                          ), // Unique key for AnimatedSwitcher based on status
                          tasksToShow: tasksToShow,
                          tasksByPage: tasksByPage,
                          sortedPageIds: sortedPageIds,
                          getPageGlobalKey: _getPageGlobalKey,
                          statusExpandedState: _statusExpandedState,
                          currentBrightness: currentBrightness,
                          formatDate: _formatDate,
                          getStatusColor: getStatusColor,
                          scrollToPageAndStatus: _scrollToPageAndStatus,
                          scrollController: _scrollController,
                          pageToScrollTo: _pageToScrollTo,
                          statusToExpand: _statusToExpand,
                          filterStatus: _currentFilterStatus!,
                          onScrollComplete: () {
                            setState(() {
                              _pageToScrollTo = null;
                              _statusToExpand = null;
                              _isScrollingFromSearch = false;
                            });
                          },
                          expansionTileControllers: _expansionTileControllers,
                          onDragStarted: _handleDragStarted,
                          onDragEnded: _handleDragEnded,
                        ),
                ],
              ),
            ),
            Positioned(
              right: 16.0,
              bottom: 16.0,
              child: FloatingActionButton(
                child: const Icon(Icons.add),
                onPressed: () async {
                  if (!mounted) return;
                  showAddTaskDialog(context);
                },
              ),
            ),
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
                          (status) => buildStatusDropTarget(
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
              Positioned.fill(
                child: Stack(
                  children: [
                    // Blur the background
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                      child: Container(
                        color: const Color.fromARGB(
                          255,
                          0,
                          0,
                          0,
                        ).withOpacity(0.3),
                      ),
                    ),

                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
          ],
        ),
      ),
    );
  }
}
