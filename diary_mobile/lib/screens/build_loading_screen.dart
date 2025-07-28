import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import '../providers/task_provider.dart';
// Make sure this path is correct if you have dialogs here
import 'package:diary_mobile/dialogs/show_add_page_dialog.dart';
import 'package:diary_mobile/dialogs/show_add_task_dialog.dart';

Widget buildLoadingScreen(
  BuildContext context, // This context is from the Scaffold's subtree
  ThemeProvider themeProvider,
  TaskProvider taskProvider,
  int? pageToScrollTo,
  Map<int, bool> pageExpandedState,
) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Diary Task Board'),
      actions: [
        IconButton(
          icon: const Icon(Icons.note_add),
          tooltip: 'Add New Page',
          onPressed: () => showAddPageDialog(
            context, // This context is now valid
            taskProvider,
            pageToScrollTo,
            pageExpandedState,
          ),
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
    ),
    body: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text("Loading tasks...", style: TextStyle(fontSize: 18)),
        ],
      ),
    ),
    floatingActionButton: Builder(
      // Use Builder to get a context under the Scaffold
      builder: (innerContext) => FloatingActionButton.extended(
        onPressed: () async {
          final int targetPageId = await taskProvider
              .getTargetPageIdForNewTask();
          if (!innerContext.mounted) return; // Use innerContext here
          showAddTaskDialog(
            innerContext,
            targetPageId,
          ); // Use innerContext here
        },
        label: const Text('Add New Task'),
        icon: const Icon(Icons.add),
      ),
    ),
  );
}
