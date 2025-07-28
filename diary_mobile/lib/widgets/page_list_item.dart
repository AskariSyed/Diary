// lib/widgets/page_list_item.dart
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:diary_mobile/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PageListItem extends StatefulWidget {
  final int pageId;
  final List<TaskDto> currentPageTasks;
  final bool isMostRecentPage;
  final bool isPageExpanded;
  final Function(DateTime?) formatDate;
  final Color Function(TaskStatus, Brightness) getStatusColor;
  final Map<int, bool> pageExpandedState;
  final Map<String, bool> statusExpandedState;
  final Brightness currentBrightness;
  final GlobalKey? itemKey; // Make it nullable here!

  // NEW: Add ExpansionTileController parameters
  final ExpansionTileController?
  pageController; // The controller for this specific PageListItem
  final Map<String, ExpansionTileController>
  statusControllers; // The map of all status controllers

  const PageListItem({
    super.key,
    required this.pageId,
    required this.currentPageTasks,
    required this.isMostRecentPage,
    required this.isPageExpanded,
    required this.formatDate,
    required this.getStatusColor,
    required this.pageExpandedState,
    required this.statusExpandedState,
    required this.currentBrightness,
    this.itemKey, // Remove 'required'
    // NEW: Mark controllers as required in the constructor
    this.pageController, // Nullable, as not every PageListItem needs a dedicated one if it's always collapsed
    required this.statusControllers, // Required, as this map holds controllers for all statuses
  });

  @override
  State<PageListItem> createState() => _PageListItemState();
}

class _PageListItemState extends State<PageListItem> {
  late ExpansionTileController _pageTileController;
  // This map will hold references to the controllers from the main TaskBoardScreen
  // We don't create new controllers here, just look them up from the passed map.
  // We can remove the local _statusTileControllers map if we directly use widget.statusControllers

  @override
  void initState() {
    super.initState();
    // Initialize the page controller. Use the one passed from parent if available,
    // otherwise, create a new one (though in this design, it should always be passed).
    _pageTileController = widget.pageController ?? ExpansionTileController();
  }

  @override
  void didUpdateWidget(covariant PageListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Logic to expand/collapse based on external state (e.g., search results)
    // The main TaskBoardScreen will call expand() on the controllers directly,
    // but this ensures consistency if the state is just set.
    if (widget.pageExpandedState[widget.pageId] == true &&
        !_pageTileController.isExpanded) {
      _pageTileController.expand();
    } else if (widget.pageExpandedState[widget.pageId] == false &&
        _pageTileController.isExpanded) {
      _pageTileController.collapse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    // Group tasks by status for the current page
    final Map<TaskStatus, List<TaskDto>> tasksByStatus = {};
    for (var task in widget.currentPageTasks) {
      tasksByStatus.putIfAbsent(task.status, () => []).add(task);
    }

    final List<TaskStatus> sortedStatuses = tasksByStatus.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    // Content of the page (status tiles)
    Widget pageContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedStatuses
          .where(
            (status) => status != TaskStatus.deleted,
          ) // Ensure deleted tasks are not shown
          .map((status) {
            final tasksInStatus = widget.currentPageTasks
                .where((task) => task.status == status)
                .toList();
            final String expansionTileKey =
                'page_${widget.pageId}_status_${status.index}';

            // Retrieve the controller for this specific status tile from the passed map
            // Ensure it exists (TaskBoardScreen is responsible for creating them)
            final ExpansionTileController statusTileController =
                widget.statusControllers[expansionTileKey] ??
                ExpansionTileController(); // Fallback in case not found, but should be found

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              color: widget.getStatusColor(status, widget.currentBrightness),
              elevation: 2.0,
              child: Column(
                children: [
                  DragTarget<TaskDto>(
                    onWillAcceptWithDetails: (data) {
                      return widget.isMostRecentPage &&
                          data.data.pageId == widget.pageId &&
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
                            SnackBar(
                              content: Text('Failed to update task status: $e'),
                            ),
                          ),
                        );
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        decoration: BoxDecoration(
                          color:
                              candidateData.isNotEmpty &&
                                  widget.isMostRecentPage
                              ? (widget.currentBrightness == Brightness.dark
                                    ? Colors.blue.withOpacity(0.4)
                                    : Colors.blue.withOpacity(0.2))
                              : null,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: ExpansionTile(
                          controller:
                              statusTileController, // Assign the controller!
                          key: PageStorageKey<String>(
                            expansionTileKey,
                          ), // Keep PageStorageKey for persistence
                          // remove 'initiallyExpanded' as controller handles it
                          onExpansionChanged: (isExpanded) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              widget.statusExpandedState[expansionTileKey] =
                                  isExpanded;
                            });
                          },
                          title: Text(
                            '${status.toApiString()} (${tasksInStatus.length})',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: widget.currentBrightness == Brightness.dark
                                  ? Colors
                                        .white // Dark text for dark theme card
                                  : Colors
                                        .black, // Black text for light theme card
                            ),
                          ),
                          children: <Widget>[
                            Column(
                              children: tasksInStatus.map<Widget>((task) {
                                if (widget.isMostRecentPage) {
                                  return LongPressDraggable<TaskDto>(
                                    data: task,
                                    feedback: Material(
                                      elevation: 8.0,
                                      shadowColor: Colors.black.withOpacity(
                                        0.6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.0,
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(12.0),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            12.0,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
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
                                        widget.isMostRecentPage,
                                        context,
                                      ),
                                    ),
                                    child: buildTaskCard(
                                      task,
                                      taskProvider,
                                      widget.isMostRecentPage,
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
                            if (tasksInStatus.isEmpty &&
                                widget.isMostRecentPage)
                              SizedBox(
                                height: 50,
                                child: Center(
                                  child: Text(
                                    'Drop tasks here',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color:
                                          widget.currentBrightness ==
                                              Brightness.dark
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
          })
          .toList(),
    );

    return Padding(
      key: widget.itemKey, // This is for scrolling to a specific page
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: 6.0,
        margin: EdgeInsets.zero,
        color: Theme.of(context).cardColor,
        child: widget.isMostRecentPage
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Page Date: ${widget.formatDate(widget.currentPageTasks.first.pageDate)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Divider(height: 24, thickness: 1),
                    pageContent,
                  ],
                ),
              )
            : ExpansionTile(
                controller:
                    _pageTileController, // Assign the controller for the page tile
                key: PageStorageKey<int>(
                  widget.pageId,
                ), // Keep PageStorageKey for persistence
                // remove 'initiallyExpanded' as controller handles it
                onExpansionChanged: (isExpanded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.pageExpandedState[widget.pageId] = isExpanded;
                  });
                },
                title: Text(
                  'Page Date: ${widget.formatDate(widget.currentPageTasks.first.pageDate)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: pageContent,
                  ),
                ],
              ),
      ),
    );
  }
}
