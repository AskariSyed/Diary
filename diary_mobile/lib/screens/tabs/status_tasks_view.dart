// lib/screens/tabs/status_tasks_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/widgets/task_card.dart';
import 'package:diary_mobile/providers/task_provider.dart';

class StatusTasksView extends StatefulWidget {
  final List<TaskDto> tasksToShow;
  final Map<int, List<TaskDto>> tasksByPage;
  final List<int> sortedPageIds;
  final GlobalKey Function(String viewPrefix, int pageId) getPageGlobalKey;
  final Map<int, bool> pageExpandedState;
  final Map<String, bool> statusExpandedState;
  final Brightness currentBrightness;
  final String Function(DateTime?) formatDate;
  final Color Function(TaskStatus, Brightness) getStatusColor;
  final Function(int, TaskStatus) scrollToPageAndStatus;
  final ScrollController scrollController;
  final int? pageToScrollTo;
  final TaskStatus? statusToExpand;
  final TaskStatus filterStatus;
  final VoidCallback? onScrollComplete;
  // --- NEW: Receive the expansionTileControllers map ---
  final Map<String, ExpansionTileController> expansionTileControllers;

  const StatusTasksView({
    super.key,
    required this.tasksToShow,
    required this.tasksByPage,
    required this.sortedPageIds,
    required this.getPageGlobalKey,
    required this.pageExpandedState,
    required this.statusExpandedState,
    required this.currentBrightness,
    required this.formatDate,
    required this.getStatusColor,
    required this.scrollToPageAndStatus,
    required this.scrollController,
    this.pageToScrollTo,
    this.statusToExpand,
    required this.filterStatus,
    this.onScrollComplete,
    required this.expansionTileControllers, // Added to constructor
  });

  @override
  State<StatusTasksView> createState() => _StatusTasksViewState();
}

class _StatusTasksViewState extends State<StatusTasksView> {
  // Local state to track if a scroll/expansion has been handled to avoid re-triggering
  int? _lastHandledPageToScrollTo;
  TaskStatus? _lastHandledStatusToExpand;

  @override
  void didUpdateWidget(covariant StatusTasksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the scroll target has changed and is not null
    // and if the current tab's filter status matches the statusToExpand
    if (widget.pageToScrollTo != null &&
        widget.statusToExpand != null &&
        (widget.pageToScrollTo != _lastHandledPageToScrollTo ||
            widget.statusToExpand != _lastHandledStatusToExpand) &&
        widget.statusToExpand == widget.filterStatus) {
      _lastHandledPageToScrollTo = widget.pageToScrollTo;
      _lastHandledStatusToExpand = widget.statusToExpand;
      final String pageKey = 'page_${widget.pageToScrollTo!}';
      final ExpansionTileController? pageController =
          widget.expansionTileControllers[pageKey];
      if (pageController != null && !pageController.isExpanded) {
        pageController.expand();
      }

      final String statusKey =
          'status_${widget.pageToScrollTo!}_${widget.statusToExpand!.index}';
      final ExpansionTileController? statusController =
          widget.expansionTileControllers[statusKey];
      if (statusController != null && !statusController.isExpanded) {
        statusController.expand();
      }
      _triggerScroll();
    }
  }

  void _triggerScroll() {
    if (widget.pageToScrollTo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final GlobalKey key = widget.getPageGlobalKey(
          'status_view_${widget.filterStatus.toApiString()}',
          widget.pageToScrollTo!,
        );
        if (key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            alignment: 0.0,
          ).then((_) {
            widget.onScrollComplete?.call();
          });
        } else {
          widget.onScrollComplete?.call();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    final List<TaskDto> filteredTasksForTab = widget.tasksToShow
        .where((task) => task.status == widget.filterStatus)
        .toList();

    final Map<int, List<TaskDto>> filteredTasksByPage = {};
    for (var task in filteredTasksForTab) {
      filteredTasksByPage.putIfAbsent(task.pageId, () => []).add(task);
    }

    final List<int> sortedFilteredPageIds = filteredTasksByPage.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    if (filteredTasksForTab.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks in "${widget.filterStatus.toApiString()}" status.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: sortedFilteredPageIds.length,
      itemBuilder: (context, index) {
        final int pageId = sortedFilteredPageIds[index];
        final List<TaskDto> currentPageTasks = filteredTasksByPage[pageId]!;
        final bool isMostRecentPage = pageId == sortedFilteredPageIds.first;

        // Ensure a controller exists for this page ExpansionTile
        final String pageKey = 'page_$pageId';
        final ExpansionTileController pageController = widget
            .expansionTileControllers
            .putIfAbsent(pageKey, () => ExpansionTileController());

        return Padding(
          key: widget.getPageGlobalKey(
            'status_view_${widget.filterStatus.toApiString()}',
            pageId,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Card(
            elevation: 6.0,
            margin: EdgeInsets.zero,
            color: Theme.of(context).cardColor,
            child: isMostRecentPage && sortedFilteredPageIds.length == 1
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Page Date: ${widget.formatDate(currentPageTasks.first.pageDate)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const Divider(height: 24, thickness: 1),
                        _buildStatusSection(
                          context,
                          taskProvider,
                          currentPageTasks,
                          widget.filterStatus,
                          isMostRecentPage,
                          widget.currentBrightness,
                          widget.statusExpandedState,
                          widget.getStatusColor,
                          widget.statusToExpand,
                          widget.expansionTileControllers, // Pass controllers
                        ),
                      ],
                    ),
                  )
                : ExpansionTile(
                    key: PageStorageKey<int>(
                      pageId,
                    ), // Retain PageStorageKey for state persistence
                    controller: pageController, // Assign the controller
                    initiallyExpanded:
                        widget.pageExpandedState[pageId] ??
                        false, // Use the map for initial state
                    onExpansionChanged: (isExpanded) {
                      setState(() {
                        widget.pageExpandedState[pageId] = isExpanded;
                      });
                    },
                    title: Text(
                      'Page Date: ${widget.formatDate(currentPageTasks.first.pageDate)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildStatusSection(
                          context,
                          taskProvider,
                          currentPageTasks,
                          widget.filterStatus,
                          isMostRecentPage,
                          widget.currentBrightness,
                          widget.statusExpandedState,
                          widget.getStatusColor,
                          widget.statusToExpand,
                          widget.expansionTileControllers, // Pass controllers
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    TaskProvider taskProvider,
    List<TaskDto> tasksOnPage,
    TaskStatus status,
    bool isMostRecentPage,
    Brightness currentBrightness,
    Map<String, bool> statusExpandedState,
    Color Function(TaskStatus, Brightness) getStatusColor,
    TaskStatus? statusToExpand,
    Map<String, ExpansionTileController>
    expansionTileControllers, // Receive controllers
  ) {
    final tasksInStatus = tasksOnPage
        .where((task) => task.status == status)
        .toList();
    final String expansionTileKey =
        'status_${tasksOnPage.first.pageId}_${status.index}';

    // Ensure a controller exists for this status ExpansionTile
    final ExpansionTileController statusController = expansionTileControllers
        .putIfAbsent(expansionTileKey, () => ExpansionTileController());

    final bool isStatusExpanded =
        statusExpandedState[expansionTileKey] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: getStatusColor(status, currentBrightness),
      elevation: 2.0,
      child: Column(
        children: [
          DragTarget<TaskDto>(
            onWillAcceptWithDetails: (data) {
              return isMostRecentPage &&
                  data.data.pageId == tasksOnPage.first.pageId &&
                  data.data.status != status;
            },
            onAcceptWithDetails: (details) async {
              final draggedTask = details.data;
              try {
                await Provider.of<TaskProvider>(
                  context,
                  listen: false,
                ).updateTaskStatus(draggedTask.id, status);
              } catch (e) {
                Future.microtask(
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update task status: $e')),
                  ),
                );
              }
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                decoration: BoxDecoration(
                  color: candidateData.isNotEmpty && isMostRecentPage
                      ? (currentBrightness == Brightness.dark
                            ? Colors.blue.withOpacity(0.4)
                            : Colors.blue.withOpacity(0.2))
                      : null,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: ExpansionTile(
                  key: PageStorageKey<String>(
                    expansionTileKey,
                  ), // Retain PageStorageKey
                  controller: statusController, // Assign the controller
                  initiallyExpanded:
                      isStatusExpanded, // Use the determined state
                  onExpansionChanged: (isExpanded) {
                    setState(() {
                      statusExpandedState[expansionTileKey] = isExpanded;
                    });
                  },
                  title: Text(
                    '${status.toApiString()} (${tasksInStatus.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: <Widget>[
                    Column(
                      children: tasksInStatus.map<Widget>((task) {
                        if (isMostRecentPage) {
                          return LongPressDraggable<TaskDto>(
                            data: task,
                            feedback: Material(
                              elevation: 8.0,
                              shadowColor: Colors.black.withOpacity(0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 2.0,
                                  ),
                                ),
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.5,
                              child: buildTaskCard(
                                task,
                                taskProvider,
                                isMostRecentPage,
                                context,
                              ),
                            ),
                            child: buildTaskCard(
                              task,
                              taskProvider,
                              isMostRecentPage,
                              context,
                            ),
                          );
                        } else {
                          return buildTaskCard(
                            task,
                            taskProvider,
                            false,
                            context,
                          );
                        }
                      }).toList(),
                    ),
                    if (tasksInStatus.isEmpty && isMostRecentPage)
                      SizedBox(
                        height: 50,
                        child: Center(
                          child: Text(
                            'Drop tasks here',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: currentBrightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
