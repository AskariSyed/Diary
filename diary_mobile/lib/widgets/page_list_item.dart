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

  final Map<int, bool>? pageExpandedState;
  final Map<String, bool> statusExpandedState;
  final Brightness currentBrightness;
  final TaskStatus? statusToExpand;
  final int? pageToScrollTo;

  const PageListItem({
    super.key,
    required this.pageId,
    required this.currentPageTasks,
    required this.isMostRecentPage,
    required this.formatDate,
    required this.getStatusColor,
    this.pageExpandedState,
    required this.statusExpandedState,
    required this.currentBrightness,
    this.statusToExpand,
    this.pageToScrollTo,
  });

  @override
  State<PageListItem> createState() => _PageListItemState();
}

class _PageListItemState extends State<PageListItem> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant PageListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    final pageDate = widget.currentPageTasks.isNotEmpty
        ? widget.currentPageTasks.first.pageDate
        : null;

    final today = DateTime.now();
    final bool isTodayOrFuture =
        pageDate != null &&
        (pageDate.year > today.year ||
            (pageDate.year == today.year &&
                (pageDate.month > today.month ||
                    (pageDate.month == today.month &&
                        pageDate.day >= today.day))));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: 6.0,
        margin: EdgeInsets.zero,
        color: Theme.of(context).cardColor,
        child: Column(
          // Use Column directly as the child of Card
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '${widget.formatDate(pageDate)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const Divider(height: 24, thickness: 1),
            Expanded(
              child: Padding(
                // Keep padding if desired
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildScrollablePageContent(
                  isTodayOrFuture,
                  taskProvider,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollablePageContent(
    bool isTodayOrFuture,
    TaskProvider taskProvider,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: TaskStatus.values
                .where((status) => status != TaskStatus.deleted)
                .map((status) {
                  final tasksInStatus = widget.currentPageTasks
                      .where((task) => task.status == status)
                      .toList();
                  final String statusExpansionTileKey =
                      'status_${widget.pageId}_${status.index}';
                  final bool initialStatusExpanded =
                      (widget.statusExpandedState[statusExpansionTileKey] ??
                          false) ||
                      (widget.pageToScrollTo == widget.pageId &&
                          widget.statusToExpand == status);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    color: widget.getStatusColor(
                      status,
                      widget.currentBrightness,
                    ),
                    elevation: 2.0,
                    child: Column(
                      children: [
                        DragTarget<TaskDto>(
                          onWillAcceptWithDetails: (data) {
                            return isTodayOrFuture &&
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
                                () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to update task status: $e',
                                        ),
                                      ),
                                    ),
                              );
                            }
                          },
                          builder: (context, candidateData, rejectedData) {
                            return Container(
                              decoration: BoxDecoration(
                                color:
                                    candidateData.isNotEmpty && isTodayOrFuture
                                    ? (widget.currentBrightness ==
                                              Brightness.dark
                                          ? Colors.blue.withOpacity(0.4)
                                          : Colors.blue.withOpacity(0.2))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: ExpansionTile(
                                title: Text(
                                  '${status.toApiString()} (${tasksInStatus.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                initiallyExpanded: initialStatusExpanded,
                                children: <Widget>[
                                  Column(
                                    children: tasksInStatus.map<Widget>((task) {
                                      return buildTaskCard(
                                        task,
                                        taskProvider,
                                        isTodayOrFuture,
                                        context,
                                      );
                                    }).toList(),
                                  ),
                                  if (tasksInStatus.isEmpty && isTodayOrFuture)
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
          ),
        );
      },
    );
  }
}
