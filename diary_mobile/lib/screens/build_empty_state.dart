import 'package:diary_mobile/dialogs/show_add_page_dialog.dart';
import 'package:diary_mobile/dialogs/show_add_task_dialog.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:diary_mobile/providers/theme_provider.dart';
import 'package:flutter/material.dart';

class EmptyStateScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  final TaskProvider taskProvider;
  final int? scrollToPageId;
  final bool isFiltering;
  final VoidCallback? onClearFilter;

  const EmptyStateScreen({
    super.key,
    required this.themeProvider,
    required this.taskProvider,
    required this.scrollToPageId,
    this.isFiltering = false,
    this.onClearFilter,
  });

  @override
  State<EmptyStateScreen> createState() => _EmptyStateScreenState();
}

class _EmptyStateScreenState extends State<EmptyStateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length:
          TaskStatus.values.where((s) => s != TaskStatus.deleted).length + 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
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
            onPressed: () => showAddPageDialog(context, widget.taskProvider),
          ),
          IconButton(
            icon: Icon(
              widget.themeProvider.themeMode == ThemeMode.light
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            onPressed: widget.themeProvider.toggleTheme,
          ),
        ],

        bottom: TabBar(
          controller: _tabController,
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
                widget.isFiltering
                    ? Icons.filter_alt_off_outlined
                    : Icons.inbox_outlined,
                size: 80,
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
              const SizedBox(height: 24),
              Text(
                widget.isFiltering ? 'No Tasks Found' : 'Your Diary is Empty',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isFiltering
                    ? 'Try adjusting your search filters or clear them to see all tasks.'
                    : 'Add a new page or task to get started.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (widget.isFiltering && widget.onClearFilter != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: widget.onClearFilter,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Filters'),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddTaskDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }
}
