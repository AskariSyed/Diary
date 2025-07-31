import 'package:flutter/material.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/widgets/page_list_item.dart';
import 'package:intl/intl.dart';
// ignore: library_prefixes
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
  static const double _kVisibleIndicatorBarWidth = 210.0;
  bool _isAnimatingPageController = false;
  bool _isAnimatingIndicatorController = false;
  static const double _kSelectedIndicatorWidth = 50.0;
  static const double _kUnselectedIndicatorWidth = 30.0;
  static const double _kHorizontalMargin = 4.0;
  double get _effectiveSelectedIndicatorTotalWidth =>
      _kSelectedIndicatorWidth + (_kHorizontalMargin * 2);
  double get _effectiveUnselectedIndicatorTotalWidth =>
      _kUnselectedIndicatorWidth + (_kHorizontalMargin * 2);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageIndicatorScrollController = ScrollController();
    _handleInitialScroll();
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
        final int targetIndex = widget.sortedPageIds.indexOf(
          widget.pageToScrollTo!,
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
    final int pageIndex = widget.sortedPageIds.indexOf(pageId);
    if (pageIndex != -1) {
      if (_currentPageIndex == pageIndex) {
        if (statusToExpand != null) {
          widget.onScrollAndExpand(pageId, statusToExpand);
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
            _scrollToCenterIndicator(_currentPageIndex);
            if (statusToExpand != null) {
              widget.onScrollAndExpand(pageId, statusToExpand);
            }
            widget.onScrollComplete?.call();
          });
    } else {
      widget.onScrollComplete?.call();
    }
  }

  Future<void> _scrollToCenterIndicator(int selectedIndex) async {
    final double maxScrollExtent =
        _pageIndicatorScrollController.position.maxScrollExtent;
    final double currentScrollOffset = _pageIndicatorScrollController.offset;
    double precedingIndicatorsTotalWidth = 0.0;
    for (int i = 0; i < selectedIndex; i++) {
      precedingIndicatorsTotalWidth += _effectiveUnselectedIndicatorTotalWidth;
    }
    double targetOffset =
        precedingIndicatorsTotalWidth +
        (_effectiveSelectedIndicatorTotalWidth / 2) -
        (_kVisibleIndicatorBarWidth / 2);
    targetOffset = targetOffset.clamp(0.0, maxScrollExtent);
    if ((targetOffset - currentScrollOffset).abs() > 1.0 &&
        !_isAnimatingIndicatorController) {
      _isAnimatingIndicatorController = true;
      await _pageIndicatorScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _isAnimatingIndicatorController = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? mostRecentPageId = widget.sortedPageIds.isNotEmpty
        ? widget.sortedPageIds.first
        : null;

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
                  _scrollToCenterIndicator(index);
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
                    double rotationY = 0.2;
                    double scale = 1.0;
                    double opacity = 1.0;

                    if (_pageController.position.haveDimensions) {
                      double pageOffset = (_pageController.page ?? 0.0) - index;
                      double clampedOffset = pageOffset.clamp(-1.0, 0.5);

                      rotationY = clampedOffset * (M.pi / 1);
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
                          padding: const EdgeInsets.fromLTRB(
                            12.0,
                            12.0,
                            12.0,
                            0,
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
                  },
                );
              }, childCount: widget.sortedPageIds.length),
            ),
          ),
          Container(
            height: _kPageIndicatorHeight,
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            margin: const EdgeInsets.only(bottom: 10.0),
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
                    final DateTime? pageDate =
                        widget.tasksByPage[pageId]?.isNotEmpty == true
                        ? widget.tasksByPage[pageId]![0].pageDate
                        : null;

                    return GestureDetector(
                      onTap: () {
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
                                _scrollToCenterIndicator(index);
                              }
                            });
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
                                        ? widget.myFormatDateFunction(pageDate)
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
            ),
          ),
        ],
      ),
    );
  }
}
