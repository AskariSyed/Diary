// lib/screens/tabs/all_tasks_view.dart
import 'package:flutter/material.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/widgets/page_list_item.dart'; // Import PageListItem

class AllTasksView extends StatefulWidget {
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
  final VoidCallback? onScrollComplete;
  final int scrollTrigger;
  final Function(int pageId, TaskStatus status) onScrollAndExpand;
  // --- NEW: Add expansionTileControllers to the constructor ---
  final Map<String, ExpansionTileController> expansionTileControllers;

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
    this.pageToScrollTo,
    this.statusToExpand,
    this.onScrollComplete,
    required this.scrollTrigger,
    required this.onScrollAndExpand,
    // --- NEW: Require expansionTileControllers ---
    required this.expansionTileControllers,
  });

  @override
  State<AllTasksView> createState() => _AllTasksViewState();
}

class _AllTasksViewState extends State<AllTasksView> {
  int _scrollAttemptCount = 0;
  static const int _maxScrollAttempts = 5; // Limit attempts

  @override
  void didUpdateWidget(covariant AllTasksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('AllTasksView: didUpdateWidget called.');
    print(
      'AllTasksView: oldWidget.scrollTrigger: ${oldWidget.scrollTrigger}, widget.scrollTrigger: ${widget.scrollTrigger}',
    );
    print(
      'AllTasksView: oldWidget.pageToScrollTo: ${oldWidget.pageToScrollTo}, widget.pageToScrollTo: ${widget.pageToScrollTo}',
    );
    print(
      'AllTasksView: oldWidget.statusToExpand: ${oldWidget.statusToExpand}, widget.statusToExpand: ${widget.statusToExpand}',
    );

    if (widget.pageToScrollTo != null &&
        (widget.pageToScrollTo != oldWidget.pageToScrollTo ||
            widget.statusToExpand != oldWidget.statusToExpand ||
            widget.scrollTrigger != oldWidget.scrollTrigger)) {
      print(
        "AllTasksView: Condition met: Triggering scroll with pageToScrollTo: ${widget.pageToScrollTo}.",
      );
      _scrollAttemptCount = 0; // Reset attempt count for a new scroll request
      _attemptScroll();
    } else {
      print("AllTasksView: Condition NOT met.");
    }
  }

  void _attemptScroll() {
    if (_scrollAttemptCount >= _maxScrollAttempts) {
      print(
        "AllTasksView: Max scroll attempts reached. Cannot find context for page ${widget.pageToScrollTo}.",
      );
      widget.onScrollComplete?.call();
      return;
    }

    if (widget.pageToScrollTo == null) {
      print(
        "AllTasksView: _attemptScroll() called but widget.pageToScrollTo is null. Aborting.",
      );
      widget.onScrollComplete?.call();
      return;
    }

    _scrollAttemptCount++;
    print(
      "AllTasksView: Attempting scroll to page ${widget.pageToScrollTo}, attempt #$_scrollAttemptCount",
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final GlobalKey key = widget.getPageGlobalKey(
        "all_tasks",
        widget.pageToScrollTo!,
      );

      if (key.currentContext != null) {
        print(
          "AllTasksView: GlobalKey context found for page ${widget.pageToScrollTo}. Ensuring visible.",
        );
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.0,
        ).then((_) {
          print(
            "AllTasksView: Scroll complete for page ${widget.pageToScrollTo}. Calling onScrollAndExpand and onScrollComplete.",
          );
          // --- CRITICAL: Call the onScrollAndExpand callback here ---
          if (widget.pageToScrollTo != null && widget.statusToExpand != null) {
            widget.onScrollAndExpand(
              widget.pageToScrollTo!,
              widget.statusToExpand!,
            );
          }
          // Call onScrollComplete to clear scrolling flags in TaskBoardScreen
          widget.onScrollComplete?.call();
        });
      } else {
        print(
          "AllTasksView: GlobalKey context NOT found for page ${widget.pageToScrollTo} on attempt #$_scrollAttemptCount. Retrying...",
        );
        _attemptScroll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final int? mostRecentPageId = widget.sortedPageIds.isNotEmpty
        ? widget.sortedPageIds.first
        : null;

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: widget.sortedPageIds.length,
      cacheExtent: 10000,
      itemBuilder: (context, index) {
        final int pageId = widget.sortedPageIds[index];
        final List<TaskDto> currentPageTasks = widget.tasksByPage[pageId]!;
        final bool isMostRecentPage = pageId == mostRecentPageId;

        return PageListItem(
          key: widget.getPageGlobalKey(
            'all_tasks',
            pageId,
          ), // Keep GlobalKey for scrolling
          pageId: pageId,
          formatDate: widget.formatDate,
          currentPageTasks: currentPageTasks,
          isMostRecentPage: isMostRecentPage,
          getStatusColor: widget.getStatusColor,
          pageExpandedState: widget
              .pageExpandedState, // Keep for initial state/manual expansion tracking
          statusExpandedState: widget
              .statusExpandedState, // Keep for initial state/manual expansion tracking
          currentBrightness: widget.currentBrightness,
          statusToExpand: widget
              .statusToExpand, // Still useful for context within PageListItem
          // --- NEW: Pass the expansionTileControllers down ---
          expansionTileControllers: widget.expansionTileControllers,
        );
      },
    );
  }
}
