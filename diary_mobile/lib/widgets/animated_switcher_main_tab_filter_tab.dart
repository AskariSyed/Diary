import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/widgets/filter_tab_bar.dart';
import 'package:flutter/material.dart';

class animated_switcher_main_tab_filter_tab extends StatelessWidget {
  const animated_switcher_main_tab_filter_tab({
    super.key,
    required TabController mainTabController,
    required TabController filterTabController,
    required TaskStatus? currentFilterStatus,
    required this.currentBrightness,
  }) : _mainTabController = mainTabController,
       _filterTabController = filterTabController,
       _currentFilterStatus = currentFilterStatus;

  final TabController _mainTabController;
  final TabController _filterTabController;
  final TaskStatus? _currentFilterStatus;
  final Brightness currentBrightness;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -1.0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _mainTabController.index == 1
          ? Stack(
              children: [
                filter_tab_bar(
                  filterTabController: _filterTabController,
                  currentFilterStatus: _currentFilterStatus,
                  currentBrightness: currentBrightness,
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
