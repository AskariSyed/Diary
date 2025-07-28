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
  final Map<String, bool> _statusExpandedState = {};
  final Map<int, bool> _pageExpandedState = {};
  final ScrollController _scrollController = ScrollController();
  String? _fetchErrorMessage;

  int? _pageToScrollTo;
  TaskStatus? _statusToExpand;

  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;
  List<TaskDto> _filteredTasks = [];
  bool _isFiltering = false;

  late TabController _tabController;

  // New: Maps to hold ExpansionTileControllers
  final Map<int, ExpansionTileController> _pageControllers = {};
  final Map<String, ExpansionTileController> _statusControllers = {};

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
        setState(() {
          // Clear scroll and expansion targets when tab changes
          _pageToScrollTo = null;
          _statusToExpand = null;
          // Optionally collapse all expansions when changing tabs, but use controllers
          _collapseAllTiles(); // New method to explicitly collapse via controllers
        });
      }
    });
  }

  void _collapseAllTiles() {
    // Collapse all page tiles
    _pageControllers.values.forEach((controller) {
      if (controller.isExpanded) controller.collapse();
    });
    // Collapse all status tiles
    _statusControllers.values.forEach((controller) {
      if (controller.isExpanded) controller.collapse();
    });
    // Also clear the state maps to keep them in sync
    _pageExpandedState.clear();
    _statusExpandedState.clear();
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
      _pageToScrollTo = null;
      _statusToExpand = null;
      // Also clear expansions when search is cleared, and collapse via controllers
      _collapseAllTiles(); // Use the new collapse method
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

  GlobalKey _getPageGlobalKey(int pageId) {
    return GlobalObjectKey(pageId);
  }

  void _scrollToPageAndStatus(int pageId, TaskStatus status) {
    // Ensure all tiles are collapsed before expanding the target ones
    // This provides a clean slate and avoids multiple open tiles by mistake
    _collapseAllTiles(); // Important!

    // 1. Switch to "All Tasks" tab
    _tabController.animateTo(0);

    // 2. Update the expansion states (these will be read by PageListItem's didUpdateWidget)
    setState(() {
      _pageToScrollTo = pageId;
      _statusToExpand = status;
      _pageExpandedState[pageId] = true; // Mark page as expanded
      // Mark status as expanded
      _statusExpandedState['page_${pageId}_status_${status.index}'] = true;
    });

    // 3. Wait for the next frame to ensure the widgets are built with expanded state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Find or create the controllers for the target page and status
      final pageController = _pageControllers.putIfAbsent(
        pageId,
        () => ExpansionTileController(),
      );
      final statusController = _statusControllers.putIfAbsent(
        'page_${pageId}_status_${status.index}',
        () => ExpansionTileController(),
      );

      // Programmatically expand the tiles
      if (!pageController.isExpanded) {
        pageController.expand();
      }
      if (!statusController.isExpanded) {
        statusController.expand();
      }

      final GlobalKey key = _getPageGlobalKey(pageId);
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          // Adjust alignment if needed; 0.0 is top, 1.0 is bottom, 0.5 is center
          alignment: 0.05, // A little offset from the very top
        );
      }
      // 4. Clear the scroll/expansion targets after scrolling is initiated
      // This prevents re-scrolling/re-expanding on subsequent rebuilds
      setState(() {
        _pageToScrollTo = null;
        _statusToExpand = null;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    // Dispose all controllers to prevent memory leaks
    _pageControllers.values.forEach((controller) => controller.dispose());
    _statusControllers.values.forEach((controller) => controller.dispose());
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

    // Ensure controllers exist for all current pages and statuses that might be displayed
    for (int pageId in sortedPageIds) {
      _pageControllers.putIfAbsent(pageId, () => ExpansionTileController());
      for (var status in TaskStatus.values.where(
        (s) => s != TaskStatus.deleted,
      )) {
        final String expansionTileKey = 'page_${pageId}_status_${status.index}';
        _statusControllers.putIfAbsent(
          expansionTileKey,
          () => ExpansionTileController(),
        );
      }
    }

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
          .map((status) => Tab(text: status.toApiString()))
          .toList(),
    ];

    final List<Widget> tabViews = [
      AllTasksView(
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
        pageControllers: _pageControllers, // Pass controllers
        statusControllers: _statusControllers, // Pass controllers
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
              pageControllers: _pageControllers, // Pass controllers
              statusControllers: _statusControllers, // Pass controllers
            ),
          )
          .toList(),
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
                    fillColor: Theme.of(context).colorScheme.surfaceVariant,
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
                                  _clearSearch();
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
