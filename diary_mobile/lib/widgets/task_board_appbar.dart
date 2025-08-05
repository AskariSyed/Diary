import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:diary_mobile/dialogs/show_add_page_dialog.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:diary_mobile/providers/theme_provider.dart';

class TaskBoardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isSearching;
  final TextEditingController searchController;
  final ValueChanged<bool> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onSelectDate;
  final Future<void> Function() onRefresh;
  final int? pageToScrollTo;
  final PreferredSizeWidget? bottom;

  const TaskBoardAppBar({
    super.key,
    required this.isSearching,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelectDate,
    required this.onRefresh,
    this.pageToScrollTo,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      title: isSearching
          ? TextField(
              controller: searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by title or date...',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.color?.withOpacity(0.6),
                ),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
              ),
            )
          : const Text(
              'E-Diary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
      leading: isSearching
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                onSearchChanged(false);
                onClearSearch();
              },
            )
          : null,
      actions: [
        if (isSearching && searchController.text.isNotEmpty)
          IconButton(icon: const Icon(Icons.clear), onPressed: onClearSearch),
        if (isSearching)
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Filter by Date',
            onPressed: onSelectDate,
          ),
        if (!isSearching)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Tasks',
            onPressed: () => onSearchChanged(true),
          ),
        IconButton(
          onPressed: () async {
            await onRefresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Tasks Refreshed."),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          icon: const Icon(Icons.note_add),
          tooltip: 'Add New Page',
          onPressed: () => showAddPageDialog(context, taskProvider),
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
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
