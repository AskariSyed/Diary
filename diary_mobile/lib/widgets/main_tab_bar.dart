import 'package:flutter/material.dart';

class MainTabBar extends StatelessWidget {
  const MainTabBar({super.key, required TabController mainTabController})
    : _mainTabController = mainTabController;

  final TabController _mainTabController;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: _mainTabController,
      tabs: [
        Tab(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.book,
                  size: 19,
                  color: _mainTabController.index == 0
                      ? Colors.deepPurple
                      : Colors.grey,
                ),
                Text(
                  'My Diary',
                  style: TextStyle(
                    fontSize: 14,
                    color: _mainTabController.index == 0
                        ? Colors.deepPurple
                        : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Tab(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_list,
                size: 18,
                color: _mainTabController.index == 1
                    ? Colors.deepPurple
                    : Colors.grey,
              ),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 9,
                  color: _mainTabController.index == 1
                      ? Colors.deepPurple
                      : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
      indicatorColor: Theme.of(context).colorScheme.onSurface,
    );
  }
}
