import 'package:flutter/material.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/widgets/status_dropTarget.dart';

class FilterTabBar extends StatelessWidget {
  const FilterTabBar({
    super.key,
    required TabController filterTabController,
    required TaskStatus? currentFilterStatus,
    required this.currentBrightness,
  }) : _filterTabController = filterTabController,
       _currentFilterStatus = currentFilterStatus;

  final TabController _filterTabController;
  final TaskStatus? _currentFilterStatus;
  final Brightness currentBrightness;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      key: const ValueKey('filterTabBar'),
      controller: _filterTabController,
      isScrollable: true,
      indicatorColor: Theme.of(context).colorScheme.onSurface,
      labelPadding: EdgeInsets.zero,
      indicatorPadding: EdgeInsets.zero,
      tabs: TaskStatus.values
          .where((status) => status != TaskStatus.deleted)
          .map(
            (status) => Tab(
              child: Container(
                width: null,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      getStatusIcon(status),
                      size: 18,
                      color: _currentFilterStatus == status
                          ? getStatusColor(status, currentBrightness)
                          : Colors.grey,
                    ),
                    Text(
                      status.toApiString(),
                      style: TextStyle(
                        fontSize: 9,
                        color: _currentFilterStatus == status
                            ? getStatusColor(status, currentBrightness)
                            : Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
