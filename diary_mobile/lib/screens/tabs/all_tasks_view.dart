import 'package:flutter/material.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/widgets/page_list_item.dart';
import 'package:intl/intl.dart';
import 'dart:math' as M;

abstract class ExpansibleController extends ChangeNotifier {
  bool get isExpanded;
  void expand();
  void collapse();
  void toggle();
}

class AllTasksView extends StatefulWidget {
  String myFormatDateFunction(DateTime? date) {
    if (date == null) {
      return 'N/A';
    }
    return DateFormat('MMM dd').format(date);
  }

  final List<TaskDto> tasksToShow;
  final Map<int, List<TaskDto>> tasksByPage;
  final List<int> sortedPageIds;
  final GlobalKey Function(String viewPrefix, int pageId) getPageGlobalKey;
  final Map<String, bool> statusExpandedState;
  final Brightness currentBrightness;
  final String Function(DateTime?) formatDate;
  final Color Function(TaskStatus, Brightness) getStatusColor;
  final Function(int, TaskStatus) scrollToPageAndStatus;
  final int? pageToScrollTo;
  final TaskStatus? statusToExpand;
  final VoidCallback? onScrollComplete;
  final int scrollTrigger;
  final Function(int pageId, TaskStatus status) onScrollAndExpand;
  final Map<String, dynamic> expansionTileControllers;

  const AllTasksView({
    super.key,
    required this.tasksToShow,
    required this.tasksByPage,
    required this.sortedPageIds,
    required this.getPageGlobalKey,
    required this.statusExpandedState,
    required this.currentBrightness,
    required this.formatDate,
    required this.getStatusColor,
    required this.scrollToPageAndStatus,
    this.pageToScrollTo,
    this.statusToExpand,
    this.onScrollComplete,
    required this.scrollTrigger,
    required this.onScrollAndExpand,
    required this.expansionTileControllers,
  });

  @override
  State<AllTasksView> createState() => _AllTasksViewState();
}

class _AllTasksViewState extends State<AllTasksView> {
  late PageController _pageController;
  late ScrollController _pageIndicatorScrollController;
  int _currentPageIndex = 0;
  static const double _kPageIndicatorHeight = 60.0;
  static const double _kIndividualIndicatorWidth = 30.0 + (4.0 * 2);
  static const double _kVisibleIndicatorBarWidth = 240.0;
  bool _isAnimatingPageController = false;
  bool _isAnimatingIndicatorController = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageIndicatorScrollController = ScrollController();
    _handleInitialScroll();
    _pageController.addListener(() {
      if (_pageController.page != null && !_isAnimatingPageController) {
        int newPageIndex = _pageController.page!.round();
        if (_currentPageIndex != newPageIndex) {
          setState(() {
            _currentPageIndex = newPageIndex;
          });
          _isAnimatingIndicatorController = true;
          _scrollToCenterIndicator(newPageIndex).then((_) {
            _isAnimatingIndicatorController = false;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant AllTasksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollTrigger != oldWidget.scrollTrigger &&
        widget.pageToScrollTo != null) {
      print(
        'AllTasksView: didUpdateWidget triggered scroll for page: ${widget.pageToScrollTo}',
      );
      print(
        'AllTasksView: Current sortedPageIds in didUpdateWidget: ${widget.sortedPageIds}',
      );
      _handleScrollToPage();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageIndicatorScrollController.dispose();
    super.dispose();
  }

  void _handleInitialScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.pageToScrollTo != null && mounted) {
        final int targetIndex = widget.sortedPageIds.indexOf(
          widget.pageToScrollTo!,
        );
        print(
          'AllTasksView: Initial scroll request for page: ${widget.pageToScrollTo}, calculated targetIndex: $targetIndex',
        );
        print(
          'AllTasksView: Current sortedPageIds in _handleInitialScroll: ${widget.sortedPageIds}',
        );

        if (targetIndex != -1) {
          if (_currentPageIndex != targetIndex) {
            _scrollToPageAndExpand(
              widget.pageToScrollTo!,
              widget.statusToExpand,
            );
          } else if (widget.statusToExpand != null) {
            widget.onScrollAndExpand(
              widget.pageToScrollTo!,
              widget.statusToExpand!,
            );
            widget.onScrollComplete?.call();
          }
        } else {
          print(
            'AllTasksView: Initial scroll target page ${widget.pageToScrollTo} not found in sortedPageIds.',
          );
          widget.onScrollComplete?.call();
        }
      }
    });
  }

  void _handleScrollToPage() {
    if (widget.pageToScrollTo != null && mounted) {
      _scrollToPageAndExpand(widget.pageToScrollTo!, widget.statusToExpand);
    }
  }

  void _scrollToPageAndExpand(int pageId, TaskStatus? statusToExpand) {
    print('AllTasksView: _scrollToPageAndExpand called for page $pageId');
    print('AllTasksView: Current sortedPageIds: ${widget.sortedPageIds}');
    final int pageIndex = widget.sortedPageIds.indexOf(pageId);
    print('AllTasksView: Calculated pageIndex for $pageId is $pageIndex');

    if (pageIndex != -1) {
      if (_currentPageIndex == pageIndex) {
        print(
          'AllTasksView: Already on target page $pageId (index $pageIndex). Skipping PageView animation.',
        );
        if (statusToExpand != null) {
          widget.onScrollAndExpand(pageId, statusToExpand);
        }
        widget.onScrollComplete?.call();
        return;
      }

      print(
        'AllTasksView: Page $pageId found at index $pageIndex. Scrolling PageView...',
      );
      print(
        'AllTasksView: _currentPageIndex before animation: $_currentPageIndex',
      );

      _isAnimatingPageController = true;
      _pageController
          .animateToPage(
            pageIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInToLinear,
          )
          .then((_) {
            _isAnimatingPageController = false;
            print('AllTasksView: Scroll animation complete for page $pageId.');
            setState(() {
              _currentPageIndex = pageIndex;
            });
            print(
              'AllTasksView: _currentPageIndex updated to: $_currentPageIndex',
            );
            _scrollToCenterIndicator(_currentPageIndex).then((__) {
              if (statusToExpand != null) {
                widget.onScrollAndExpand(pageId, statusToExpand);
              }
              widget.onScrollComplete?.call();
            });
          });
    } else {
      print(
        'AllTasksView: Page $pageId not found in sortedPageIds. Cannot scroll.',
      );
      widget.onScrollComplete?.call();
    }
  }

  Future<void> _scrollToCenterIndicator(int selectedIndex) async {
    final double maxScrollExtent =
        _pageIndicatorScrollController.position.maxScrollExtent;
    final double currentScrollOffset = _pageIndicatorScrollController.offset;
    double targetOffset =
        (selectedIndex * _kIndividualIndicatorWidth) -
        ((_kVisibleIndicatorBarWidth / 2) - (_kIndividualIndicatorWidth / 2));
    targetOffset = targetOffset.clamp(0.0, maxScrollExtent);

    if ((targetOffset - currentScrollOffset).abs() > 1.0) {
      await _pageIndicatorScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? mostRecentPageId = widget.sortedPageIds.isNotEmpty
        ? widget.sortedPageIds.first
        : null;

    return Scaffold(
      body: Stack(
        children: [
          // PageView.builder(
          //   controller: _pageController,
          //   itemCount: widget.sortedPageIds.length,
          //   scrollDirection: Axis.horizontal,
          //   itemBuilder: (context, index) {
          //     final int pageId = widget.sortedPageIds[index];
          //     final List<TaskDto> currentPageTasks =
          //         widget.tasksByPage[pageId]!;
          //     final bool isMostRecentPage = pageId == mostRecentPageId;

          //     return Padding(
          //       padding: EdgeInsets.only(
          //         left: 12.0,
          //         right: 12.0,
          //         top: 12.0,
          //         bottom: 10,
          //       ),
          //       child: PageListItem(
          //         key: widget.getPageGlobalKey('all_tasks', pageId),
          //         pageId: pageId,
          //         formatDate: widget.formatDate,
          //         currentPageTasks: currentPageTasks,
          //         isMostRecentPage: isMostRecentPage,
          //         getStatusColor: widget.getStatusColor,
          //         statusExpandedState: widget.statusExpandedState,
          //         currentBrightness: widget.currentBrightness,
          //         statusToExpand: widget.statusToExpand,
          //       ),
          //     );
          //   },
          // ),
          PageView.custom(
            controller: _pageController,
            scrollDirection: Axis.horizontal,
            childrenDelegate: SliverChildBuilderDelegate((context, index) {
              final int pageId = widget.sortedPageIds[index];
              final List<TaskDto> currentPageTasks =
                  widget.tasksByPage[pageId]!;
              final bool isMostRecentPage = pageId == mostRecentPageId;

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double rotationY = 0.2;
                  double scale = 1.0;
                  double opacity = 1.0;

                  if (_pageController.position.haveDimensions) {
                    double pageOffset = _pageController.page! - index;
                    double clampedOffset = pageOffset.clamp(-1.0, 0.5);

                    rotationY = clampedOffset * (M.pi / 1);
                    scale = (1 - (clampedOffset.abs() * 0.1)).clamp(0.9, 1.0);
                    opacity = (1 - clampedOffset.abs() * 0.3).clamp(0.1, 1.0);
                  }

                  final transform = Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..rotateY(rotationY)
                      ..scale(scale),
                    child: Opacity(
                      opacity: opacity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 10.0,
                        ),
                        child: PageListItem(
                          key: widget.getPageGlobalKey('all_tasks', pageId),
                          pageId: pageId,
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

                  return transform;
                },
              );
            }, childCount: widget.sortedPageIds.length),
          ),

          Positioned(
            bottom: 63,
            left: 0,
            right: 0,
            child: Container(
              height: _kPageIndicatorHeight,
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Center(
                child: SizedBox(
                  width: _kVisibleIndicatorBarWidth,
                  child: ListView.builder(
                    controller: _pageIndicatorScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: widget.sortedPageIds.length,
                    itemBuilder: (context, index) {
                      bool isSelected = _currentPageIndex == index;
                      final int pageId = widget.sortedPageIds[index];
                      final DateTime? pageDate =
                          widget.tasksByPage[pageId]?.isNotEmpty == true
                          ? widget.tasksByPage[pageId]![0].pageDate
                          : null;

                      IconData indicatorIcon = Icons.sticky_note_2_outlined;
                      if (pageId == mostRecentPageId) {
                        indicatorIcon = Icons.bookmark_outlined;
                      }

                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          height: isSelected ? 36.0 : 30.0,
                          width: isSelected ? 80.0 : 30.0,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(15.0),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isSelected)
                                  Icon(
                                    indicatorIcon,
                                    size: 15.0,
                                    color: Colors.white,
                                  ),

                                if (isSelected) const SizedBox(width: 4),
                                Text(
                                  pageDate != null
                                      ? isSelected
                                            ? widget.myFormatDateFunction(
                                                pageDate,
                                              )
                                            : DateFormat('dd').format(pageDate)
                                      : 'N/A',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
