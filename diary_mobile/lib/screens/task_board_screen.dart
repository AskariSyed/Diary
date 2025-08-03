// task_board_screen.dart
import 'dart:ui';
import 'package:diary_mobile/dialogs/show_add_page_dialog.dart';
import 'package:diary_mobile/dialogs/show_add_task_dialog.dart';
import 'package:diary_mobile/providers/page_provider.dart';
import 'package:diary_mobile/screens/build_empty_state.dart';
import 'package:diary_mobile/screens/build_error_state.dart';
import 'package:diary_mobile/screens/build_loading_screen.dart';
import 'package:diary_mobile/utils/task_helpers.dart';
import 'package:diary_mobile/widgets/animated_switcher_main_tab_filter_tab.dart';
import 'package:diary_mobile/widgets/drag_and_drop_target_bar.dart';
import 'package:diary_mobile/widgets/main_tab_bar.dart';
import 'package:diary_mobile/widgets/status_dropTarget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '/models/task_dto.dart';
import '/mixin/taskstatus.dart';
import '/providers/task_provider.dart';
import '/providers/theme_provider.dart';
import 'package:diary_mobile/screens/tabs/all_tasks_view.dart'
    hide ExpansibleController;
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
  TaskStatus? _currentFilterStatus;
  int _initialMainTabIndex = 0;

  // Add a listener for PageProvider
  late PageProvider _pageProvider;
  int? _previousPageCount;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchTasksWithErrorHandling());
    _searchController.addListener(_onSearchChanged);
    _mainTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _initialMainTabIndex,
    );
    _filterTabController = TabController(
      length: TaskStatus.values
          .where((status) => status != TaskStatus.deleted)
          .length,
      vsync: this,
    );

    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        if (_mainTabController.index == 0) {
          setState(() {
            _currentFilterStatus = null;
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

    // Initialize pageProvider and add listener
    _pageProvider = Provider.of<PageProvider>(context, listen: false);
    _previousPageCount = _pageProvider.pages.length;
    _pageProvider.addListener(_onPageProviderChange);
  }

  void _onPageProviderChange() {
    if (_pageProvider.pages.length > (_previousPageCount ?? 0)) {
      final int? newPageId = _pageProvider.pages.isNotEmpty
          ? _pageProvider.pages.last.pageId
          : null;

      if (newPageId != null) {
        _scrollToPageAndStatus(newPageId, TaskStatus.backlog);
      }
    }
    _previousPageCount = _pageProvider.pages.length;
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
          final formattedDate = formatDate(task.pageDate).toLowerCase();

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
        _searchController.text = formatDate(picked);
      });
    }
  }

  Future<void> _fetchTasksWithErrorHandling() async {
    try {
      await Provider.of<TaskProvider>(context, listen: false).fetchTasks();

      await Provider.of<PageProvider>(
        context,
        listen: false,
      ).fetchPagesByDiary(1);

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
    return key;
  }

  void _scrollToPageAndStatus(int pageId, TaskStatus status) {
    _searchController.removeListener(_onSearchChanged);
    _searchController.clear();
    _searchController.addListener(_onSearchChanged);

    setState(() {
      // All state changes are now in one place
      _isSearching = false;
      _isScrollingFromSearch = true;
      _pageToScrollTo = pageId;
      _statusToExpand = status;
      _scrollTrigger++;

      // Logic from _clearSearch() is merged here
      _selectedDate = null;
      _isFiltering = false;
      _filteredTasks = [];
      _statusExpandedState.clear();
      for (var controller in _expansionTileControllers.values) {
        if (controller.isExpanded) {
          controller.collapse();
        }
      }
    });

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
  } // task_board_screen.dart

  // ...
  void _onScrollAndExpand(int pageId, TaskStatus status) {
    // Safely schedules the code to run after the build is complete.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final String statusKey = 'status_${pageId}_${status.index}';
      final ExpansibleController? statusController =
          _expansionTileControllers[statusKey];

      if (statusController != null && !statusController.isExpanded) {
        print('TaskBoardScreen: Expanding status tile for key: $statusKey');
        statusController.expand();
      }

      // Consolidate state changes into a single call
      setState(() {
        _statusExpandedState.clear();
        _statusExpandedState[statusKey] = true;
        _pageToScrollTo = null;
        _statusToExpand = null;
        _isScrollingFromSearch = false;
      });
    });
  }

  // ...
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
    _pageProvider.removeListener(_onPageProviderChange);
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
    final pageProvider = Provider.of<PageProvider>(
      context,
    ); // Listen to PageProvider
    final Brightness currentBrightness = Theme.of(context).brightness;

    final List<TaskDto> tasksToShow = taskProvider.tasks
        .where((task) => task.status != TaskStatus.deleted)
        .toList();
    List<TaskDto> allTasks = taskProvider.tasks.toList();
    final Map<int, List<TaskDto>> tasksByPage = {};
    for (var task in allTasks) {
      tasksByPage.putIfAbsent(task.pageId, () => []).add(task);
    }
    final sortedPageIds = pageProvider.pages.map((p) => p.pageId).toList()
      ..sort((a, b) {
        final aDate = pageProvider.getPageDateById(a);
        final bDate = pageProvider.getPageDateById(b);
        return aDate!.compareTo(bDate!);
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
      return EmptyStateScreen(
        themeProvider: themeProvider,
        taskProvider: taskProvider,
        scrollToPageId: _pageToScrollTo,
      );
    }

    return DefaultTabController(
      length: 2,
      child: SafeArea(
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
                onPressed: () async {
                  await Provider.of<TaskProvider>(
                    context,
                    listen: false,
                  ).fetchTasks();

                  await Provider.of<PageProvider>(
                    context,
                    listen: false,
                  ).fetchPagesByDiary(1);

                  showTopSnackBar(
                    Overlay.of(context),
                    const CustomSnackBar.success(message: 'Tasks Refreshed'),
                    displayDuration: Durations.short1,
                  );
                },
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                icon: const Icon(Icons.note_add),
                tooltip: 'Add New Page',
                onPressed: () => showAddPageDialog(context, taskProvider),
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
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(
                _mainTabController.index == 0
                    ? kToolbarHeight
                    : kToolbarHeight * 2,
              ),
              child: Column(
                children: [
                  MainTabBar(mainTabController: _mainTabController),
                  AnimatedSwitcherMainTabFilterTab(
                    mainTabController: _mainTabController,
                    filterTabController: _filterTabController,
                    currentFilterStatus: _currentFilterStatus,
                    currentBrightness: currentBrightness,
                  ),
                ],
              ),
            ),
          ),
          body: Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: TabBarView(
                  key: ValueKey(_mainTabController.index),
                  controller: _mainTabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    AllTasksView(
                      pageDatesById: {
                        for (var page in pageProvider.pages)
                          page.pageId: page.pageDate,
                      },
                      allTasks: allTasks,
                      scrollTrigger: _scrollTrigger,
                      tasksToShow: tasksToShow,
                      tasksByPage: tasksByPage,
                      sortedPageIds: sortedPageIds,
                      statusExpandedState: _statusExpandedState,
                      currentBrightness: currentBrightness,
                      formatDate: formatDate,
                      getStatusColor: getStatusColor,
                      scrollToPageAndStatus: _scrollToPageAndStatus,
                      pageToScrollTo: _pageToScrollTo,
                      statusToExpand: _statusToExpand,
                      onScrollComplete: () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _pageToScrollTo = null;
                            _statusToExpand = null;
                            _isScrollingFromSearch = false;
                          });
                        });
                      },
                      onScrollAndExpand: _onScrollAndExpand,
                      expansionTileControllers: _expansionTileControllers,
                    ),
                    _currentFilterStatus == null
                        ? Center(
                            key: const ValueKey('noFilterSelected'),
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
                            key: ValueKey(_currentFilterStatus!.index),
                            tasksToShow: tasksToShow,
                            tasksByPage: tasksByPage,
                            sortedPageIds: sortedPageIds,
                            getPageGlobalKey: _getPageGlobalKey,
                            statusExpandedState: _statusExpandedState,
                            currentBrightness: currentBrightness,
                            formatDate: formatDate,
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
                DragDropTarget(
                  taskProvider: taskProvider,
                  currentBrightness: currentBrightness,
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
                                    'Page Date: ${formatDate(task.pageDate)} | Status: ${task.status.toApiString()}',
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
      ),
    );
  }
}
