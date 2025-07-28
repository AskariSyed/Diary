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
  final Function(DateTime?) formatDate;
  final Color Function(TaskStatus, Brightness) getStatusColor;
  final Map<int, bool>
  pageExpandedState; // Still kept for general UI state tracking if needed
  final Map<String, bool>
  statusExpandedState; // Still kept for general UI state tracking if needed
  final Brightness currentBrightness;
  final TaskStatus? statusToExpand; // Still useful for initial setup logic

  // --- NEW: Receive the map of ExpansionTileControllers ---
  final Map<String, ExpansionTileController> expansionTileControllers;

  const PageListItem({
    super.key,
    required this.pageId,
    required this.currentPageTasks,
    required this.isMostRecentPage,
    // Removed isPageExpanded as its state will be managed by controller
    required this.formatDate,
    required this.getStatusColor,
    required this.pageExpandedState,
    required this.statusExpandedState,
    required this.currentBrightness,
    this.statusToExpand,
    required this.expansionTileControllers, // Add to constructor
  });

  @override
  State<PageListItem> createState() => _PageListItemState();
}

class _PageListItemState extends State<PageListItem> {
  // We no longer need this didUpdateWidget logic here for expansion.
  // The expansion is now directly triggered by the controller from TaskBoardScreen.
  // @override
  // void didUpdateWidget(covariant PageListItem oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //   if (widget.pageId == widget.pageExpandedState[widget.pageId] &&
  //       widget.statusToExpand != null &&
  //       widget.isPageExpanded) { // isPageExpanded is gone now
  //     final String statusKey =
  //         'page_${widget.pageId}_status_${widget.statusToExpand!.index}';
  //     if (!(widget.statusExpandedState[statusKey] ?? false)) {
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         if (mounted) {
  //           setState(() {
  //             widget.statusExpandedState[statusKey] = true;
  //           });
  //         }
  //       });
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    Widget pageContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: TaskStatus.values.where((status) => status != TaskStatus.deleted).map((
        status,
      ) {
        final tasksInStatus = widget.currentPageTasks
            .where((task) => task.status == status)
            .toList();
        final String statusExpansionTileKey =
            'status_${widget.pageId}_${status.index}'; // Unique key for status tile

        // --- NEW: Get or create the ExpansionTileController for this status section ---
        final ExpansionTileController statusController = widget
            .expansionTileControllers
            .putIfAbsent(
              statusExpansionTileKey,
              () => ExpansionTileController(),
            );

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
                      color: candidateData.isNotEmpty && widget.isMostRecentPage
                          ? (widget.currentBrightness == Brightness.dark
                                ? Colors.blue.withOpacity(0.4)
                                : Colors.blue.withOpacity(0.2))
                          : null,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: ExpansionTile(
                      key: PageStorageKey<String>(statusExpansionTileKey),
                      // --- NEW: Assign the controller here ---
                      controller: statusController,
                      // Remove initiallyExpanded and let the controller manage it
                      // initiallyExpanded: widget.statusExpandedState[statusExpansionTileKey] ?? false,
                      onExpansionChanged: (isExpanded) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            // Update the state map for consistency if needed,
                            // but the controller now drives the actual expansion.
                            widget.statusExpandedState[statusExpansionTileKey] =
                                isExpanded;
                          }
                        });
                      },
                      title: Text(
                        '${status.toApiString()} (${tasksInStatus.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: <Widget>[
                        Column(
                          children: tasksInStatus.map<Widget>((task) {
                            if (widget.isMostRecentPage) {
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
                        if (tasksInStatus.isEmpty && widget.isMostRecentPage)
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
      }).toList(),
    );

    // --- NEW: Key for the page ExpansionTile ---
    final String pageExpansionTileKey = 'page_${widget.pageId}';

    // --- NEW: Get or create the ExpansionTileController for this page ---
    final ExpansionTileController pageController = widget
        .expansionTileControllers
        .putIfAbsent(pageExpansionTileKey, () => ExpansionTileController());

    return Padding(
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
                key: PageStorageKey<int>(
                  widget.pageId,
                ), // Keep PageStorageKey for state restoration on scroll
                // --- NEW: Assign the controller here ---
                controller: pageController,
                // Remove initiallyExpanded and let the controller manage it
                // initiallyExpanded: widget.isPageExpanded,
                onExpansionChanged: (isExpanded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      // Update the state map for consistency if needed,
                      // but the controller now drives the actual expansion.
                      widget.pageExpandedState[widget.pageId] = isExpanded;
                    }
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
