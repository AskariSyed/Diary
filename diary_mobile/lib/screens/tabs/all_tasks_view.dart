// all_tasks_view.dart

import 'package:diary_mobile/widgets/drag_drop_target._Pages.dart';
import 'package:diary_mobile/widgets/page_view_builder.dart';
import 'package:flutter/material.dart';
import 'package:diary_mobile/models/task_dto.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import 'package:provider/provider.dart';
import 'package:diary_mobile/providers/task_provider.dart';

class AllTasksView extends StatefulWidget {
  final List<TaskDto> tasksToShow;
  final List<TaskDto> allTasks;
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
  final Map<int, DateTime?> pageDatesById;

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
    required this.allTasks,
    required this.pageDatesById,
  });

  @override
  State<AllTasksView> createState() => _AllTasksViewState();
}

class _AllTasksViewState extends State<AllTasksView>
    with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  late ScrollController _pageIndicatorScrollController;
  int _currentPageIndex = 0;
  bool _isDragging = false;

  void _handleDragStarted() {
    setState(() {
      _isDragging = true;
    });
  }

  void _handleDragCompleted() {
    setState(() {
      _isDragging = false;
    });
  }

  static const double _kPageIndicatorHeight = 60.0;
  static const double _kVisibleIndicatorBarWidth = 240.0;
  // ignore: unused_field
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

    _currentPageIndex =
        widget.pageToScrollTo != null &&
            widget.sortedPageIds.contains(widget.pageToScrollTo)
        ? widget.sortedPageIds.indexOf(widget.pageToScrollTo!)
        : 0;

    _pageController = PageController(initialPage: _currentPageIndex);
    _pageIndicatorScrollController = ScrollController();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        if (_pageController.page?.round() != _currentPageIndex) {
          _pageController.jumpToPage(_currentPageIndex);
        }
        _scrollToCenterIndicator(_currentPageIndex);
      }
    });
  }

  @override
  void didUpdateWidget(covariant AllTasksView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.scrollTrigger != oldWidget.scrollTrigger &&
        widget.pageToScrollTo != null) {
      _handleScrollToPage();
    } else if (widget.pageToScrollTo != oldWidget.pageToScrollTo &&
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
        if (_currentPageIndex != targetIndex) {
          _scrollToPageAndExpand(targetIndex, widget.statusToExpand);
        } else {
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
      final pageDate = widget.pageDatesById[pageId];

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
                    final DateTime? pageDate = widget.pageDatesById[pageId];

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
      showTopSnackBar(
        Overlay.of(context),
        const CustomSnackBar.error(
          message: 'No page for Today. Create a new page',
        ),
        displayDuration: Durations.short3,
      );
      _showPageSelectionSheet();
      return;
    }

    final int todaysPageIndex = widget.sortedPageIds.indexOf(todaysPageId);

    if (_currentPageIndex == todaysPageIndex) {
      _showPageSelectionSheet();
    } else {
      _scrollToPageAndExpand(todaysPageIndex, null);
    }
  }

  void _scrollToPageAndExpand(int pageIndex, TaskStatus? statusToExpand) {
    if (pageIndex != -1 && pageIndex < widget.sortedPageIds.length) {
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
    if (!_pageIndicatorScrollController.hasClients ||
        _isAnimatingIndicatorController) {
      return;
    }

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
    if ((targetOffset - currentScrollOffset).abs() > 1.0) {
      _isAnimatingIndicatorController = true;
      await _pageIndicatorScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _isAnimatingIndicatorController = false;
    }
  }

  String myFormatDateFunction(DateTime? date) {
    if (date == null) {
      return 'N/A';
    }
    return DateFormat('MMM dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final int? todaysPageId = _findTodaysPageId();
    final bool isTodaySelected =
        _currentPageIndex == widget.sortedPageIds.indexOf(todaysPageId ?? -1);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageViewBuilder(
                  pageController: _pageController,
                  widget: widget,
                  onDragStarted: _handleDragStarted,
                  onDragCompleted: _handleDragCompleted,
                  onPageChanged: (index) {
                    if (_currentPageIndex != index) {
                      setState(() {
                        _currentPageIndex = index;
                      });
                      SchedulerBinding.instance.addPostFrameCallback((_) {
                        _scrollToCenterIndicator(index);
                      });
                    }
                  },
                ),
              ),
              Container(
                height: _kPageIndicatorHeight,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                margin: const EdgeInsets.only(bottom: 4.0),
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
                              widget.pageDatesById[pageId];

                          return GestureDetector(
                            onTap: () {
                              if (_currentPageIndex != index) {
                                _pageController
                                    .animateToPage(
                                      index,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    )
                                    .then((_) {
                                      if (mounted) {
                                        setState(() {
                                          _currentPageIndex = index;
                                        });
                                        SchedulerBinding.instance
                                            .addPostFrameCallback((_) {
                                              _scrollToCenterIndicator(index);
                                            });
                                      }
                                    });
                              } else {
                                SchedulerBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
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
                                    ? Color.fromARGB(255, 94, 79, 230)
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
                                              ? myFormatDateFunction(pageDate)
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
          if (_isDragging)
            DragDropTargetForPage(
              taskProvider: taskProvider,
              currentBrightness: widget.currentBrightness,
            ),
        ],
      ),
    );
  }
}
