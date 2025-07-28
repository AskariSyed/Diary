// lib/screens/tabs/all_tasks_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/widgets/task_card.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:diary_mobile/widgets/page_list_item.dart'; // Ensure this is imported

class AllTasksView extends StatelessWidget {
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
  // Add these new required parameters
  final Map<int, ExpansionTileController> pageControllers;
  final Map<String, ExpansionTileController> statusControllers;

  const AllTasksView({
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
    // Mark these as required in the constructor
    required this.pageControllers,
    required this.statusControllers,
  });

  @override
  Widget build(BuildContext context) {
    final int? mostRecentPageId = sortedPageIds.isNotEmpty
        ? sortedPageIds.first
        : null;

    return ListView.builder(
      controller: scrollController,
      itemCount: sortedPageIds.length,
      itemBuilder: (context, index) {
        final int pageId = sortedPageIds[index];
        final List<TaskDto> currentPageTasks = tasksByPage[pageId]!;
        final bool isMostRecentPage = pageId == mostRecentPageId;
        final bool isPageExpanded = pageExpandedState[pageId] ?? false;

        return PageListItem(
          key: ValueKey(pageId),
          itemKey: getPageGlobalKey(pageId),
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
}
