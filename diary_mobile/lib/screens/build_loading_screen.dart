import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import '../providers/task_provider.dart';
import 'package:diary_mobile/dialogs/show_add_page_dialog.dart';
import 'package:diary_mobile/dialogs/show_add_task_dialog.dart';

Widget buildLoadingScreen(
  BuildContext context,
  ThemeProvider themeProvider,
  TaskProvider taskProvider,
  int? pageToScrollTo,
) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Diary Task Board'),
      actions: [
        IconButton(
          icon: const Icon(Icons.note_add),
          tooltip: 'Add New Page',
          onPressed: () =>
              showAddPageDialog(context, taskProvider, pageToScrollTo),
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
      builder: (innerContext) => FloatingActionButton.extended(
        onPressed: () async {
          final int targetPageId = await taskProvider
              .getTargetPageIdForNewTask();
          if (!innerContext.mounted) return;
          showAddTaskDialog(innerContext);
        },
        label: const Text('Add New Task'),
        icon: const Icon(Icons.add),
      ),
    ),
  );
}
