import 'package:flutter/material.dart';
import 'package:diary_mobile/dialogs/show_add_page_dialog.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:diary_mobile/providers/theme_provider.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';

Widget buildEmptyState(
  ThemeProvider themeProvider,
  TaskProvider taskProvider,
  BuildContext context,
  int? scrollToPageId, {
  bool isFiltering = false,
  VoidCallback? onClearFilter,
}) {
  final TabController dummyTabController = TabController(
    length: TaskStatus.values.where((s) => s != TaskStatus.deleted).length + 1,
    vsync: Scaffold.of(context), // Requires a TickerProvider
  );

  final List<Tab> tabs = [
    const Tab(text: 'All'),
    ...TaskStatus.values
        .where((status) => status != TaskStatus.deleted)
        .map((status) => Tab(text: status.toApiString())),
  ];

  return Scaffold(
    appBar: AppBar(
      title: const Text('Diary Task Board'),
      actions: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextField(
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                suffixIcon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.note_add),
          tooltip: 'Add New Page',
          onPressed: () =>
              showAddPageDialog(context, taskProvider, scrollToPageId),
        ),
        IconButton(
          icon: Icon(
            themeProvider.themeMode == ThemeMode.light
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
          ),
          onPressed: themeProvider.toggleTheme,
        ),
      ],
      bottom: TabBar(
        controller: dummyTabController,
        isScrollable: true,
        tabs: tabs,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorColor: Theme.of(context).colorScheme.secondary,
        labelColor: Theme.of(context).colorScheme.onSurface,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltering
                  ? Icons.filter_alt_off_outlined
                  : Icons.inbox_outlined,
              size: 80,
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              isFiltering ? 'No Tasks Found' : 'Your Diary is Empty',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltering
                  ? 'Try adjusting your search filters or clear them to see all tasks.'
                  : 'Add a new page or task to get started.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (isFiltering && onClearFilter != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onClearFilter,
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
