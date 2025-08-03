import 'package:diary_mobile/dialogs/show_add_page_dialog.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:diary_mobile/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';

class ErrorStateScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  final TaskProvider taskProvider;
  final int? scrollToPageId;
  final String? fetchErrorMessage;

  const ErrorStateScreen({
    super.key,
    required this.themeProvider,
    required this.taskProvider,
    required this.scrollToPageId,
    required this.fetchErrorMessage,
  });

  @override
  State<ErrorStateScreen> createState() => _ErrorStateScreenState();
}

class _ErrorStateScreenState extends State<ErrorStateScreen>
    with SingleTickerProviderStateMixin {
  String? _localFetchError;
  late TabController _dummyTabController;

  @override
  void initState() {
    super.initState();
    _localFetchError = widget.fetchErrorMessage;
    _dummyTabController = TabController(
      length:
          TaskStatus.values.where((s) => s != TaskStatus.deleted).length + 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _dummyTabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTasksWithErrorHandling() async {
    try {
      await widget.taskProvider.fetchTasks();
      if (!mounted) return;
      setState(() {
        _localFetchError = null;
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _localFetchError = e.toString();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => showAddPageDialog(context, widget.taskProvider),
          ),
          IconButton(
            icon: Icon(
              widget.themeProvider.themeMode == ThemeMode.light
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
            ),
            onPressed: widget.themeProvider.toggleTheme,
          ),
        ],
        bottom: TabBar(
          controller: _dummyTabController,
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load tasks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _localFetchError ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchTasksWithErrorHandling,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
