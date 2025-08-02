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
      elevation: 2,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      title: Text(
        'E-Diary',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.deepPurple,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.note_add_outlined),
          tooltip: 'Add New Page',
          onPressed: () =>
              showAddPageDialog(context, taskProvider, pageToScrollTo),
        ),
        IconButton(
          icon: Icon(
            themeProvider.themeMode == ThemeMode.light
                ? Icons.light_mode
                : Icons.dark_mode,
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
