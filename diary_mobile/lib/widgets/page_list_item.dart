import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:diary_mobile/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
  // Declare a ScrollController for this instance
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    // Initialize the controller
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    // Dispose of the controller
    _scrollController.dispose();
    super.dispose();
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

    final bool isTodayOrFuture =
        pageDate != null &&
        !pageDate.isBefore(DateUtils.dateOnly(DateTime.now()));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: 6.0,
        margin: EdgeInsets.zero,
        color: Theme.of(context).cardColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    '${widget.formatDate(pageDate)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      // HERE IS THE CHANGE:
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        _showDatePickerAndCopyTasks(context, pageDate),
                    icon: const Icon(Icons.move_to_inbox),
                    tooltip: 'Copy tasks from another day',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: Padding(
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

  Future<void> _showDatePickerAndCopyTasks(
    BuildContext context,
    DateTime? targetPageDate,
  ) async {
    if (targetPageDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Target page date is not available.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    DateTime? selectedSourceDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 1)),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
      // Cannot copy from a future date
      helpText: 'Select date to copy tasks from',
      fieldLabelText: 'Source Date',
    );
    if (selectedSourceDate == null) {
      return;
    }

    selectedSourceDate = DateUtils.dateOnly(selectedSourceDate);
    final DateTime cleanTargetDate = DateUtils.dateOnly(targetPageDate);

    if (selectedSourceDate.isAtSameMomentAs(cleanTargetDate)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot copy tasks to the same day.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool? confirmCopy = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Task Copy'),
        content: Text(
          'Are you sure you want to copy all uncompleted and undeleted tasks from '
          '${widget.formatDate(selectedSourceDate)} to ' // Use the selected source date directly
          '${widget.formatDate(cleanTargetDate)}?', // Use the clean target date
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Copy'),
          ),
        ],
      ),
    );

    if (confirmCopy != true) {
      return;
    }

    try {
      await taskProvider.copyPageTasks(
        sourceDate: selectedSourceDate,
        targetDate: cleanTargetDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tasks successfully copied from ${widget.formatDate(selectedSourceDate)}!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      taskProvider.fetchTasks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy tasks: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildScrollablePageContent(
    bool isTodayOrFuture,
    TaskProvider taskProvider,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollController,
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
                            return data.data.pageId == widget.pageId &&
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
                                        true,
                                        context,
                                      );
                                    }).toList(),
                                  ),
                                  if (tasksInStatus.isEmpty)
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
