import 'dart:math' as m;

import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/screens/tabs/all_tasks_view.dart';
import 'package:diary_mobile/widgets/page_list_item.dart';
import 'package:flutter/material.dart';

class PageViewBuilder extends StatelessWidget {
  const PageViewBuilder({
    super.key,
    required PageController pageController,
    required this.widget,
    required this.onPageChanged,
  }) : _pageController = pageController;

  final PageController _pageController;
  final AllTasksView widget;
  final ValueChanged<int> onPageChanged;
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: onPageChanged,
      itemCount: widget.sortedPageIds.length,
      itemBuilder: (context, index) {
        final int pageId = widget.sortedPageIds[index];
        final List<TaskDto> allPageTasks = widget.tasksByPage[pageId] ?? [];
        final List<TaskDto> currentPageTasks = allPageTasks
            .where((t) => t.status != TaskStatus.deleted)
            .toList();
        final DateTime? pageDate = widget.pageDatesById[pageId];
        final bool isMostRecentPage =
            pageId ==
            (widget.sortedPageIds.isNotEmpty
                ? widget.sortedPageIds.first
                : null);

        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double rotationY = 0.0;
            double scale = 1.0;
            double opacity = 1.0;

            if (_pageController.hasClients &&
                _pageController.position.haveDimensions) {
              num pageOffset =
                  (_pageController.page ?? _pageController.initialPage) - index;
              num clampedOffset = pageOffset.clamp(-1.0, 1.0);

              if (clampedOffset.abs() > 0.001) {
                rotationY = clampedOffset * (m.pi);
              } else {
                rotationY = 0.0;
              }

              scale = (1 - (clampedOffset.abs() * 0.1)).clamp(0.9, 1.0);
              opacity = (1 - clampedOffset.abs() * 0.3).clamp(0.1, 1.0);
            }

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(rotationY)
                ..scale(scale),
              child: Opacity(
                opacity: opacity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
                  child: PageListItem(
                    key: ValueKey('all_tasks-$pageId'),
                    pageId: pageId,
                    pageDate: pageDate,
                    formatDate: widget.formatDate,
                    currentPageTasks: currentPageTasks,
                    isMostRecentPage: isMostRecentPage,
                    getStatusColor: widget.getStatusColor,
                    statusExpandedState: widget.statusExpandedState,
                    currentBrightness: widget.currentBrightness,
                    statusToExpand: widget.statusToExpand,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
