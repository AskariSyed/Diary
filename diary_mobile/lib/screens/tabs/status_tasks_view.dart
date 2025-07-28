// lib/screens/tabs/status_tasks_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/widgets/task_card.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:diary_mobile/widgets/page_list_item.dart'; // Ensure this is imported

class StatusTasksView extends StatelessWidget {
  final List<TaskDto> tasksToShow;
  final Map<int, List<TaskDto>> tasksByPage;
  final List<int> sortedPageIds;
  final GlobalKey Function(int pageId) getPageGlobalKey;
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
  // Add these new required parameters for ExpansionTileControllers
  final Map<int, ExpansionTileController> pageControllers;
  final Map<String, ExpansionTileController> statusControllers;

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
    required this.pageToScrollTo,
    required this.statusToExpand,
    required this.filterStatus,
    // Mark these as required in the constructor
    required this.pageControllers,
    required this.statusControllers,
  });

  @override
  Widget build(BuildContext context) {
    final List<TaskDto> filteredTasksForTab = tasksToShow
        .where((task) => task.status == filterStatus)
        .toList();

    final Map<int, List<TaskDto>> filteredTasksByPage = {};
    for (var task in filteredTasksForTab) {
      filteredTasksByPage.putIfAbsent(task.pageId, () => []).add(task);
    }

    final List<int> sortedFilteredPageIds = filteredTasksByPage.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    if (filteredTasksForTab.isEmpty) {
      return Center(
        child: Text(
          'No tasks found for ${filterStatus.toApiString()}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return ListView.builder(
      // CRITICAL: We don't need a scrollController for these non-primary lists
      // as scrolling is handled by switching to 'All Tasks'.
      // If you DID need independent scrolling per tab, you'd need unique controllers.
      // controller: scrollController, // Consider removing this if not needed for independent scrolling
      itemCount: sortedFilteredPageIds.length,
      itemBuilder: (context, index) {
        final int pageId = sortedFilteredPageIds[index];
        final List<TaskDto> currentPageTasks = filteredTasksByPage[pageId]!;
        final bool isMostRecentPage = pageId == sortedFilteredPageIds.first;
        final bool isPageExpanded = pageExpandedState[pageId] ?? false;

        return PageListItem(
          // REMOVE itemKey: getPageGlobalKey(pageId),
          // We only need the GlobalKey on the PageListItem in AllTasksView
          // because that's where we scroll.
          // Providing it here causes duplicates when the same pageId exists in both.
          key: ValueKey(
            pageId,
          ), // Keep ValueKey for ListView.builder's internal item management
          pageId: pageId,
          currentPageTasks: currentPageTasks,
          isMostRecentPage: isMostRecentPage,
          isPageExpanded: isPageExpanded,
          formatDate: formatDate,
          getStatusColor: getStatusColor,
          pageExpandedState: pageExpandedState,
          statusExpandedState: statusExpandedState,
          currentBrightness: currentBrightness,
          // Pass the controllers here!
          pageController: pageControllers[pageId],
          statusControllers: statusControllers,
        );
      },
    );
  }

  // The _buildStatusSection method is not part of the StatelessWidget's build method
  // and is likely a helper function defined elsewhere or intended to be
  // integrated into the PageListItem widget itself.
  // It should NOT be directly inside StatusTasksView's StatelessWidget class
  // as it is currently structured. PageListItem already handles this internal structure.
  // I'm omitting it from this corrected code block to avoid confusion,
  // as it was likely a leftover or misplaced snippet from previous iterations.
  // Ensure that the logic for building status sections is solely within PageListItem.
}
