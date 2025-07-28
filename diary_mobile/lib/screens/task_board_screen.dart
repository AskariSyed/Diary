// lib/screens/task_board_screen.dart
import 'package:diary_mobile/dialogs/show_add_page_dialog.dart';
import 'package:diary_mobile/dialogs/show_add_task_dialog.dart';
import 'package:diary_mobile/screens/build_empty_state.dart';
import 'package:diary_mobile/screens/build_error_state.dart';
import 'package:diary_mobile/screens/build_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/models/task_dto.dart';
import '/mixin/taskstatus.dart';
import '/providers/task_provider.dart';
import '/providers/theme_provider.dart';
import 'package:intl/intl.dart';

// Import the new tab view files
import 'package:diary_mobile/screens/tabs/all_tasks_view.dart';
import 'package:diary_mobile/screens/tabs/status_tasks_view.dart';

class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen>
    with SingleTickerProviderStateMixin {
  // We'll still use these maps to track intended expansion states for UI consistency
  // but the actual expansion will be driven by ExpansionTileControllers.
  final Map<String, bool> _statusExpandedState = {};
  final Map<int, bool> _pageExpandedState = {};

  // --- NEW: Map to hold ExpansionTileControllers ---
  final Map<String, ExpansionTileController> _expansionTileControllers = {};

  final ScrollController _scrollController = ScrollController();
  String? _fetchErrorMessage;
  int _scrollTrigger = 0;

  int? _pageToScrollTo;
  TaskStatus? _statusToExpand;

  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;
  List<TaskDto> _filteredTasks = [];
  bool _isFiltering = false;
  bool _isScrollingFromSearch = false; // New flag

  late TabController _tabController;

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
            // Trigger scroll on tab change to 'All Tasks' if there's a pending scroll target
            // This is crucial if a search result was clicked and the user was on another tab
            if (_pageToScrollTo != null) {
              _scrollTrigger++;
            }
          });
        } else {
          setState(() {
            _pageToScrollTo = null;
            _statusToExpand = null;
            // Clear expansion states when switching tabs (optional, but good for clean UI)
            _pageExpandedState.clear();
            _statusExpandedState.clear();
            _isScrollingFromSearch = false; // Reset flag on tab switch
            // Close all expansion tiles when switching tabs
            _expansionTileControllers.values.forEach((controller) {
              if (controller.isExpanded) {
                controller.collapse();
              }
            });
            // It's generally better not to clear the controllers themselves here,
            // but rather manage their expansion state. If they are cleared,
            // they would need to be re-created by the child widgets on subsequent visits.
            // For now, let's keep them and just collapse.
          });
        }
      }
    });
  }

  // --- NEW: Method to get or create ExpansionTileController ---
  // This method is primarily for TaskBoardScreen itself if it were to manage
  // controllers for top-level ExpansionTiles. For child widgets, they will use
  // the map passed down. This specific method might not be directly used here,
  // but it indicates the intent of managing controllers in a map.
  ExpansionTileController _getOrCreateExpansionTileController(String key) {
    return _expansionTileControllers.putIfAbsent(
      key,
      () => ExpansionTileController(),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown Date';
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      _clearSearch();
    } else {
      _searchTasks();
    }
  }

  void _searchTasks() {
    final String searchText = _searchController.text.trim();
    final allTasks = Provider.of<TaskProvider>(context, listen: false).tasks;

    setState(() {
      if (searchText.isEmpty) {
        _filteredTasks = [];
        _isFiltering = false;
      } else {
        _filteredTasks = allTasks.where((task) {
          return task.title.toLowerCase().contains(searchText.toLowerCase()) &&
              task.status != TaskStatus.deleted;
        }).toList();
        _isFiltering = true;
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _selectedDate = null;
      _isFiltering = false;
      _filteredTasks = [];
      if (!_isScrollingFromSearch) {
        _pageToScrollTo = null;
        _statusToExpand = null;
      }
      _pageExpandedState.clear();
      _statusExpandedState.clear();
      // Optionally collapse all tiles when search is cleared, if they are open.
      _expansionTileControllers.values.forEach((controller) {
        if (controller.isExpanded) {
          controller.collapse();
        }
      });
    });
  }

  Future<void> _fetchTasksWithErrorHandling() async {
    try {
      await Provider.of<TaskProvider>(context, listen: false).fetchTasks();
      setState(() {
        _fetchErrorMessage = null;
        print('Tasks fetched successfully');
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
      () => GlobalObjectKey(
        keyString,
      ), // Ensures a unique key instance per pageId
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
      _isScrollingFromSearch = true; // Set the flag
      _pageToScrollTo = pageId;
      _statusToExpand = status;
      _isFiltering = false; // Hide the search results overlay
      _searchController.clear(); // Clear search text to remove overlay

      // Increment scrollTrigger to ensure AllTasksView rebuilds and checks for scroll
      _scrollTrigger++;
      print(
        'TaskBoardScreen: After setState in _scrollToPageAndStatus: _pageToScrollTo = $_pageToScrollTo, _scrollTrigger = $_scrollTrigger',
      );
    });

    // If we are not already on the "All Tasks" tab (index 0), switch to it.
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
      // Clear all expansion states before expanding the target
      _pageExpandedState.clear();
      _statusExpandedState.clear();

      // Set the intended expanded state for the target page and status
      _pageExpandedState[pageId] = true;
      _statusExpandedState['status_${pageId}_${status.index}'] = true;
    });

    // Explicitly expand the page ExpansionTile
    final String pageKey = 'page_$pageId';
    final ExpansionTileController? pageController =
        _expansionTileControllers[pageKey];
    if (pageController != null && !pageController.isExpanded) {
      print('TaskBoardScreen: Expanding page tile for key: $pageKey');
      pageController.expand();
    }

    // Explicitly expand the status ExpansionTile within that page
    final String statusKey = 'status_${pageId}_${status.index}';
    final ExpansionTileController? statusController =
        _expansionTileControllers[statusKey];
    if (statusController != null && !statusController.isExpanded) {
      print('TaskBoardScreen: Expanding status tile for key: $statusKey');
      statusController.expand();
    }

    // Ensure _pageToScrollTo and _statusToExpand are nullified after successful scroll and expand
    // This is important to prevent re-triggering the scroll/expansion on subsequent rebuilds.
    setState(() {
      _pageToScrollTo = null;
      _statusToExpand = null;
      _isScrollingFromSearch =
          false; // Reset the flag once expansion is triggered
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
    // Dispose of all ExpansionTileControllers when the screen is disposed
    _expansionTileControllers.values.forEach(
      (controller) => controller.dispose(),
    );
    _expansionTileControllers.clear();
    super.dispose();
  }

  Color _getStatusColor(TaskStatus status, Brightness brightness) {
    final Map<TaskStatus, Color> baseColors = {
      TaskStatus.backlog: Colors.blueGrey,
      TaskStatus.toDiscuss: Colors.amber,
      TaskStatus.inProgress: Colors.deepPurple,
      TaskStatus.onHold: Colors.red,
      TaskStatus.complete: Colors.green,
      TaskStatus.toFollowUp: Colors.teal,
    };

    Color baseColor = baseColors[status] ?? Colors.grey;
    if (brightness == Brightness.dark) {
      return baseColor.withOpacity(0.2);
    } else {
      return baseColor;
    }
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
      ..sort((a, b) => b.compareTo(a));

    if (taskProvider.errorMessage != null) {
      return ErrorStateScreen(
        themeProvider: themeProvider,
        taskProvider: taskProvider,
        scrollToPageId: _pageToScrollTo,
        pageExpandedState: _pageExpandedState,
        fetchErrorMessage: _fetchErrorMessage,
      );
    }

    if (taskProvider.isLoading && sortedPageIds.isEmpty) {
      return buildLoadingScreen(
        context,
        themeProvider,
        taskProvider,
        _pageToScrollTo,
        _pageExpandedState,
      );
    }
    if (sortedPageIds.isEmpty && !_isFiltering) {
      return buildEmptyState(
        themeProvider,
        taskProvider,
        context,
        _pageToScrollTo,
        _pageExpandedState,
      );
    }

    final List<Tab> tabs = [
      const Tab(text: 'All Tasks'),
      ...TaskStatus.values
          .where((status) => status != TaskStatus.deleted)
          .map((status) => Tab(text: status.toApiString())),
    ];

    final List<Widget> tabViews = [
      AllTasksView(
        scrollTrigger: _scrollTrigger,
        tasksToShow: tasksToShow,
        tasksByPage: tasksByPage,
        sortedPageIds: sortedPageIds,
        getPageGlobalKey: _getPageGlobalKey,
        pageExpandedState: _pageExpandedState,
        statusExpandedState: _statusExpandedState,
        currentBrightness: currentBrightness,
        formatDate: _formatDate,
        getStatusColor: _getStatusColor,
        scrollToPageAndStatus: _scrollToPageAndStatus,
        scrollController: _scrollController,
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
              pageExpandedState: _pageExpandedState,
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
              // --- ADDED: Pass the expansionTileControllers map ---
              expansionTileControllers: _expansionTileControllers,
            ),
          ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diary Task Board'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: tabs,
            indicatorColor: Theme.of(context).colorScheme.onSurface,
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
          ),
          actions: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search tasks by title...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : const Icon(Icons.search),
                  ),
                  onChanged: (_) => _onSearchChanged(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.note_add),
              tooltip: 'Add New Page',
              onPressed: () => showAddPageDialog(
                context,
                taskProvider,
                _pageToScrollTo,
                _pageExpandedState,
              ),
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
        ),
        body: Stack(
          children: [
            TabBarView(controller: _tabController, children: tabViews),

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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final int targetPageId = await taskProvider
                .getTargetPageIdForNewTask();

            if (!mounted) return;

            showAddTaskDialog(context, targetPageId);
          },
          label: const Text('Add New Task'),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }
}
