import 'package:flutter/material.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/widgets/page_list_item.dart';

// Assuming ExpansibleController is defined or aliased elsewhere.
abstract class ExpansibleController extends ChangeNotifier {
  bool get isExpanded;
  void expand();
  void collapse();
  void toggle();
}

class AllTasksView extends StatefulWidget {
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
  int _currentPageIndex = 0; // Track the current page for the indicator

  static const double _kPageIndicatorHeight = 60.0;
  // Calculate the ideal width for one unselected indicator (30w + 8m)
  static const double _kIndividualIndicatorWidth =
      30.0 + (4.0 * 2); // width + left/right margin
  // Calculate the width needed to show exactly 3 unselected indicators
  static const double _kVisibleIndicatorBarWidth =
      _kIndividualIndicatorWidth * 5;

  // Flag to prevent recursive calls between listeners
  bool _isAnimatingPageController = false;
  bool _isAnimatingIndicatorController = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageIndicatorScrollController = ScrollController();
    _handleInitialScroll();

    // Listener for main PageView scrolling
    _pageController.addListener(() {
      if (_pageController.page != null && !_isAnimatingPageController) {
        int newPageIndex = _pageController.page!.round();
        if (_currentPageIndex != newPageIndex) {
          setState(() {
            _currentPageIndex = newPageIndex;
          });
          _isAnimatingIndicatorController =
              true; // Set flag to prevent feedback loop
          _scrollToCenterIndicator(newPageIndex).then((_) {
            _isAnimatingIndicatorController =
                false; // Reset flag after animation
          });
        }
      }
    });

    // Listener for indicator bar scrolling
    _pageIndicatorScrollController.addListener(() {
      if (_pageIndicatorScrollController.position.isScrollingNotifier.value &&
          !_isAnimatingIndicatorController) {
        // Calculate the center of the currently visible part of the scroll bar
        final double centerScrollOffset =
            _pageIndicatorScrollController.offset +
            (_kVisibleIndicatorBarWidth / 2);
        // Determine which indicator is closest to the center
        int targetIndex = (centerScrollOffset / _kIndividualIndicatorWidth)
            .round();

        // Ensure targetIndex is within valid bounds
        targetIndex = targetIndex.clamp(0, widget.sortedPageIds.length - 1);

        if (targetIndex != _currentPageIndex) {
          _isAnimatingPageController =
              true; // Set flag to prevent feedback loop
          _pageController
              .animateToPage(
                targetIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              )
              .then((_) {
                _isAnimatingPageController =
                    false; // Reset flag after animation
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
        _scrollToPageAndExpand(widget.pageToScrollTo!, widget.statusToExpand);
      }
    });
  }

  void _handleScrollToPage() {
    if (widget.pageToScrollTo != null && mounted) {
      _scrollToPageAndExpand(widget.pageToScrollTo!, widget.statusToExpand);
    }
  }

  void _scrollToPageAndExpand(int pageId, TaskStatus? statusToExpand) {
    print('AllTasksView: Attempting to scroll to page $pageId');
    final int pageIndex = widget.sortedPageIds.indexOf(pageId);
    if (pageIndex != -1) {
      print(
        'AllTasksView: Page $pageId found at index $pageIndex. Scrolling...',
      );
      _pageController
          .animateToPage(
            pageIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInToLinear,
          )
          .then((_) {
            print('AllTasksView: Scroll animation complete for page $pageId.');
            if (statusToExpand != null) {
              widget.onScrollAndExpand(pageId, statusToExpand);
            }
            widget.onScrollComplete?.call();
          });
    } else {
      print('AllTasksView: Page $pageId not found in sortedPageIds.');
      widget.onScrollComplete?.call();
    }
  }

  // Scrolls the page indicator bar to center the currently selected indicator
  Future<void> _scrollToCenterIndicator(int selectedIndex) async {
    final double maxScrollExtent =
        _pageIndicatorScrollController.position.maxScrollExtent;
    final double currentScrollOffset = _pageIndicatorScrollController.offset;

    // Calculate the target offset to bring the selected indicator to the left edge
    // and then center it within the visible 3-indicator window.
    double targetOffset =
        (selectedIndex * _kIndividualIndicatorWidth) -
        ((_kVisibleIndicatorBarWidth / 2) - (_kIndividualIndicatorWidth / 2));

    // Clamp the targetOffset to prevent over-scrolling
    targetOffset = targetOffset.clamp(0.0, maxScrollExtent);

    // Only animate if the target offset is significantly different to avoid unnecessary animations
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
          PageView.builder(
            controller: _pageController,
            itemCount: widget.sortedPageIds.length,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final int pageId = widget.sortedPageIds[index];
              final List<TaskDto> currentPageTasks =
                  widget.tasksByPage[pageId]!;
              final bool isMostRecentPage = pageId == mostRecentPageId;

              return Padding(
                padding: EdgeInsets.only(
                  left: 12.0,
                  right: 12.0,
                  top: 12.0,
                  bottom: _kPageIndicatorHeight + 10,
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
              );
            },
          ),

          // ---
          // START: MODIFIED SECTION FOR THE INDICATOR BAR
          Positioned(
            bottom: 40,
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
                    itemCount: widget.sortedPageIds.length,
                    itemBuilder: (context, index) {
                      bool isSelected = _currentPageIndex == index;
                      final int pageId = widget.sortedPageIds[index];
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
                            child: isSelected
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        indicatorIcon,
                                        size: 15.0,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Page ${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  )
                                : Icon(
                                    indicatorIcon,
                                    size: 15.0,
                                    color: Colors.white,
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
