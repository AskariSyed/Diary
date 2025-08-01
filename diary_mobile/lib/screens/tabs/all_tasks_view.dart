import 'package:flutter/material.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/widgets/page_list_item.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
// ignore: library_imports
import 'dart:math' as M; // Corrected to library_imports

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

class _AllTasksViewState extends State<AllTasksView>
    with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  late ScrollController _pageIndicatorScrollController;
  int _currentPageIndex = 0;
  static const double _kPageIndicatorHeight = 60.0;
  static const double _kVisibleIndicatorBarWidth = 150.0;
  bool _isAnimatingPageController = false;
  bool _isAnimatingIndicatorController = false;
  static const double _kSelectedIndicatorWidth = 50.0;
  static const double _kUnselectedIndicatorWidth = 30.0;
  static const double _kHorizontalMargin = 2.0;

  static const double _kTodayButtonExpandedWidth = 70.0;

  double get _effectiveSelectedIndicatorTotalWidth =>
      _kSelectedIndicatorWidth + (_kHorizontalMargin * 2);
  double get _effectiveUnselectedIndicatorTotalWidth =>
      _kUnselectedIndicatorWidth + (_kHorizontalMargin * 2);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Determine initial page index based on widget.pageToScrollTo
    _currentPageIndex =
        widget.pageToScrollTo != null &&
            widget.sortedPageIds.contains(widget.pageToScrollTo)
        ? widget.sortedPageIds.indexOf(widget.pageToScrollTo!)
        : 0; // Default to the first page if no specific page is set

    _pageController = PageController(initialPage: _currentPageIndex);
    _pageIndicatorScrollController = ScrollController();

    // Schedule the initial scroll to ensure PageController has dimensions
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        // Ensure the PageView is at the correct page initially
        // No need to animate if it's the initial page.
        if (_pageController.page?.round() != _currentPageIndex) {
          _pageController.jumpToPage(_currentPageIndex);
        }
        // Center the indicator after initial page setting
        _scrollToCenterIndicator(_currentPageIndex);
      }
    });
  }

  @override
  void didUpdateWidget(covariant AllTasksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only trigger scroll if the scrollTrigger changes and a page is specified
    if (widget.scrollTrigger != oldWidget.scrollTrigger &&
        widget.pageToScrollTo != null) {
      _handleScrollToPage();
    }
    // Also handle cases where pageToScrollTo might change without scrollTrigger
    else if (widget.pageToScrollTo != oldWidget.pageToScrollTo &&
        widget.pageToScrollTo != null) {
      final int targetIndex = widget.sortedPageIds.indexOf(
        widget.pageToScrollTo!,
      );
      if (targetIndex != -1 && targetIndex != _currentPageIndex) {
        _scrollToPageAndExpand(targetIndex, widget.statusToExpand);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageIndicatorScrollController.dispose();
    super.dispose();
  }

  void _handleScrollToPage() {
    if (widget.pageToScrollTo != null && mounted) {
      final int targetIndex = widget.sortedPageIds.indexOf(
        widget.pageToScrollTo!,
      );
      if (targetIndex != -1) {
        // Only scroll if it's a different page
        if (_currentPageIndex != targetIndex) {
          _scrollToPageAndExpand(targetIndex, widget.statusToExpand);
        } else {
          // If already on the target page, just expand the status if needed
          if (widget.statusToExpand != null) {
            widget.onScrollAndExpand(
              widget.sortedPageIds[targetIndex],
              widget.statusToExpand!,
            );
          }
          widget.onScrollComplete?.call();
        }
      } else {
        widget.onScrollComplete?.call();
      }
    }
  }

  int? _findTodaysPageId() {
    final today = DateTime.now();
    for (final pageId in widget.sortedPageIds) {
      final pageDate = widget.tasksByPage[pageId]?.isNotEmpty == true
          ? widget.tasksByPage[pageId]![0].pageDate
          : null;
      if (pageDate != null &&
          pageDate.year == today.year &&
          pageDate.month == today.month &&
          pageDate.day == today.day) {
        return pageId;
      }
    }
    return null;
  }

  void _showPageSelectionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Scroll to Page',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.sortedPageIds.length,
                  itemBuilder: (context, index) {
                    final pageId = widget.sortedPageIds[index];
                    final pageDate =
                        widget.tasksByPage[pageId]?.isNotEmpty == true
                        ? widget.tasksByPage[pageId]![0].pageDate
                        : null;
                    return ListTile(
                      title: Text(
                        pageDate != null
                            ? DateFormat('MMMM dd, yyyy').format(pageDate)
                            : 'Page $pageId',
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        final int pageIndex = widget.sortedPageIds.indexOf(
                          pageId,
                        );
                        if (pageIndex != -1) {
                          _scrollToPageAndExpand(pageIndex, null);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _scrollToToday() {
    final todaysPageId = _findTodaysPageId();

    if (todaysPageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No tasks for today. Showing all pages."),
          duration: Duration(seconds: 2),
        ),
      );
      _showPageSelectionSheet();
      return;
    }

    final int todaysPageIndex = widget.sortedPageIds.indexOf(todaysPageId);

    if (_currentPageIndex == todaysPageIndex) {
      _showPageSelectionSheet(); // If already on today's page, open sheet
    } else {
      _scrollToPageAndExpand(todaysPageIndex, null);
    }
  }

  void _scrollToPageAndExpand(int pageIndex, TaskStatus? statusToExpand) {
    if (pageIndex != -1 && pageIndex < widget.sortedPageIds.length) {
      // If the target page is already the current page, just handle expansion and complete callback
      if (_currentPageIndex == pageIndex) {
        if (statusToExpand != null) {
          widget.onScrollAndExpand(
            widget.sortedPageIds[pageIndex],
            statusToExpand,
          );
        }
        widget.onScrollComplete?.call();
        return;
      }

      _isAnimatingPageController = true;
      _pageController
          .animateToPage(
            pageIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInToLinear,
          )
          .then((_) {
            _isAnimatingPageController = false;
            if (mounted) {
              setState(() {
                _currentPageIndex = pageIndex;
              });
            }
            // Ensure the indicator is centered AFTER the page has fully settled.
            // Using addPostFrameCallback ensures layout is done.
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _scrollToCenterIndicator(pageIndex);
              if (statusToExpand != null) {
                widget.onScrollAndExpand(
                  widget.sortedPageIds[pageIndex],
                  statusToExpand,
                );
              }
              widget.onScrollComplete?.call();
            });
          });
    } else {
      widget.onScrollComplete?.call();
    }
  }

  Future<void> _scrollToCenterIndicator(int selectedIndex) async {
    // If the scroll controller isn't attached to a scrollable yet,
    // or if an animation is already in progress, return.
    if (!_pageIndicatorScrollController.hasClients ||
        _isAnimatingIndicatorController) {
      return;
    }

    // Determine the maximum scrollable extent of the indicator bar.
    final double maxScrollExtent =
        _pageIndicatorScrollController.position.maxScrollExtent;
    // Get the current scroll offset of the indicator bar.
    final double currentScrollOffset = _pageIndicatorScrollController.offset;

    // Calculate the total width of all indicators *before* the selected one.
    double precedingIndicatorsTotalWidth = 0.0;
    for (int i = 0; i < selectedIndex; i++) {
      // Assuming all preceding indicators are unselected width
      precedingIndicatorsTotalWidth += _effectiveUnselectedIndicatorTotalWidth;
    }

    // Calculate the target offset to bring the selected indicator to the center of the visible bar.
    // This is done by:
    // 1. Starting with the total width of preceding indicators.
    // 2. Adding half the width of the selected indicator itself to get to its center.
    // 3. Subtracting half the visible width of the indicator bar to center that point.
    double targetOffset =
        precedingIndicatorsTotalWidth +
        (_effectiveSelectedIndicatorTotalWidth / 2) -
        (_kVisibleIndicatorBarWidth / 2);

    // Ensure the target offset is within the valid scroll range (0 to maxScrollExtent).
    targetOffset = targetOffset.clamp(0.0, maxScrollExtent);

    // Only animate if the current offset is significantly different from the target offset
    // to prevent unnecessary animations.
    if ((targetOffset - currentScrollOffset).abs() > 1.0) {
      _isAnimatingIndicatorController =
          true; // Set flag to indicate animation is active
      await _pageIndicatorScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _isAnimatingIndicatorController = false; // Reset flag after animation
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final int? mostRecentPageId = widget.sortedPageIds.isNotEmpty
        ? widget.sortedPageIds.first
        : null;

    final int? todaysPageId = _findTodaysPageId();
    final bool isTodaySelected =
        _currentPageIndex == widget.sortedPageIds.indexOf(todaysPageId ?? -1);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.custom(
              controller: _pageController,
              scrollDirection: Axis.horizontal,
              onPageChanged: (index) {
                if (_currentPageIndex != index) {
                  setState(() {
                    _currentPageIndex = index;
                  });
                  // Ensure this is called after the state update
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    _scrollToCenterIndicator(
                      index,
                    ); // Scroll indicator to center
                  });
                }
              },
              childrenDelegate: SliverChildBuilderDelegate((context, index) {
                if (index < 0 || index >= widget.sortedPageIds.length) {
                  return null;
                }
                final int pageId = widget.sortedPageIds[index];
                final List<TaskDto> currentPageTasks =
                    widget.tasksByPage[pageId]!;
                final bool isMostRecentPage = pageId == mostRecentPageId;

                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double rotationY = 0.0; // Default to 0 rotation
                    double scale = 1.0;
                    double opacity = 1.0;

                    if (_pageController.position.haveDimensions) {
                      double pageOffset = (_pageController.page ?? 0.0) - index;
                      double clampedOffset = pageOffset.clamp(
                        -1.0,
                        1.0,
                      ); // Clamped more broadly for consistency

                      // Ensure the rotation is applied correctly for pages off-screen
                      if (clampedOffset.abs() > 0.001) {
                        // Small epsilon to avoid tiny, unintended rotations
                        rotationY =
                            clampedOffset *
                            (M.pi / 2); // Rotate up to 90 degrees (M.pi / 2)
                      } else {
                        rotationY = 0.0; // No rotation if exactly on page
                      }

                      scale = (1 - (clampedOffset.abs() * 0.1)).clamp(0.9, 1.0);
                      opacity = (1 - clampedOffset.abs() * 0.3).clamp(0.1, 1.0);
                    } else {
                      // If dimensions are not available, return a non-transformed state
                      // for the initial build to avoid visual glitches.
                      return Opacity(
                        opacity: 1.0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            12.0,
                            12.0,
                            12.0,
                            0,
                          ),
                          child: PageListItem(
                            key: ValueKey('all_tasks-$pageId'),
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
                      );
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
                          padding: const EdgeInsets.fromLTRB(
                            12.0,
                            12.0,
                            12.0,
                            0,
                          ),
                          child: PageListItem(
                            key: ValueKey('all_tasks-$pageId'),
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
                  },
                );
              }, childCount: widget.sortedPageIds.length),
            ),
          ),
          Container(
            height: _kPageIndicatorHeight,
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            margin: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: _scrollToToday,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(
                        horizontal: _kHorizontalMargin,
                      ),
                      width: isTodaySelected
                          ? _kUnselectedIndicatorWidth
                          : _kTodayButtonExpandedWidth,
                      height: isTodaySelected ? 30.0 : 36.0,
                      decoration: BoxDecoration(
                        color: isTodaySelected
                            ? Colors.grey.shade600
                            : Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(15.0),
                        border: Border.all(
                          color: isTodaySelected
                              ? Colors.grey.shade500
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: isTodaySelected
                            ? const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 16.0,
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Today',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: _kVisibleIndicatorBarWidth,
                  child: ListView.builder(
                    controller: _pageIndicatorScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.sortedPageIds.length,
                    itemBuilder: (context, index) {
                      bool isSelected = _currentPageIndex == index;
                      final int pageId = widget.sortedPageIds[index];
                      final DateTime? pageDate =
                          widget.tasksByPage[pageId]?.isNotEmpty == true
                          ? widget.tasksByPage[pageId]![0].pageDate
                          : null;

                      return GestureDetector(
                        onTap: () {
                          // Only animate if the target page is different
                          if (_currentPageIndex != index) {
                            _pageController
                                .animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                )
                                .then((_) {
                                  if (mounted) {
                                    setState(() {
                                      _currentPageIndex = index;
                                    });
                                    // Call to center the indicator after page animation completes
                                    SchedulerBinding.instance
                                        .addPostFrameCallback((_) {
                                          _scrollToCenterIndicator(index);
                                        });
                                  }
                                });
                          } else {
                            // If tapping the current page's indicator, just ensure it's centered
                            // and no page animation is needed.
                            SchedulerBinding.instance.addPostFrameCallback((_) {
                              _scrollToCenterIndicator(index);
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          margin: const EdgeInsets.symmetric(
                            horizontal: _kHorizontalMargin,
                          ),
                          height: isSelected ? 36.0 : 30.0,
                          width: isSelected
                              ? _kSelectedIndicatorWidth
                              : _kUnselectedIndicatorWidth,
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
                                  Expanded(
                                    child: Text(
                                      pageDate != null
                                          ? widget.myFormatDateFunction(
                                              pageDate,
                                            )
                                          : 'N/A',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                    ),
                                  ),
                                if (!isSelected)
                                  Text(
                                    pageDate != null
                                        ? DateFormat('dd').format(pageDate)
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
