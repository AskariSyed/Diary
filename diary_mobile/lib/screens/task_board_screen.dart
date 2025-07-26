import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting
import '/models/task_dto.dart';
import '/mixin/taskstatus.dart';
import '/providers/task_provider.dart';
import '/providers/theme_provider.dart';

class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen> {
  final Map<String, bool> _statusExpandedState = {};
  final Map<int, bool> _pageExpandedState = {};
  final ScrollController _scrollController = ScrollController();
  String? _fetchErrorMessage;

  int? _scrollToPageId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchTasksWithErrorHandling());
  }

  Future<void> _fetchTasksWithErrorHandling() async {
    try {
      await Provider.of<TaskProvider>(context, listen: false).fetchTasks();
      setState(() {
        _fetchErrorMessage = null;
        print('Tasks fetched successfully');
      });
    } catch (e) {
      print('Error fetching tasks from_fetchTaskswithError Handling: $e');
      setState(() {
        _fetchErrorMessage = e.toString();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scrollToPageId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
        _scrollToPageId = null;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getStatusColor(TaskStatus status, Brightness brightness) {
    final Map<TaskStatus, Color> baseColors = {
      TaskStatus.backlog: Colors.blueGrey,
      TaskStatus.toDiscuss: Colors.amber,
      TaskStatus.inProgress: Colors.deepPurple,
      TaskStatus.onHold: Colors.red,
      TaskStatus.complete: Colors.green,
      TaskStatus.toFollowUp: Colors.teal,
    };

    Color baseColor = baseColors[status] ?? Colors.grey;
    if (brightness == Brightness.dark) {
      return baseColor.withOpacity(0.2);
    } else {
      return baseColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Brightness currentBrightness = Theme.of(context).brightness;

    // Group tasks by their page ID.
    final Map<int, List<TaskDto>> tasksByPage = {};
    for (var task in taskProvider.tasks) {
      tasksByPage.putIfAbsent(task.pageId, () => []).add(task);
    }
    final List<int> sortedPageIds = tasksByPage.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final int? mostRecentPageId = sortedPageIds.isNotEmpty
        ? sortedPageIds.first
        : null;

    if (taskProvider.errorMessage != null) {
      return _buildErrorState(themeProvider, taskProvider);
    }

    if (taskProvider.isLoading && sortedPageIds.isEmpty) {
      return _buildLoadingScreen(themeProvider, taskProvider);
    }
    if (sortedPageIds.isEmpty) {
      return _buildEmptyState(themeProvider, taskProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary Task Board'),
        actions: [
          // Button to add a new page.
          IconButton(
            icon: const Icon(Icons.note_add),
            tooltip: 'Add New Page',
            onPressed: () => _showAddPageDialog(context, taskProvider),
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
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sortedPageIds.map((pageId) {
              final List<TaskDto> currentPageTasks = tasksByPage[pageId]!;
              final bool isMostRecentPage = pageId == mostRecentPageId;

              // Determine if a page should be expanded by default (most recent)
              // or based on its stored state.
              final bool isPageExpanded = isMostRecentPage
                  ? true
                  : (_pageExpandedState[pageId] ?? false);

              // Widget to hold the content of a single page (status sections).
              Widget pageContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: TaskStatus.values.map((status) {
                  final tasksInStatus = currentPageTasks
                      .where((task) => task.status == status)
                      .toList();

                  // Unique key for each status expansion tile within a page for state preservation.
                  final String expansionTileKey =
                      'page_${pageId}_status_${status.index}';
                  // Expand statuses by default for the most recent page, otherwise use stored state.
                  final bool isStatusExpanded = isMostRecentPage
                      ? true
                      : (_statusExpandedState[expansionTileKey] ?? true);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    color: _getStatusColor(
                      status,
                      currentBrightness,
                    ), // Use updated color helper
                    elevation: 2.0,
                    child: Column(
                      children: [
                        // DragTarget wraps the header area
                        DragTarget<TaskDto>(
                          onWillAcceptWithDetails: (data) {
                            return isMostRecentPage &&
                                data.data.pageId == pageId &&
                                data.data.status != status;
                          },
                          onAcceptWithDetails: (details) async {
                            final draggedTask = details.data;
                            try {
                              await Provider.of<TaskProvider>(
                                context,
                                listen: false,
                              ).updateTaskStatus(draggedTask.id, status);
                              Future.microtask(
                                () => ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Task "${draggedTask.title}" moved to ${status.toApiString()} on Page $pageId',
                                    ),
                                  ),
                                ),
                              );
                            } catch (e) {
                              Future.microtask(
                                () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to update task status: $e',
                                        ),
                                      ),
                                    ),
                              );
                            }
                          },
                          builder: (context, candidateData, rejectedData) {
                            return Container(
                              decoration: BoxDecoration(
                                color:
                                    candidateData.isNotEmpty && isMostRecentPage
                                    ? (currentBrightness == Brightness.dark
                                          ? Colors.blue.withOpacity(0.4)
                                          : Colors.blue.withOpacity(0.2))
                                    : null,
                                borderRadius: BorderRadius.circular(
                                  4.0,
                                ), // Match card border
                              ),
                              child: ExpansionTile(
                                key: PageStorageKey<String>(expansionTileKey),
                                initiallyExpanded: isStatusExpanded,
                                onExpansionChanged: (isExpanded) {
                                  setState(() {
                                    _statusExpandedState[expansionTileKey] =
                                        isExpanded;
                                  });
                                },
                                title: Text(
                                  '${status.toApiString()} (${tasksInStatus.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                children: <Widget>[
                                  Column(
                                    children: tasksInStatus.map<Widget>((task) {
                                      if (isMostRecentPage) {
                                        return Draggable<TaskDto>(
                                          data: task,
                                          feedback: Material(
                                            elevation: 4.0,
                                            child: Container(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).cardColor,
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              child: Text(
                                                task.title,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color,
                                                  fontSize: 16.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                          childWhenDragging: Opacity(
                                            opacity: 0.5,
                                            child: _buildTaskCard(
                                              task,
                                              taskProvider,
                                              isMostRecentPage,
                                            ),
                                          ),
                                          child: _buildTaskCard(
                                            task,
                                            taskProvider,
                                            isMostRecentPage,
                                          ),
                                        );
                                      } else {
                                        return _buildTaskCard(
                                          task,
                                          taskProvider,
                                          false,
                                        );
                                      }
                                    }).toList(),
                                  ),

                                  if (tasksInStatus.isEmpty && isMostRecentPage)
                                    SizedBox(
                                      height: 50,
                                      child: Center(
                                        child: Text(
                                          'Drop tasks here',
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color:
                                                currentBrightness ==
                                                    Brightness.dark
                                                ? const Color.fromARGB(
                                                    255,
                                                    255,
                                                    255,
                                                    255,
                                                  )
                                                : const Color.fromARGB(
                                                    255,
                                                    255,
                                                    255,
                                                    255,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
              if (!isMostRecentPage) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Card(
                    elevation: 6.0,
                    margin: EdgeInsets.zero,
                    color: Theme.of(
                      context,
                    ).cardColor, // Use theme's card color
                    child: ExpansionTile(
                      key: PageStorageKey<int>(pageId),
                      initiallyExpanded: isPageExpanded,
                      onExpansionChanged: (isExpanded) {
                        setState(() {
                          _pageExpandedState[pageId] = isExpanded;
                        });
                      },
                      title: Text(
                        'Page ID: $pageId',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: pageContent,
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 6.0,
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Page ID: $pageId (Most Recent)',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const Divider(height: 24, thickness: 1),
                          pageContent,
                        ],
                      ),
                    ),
                  ),
                );
              }
            }).toList(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final int targetPageId = await taskProvider
              .getTargetPageIdForNewTask();
          _showAddTaskDialog(context, targetPageId);
        },
        label: const Text('Add New Task'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLoadingScreen(
    ThemeProvider themeProvider,
    TaskProvider taskProvider,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary Task Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add),
            tooltip: 'Add New Page',
            onPressed: () => _showAddPageDialog(context, taskProvider),
          ),
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: themeProvider.toggleTheme,
          ),
        ],
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildEmptyState(
    ThemeProvider themeProvider,
    TaskProvider taskProvider,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary Task Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add),
            tooltip: 'Add New Page',
            onPressed: () => _showAddPageDialog(context, taskProvider),
          ),
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: themeProvider.toggleTheme,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No tasks or pages found. Add a new task or page!'),
            const SizedBox(height: 20),
            // Button to add the first task.
            ElevatedButton.icon(
              onPressed: () async {
                final int targetPageId = await taskProvider
                    .getTargetPageIdForNewTask();
                _showAddTaskDialog(context, targetPageId);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add First Task'),
            ),
            const SizedBox(height: 20),
            // Button to add the first page.
            ElevatedButton.icon(
              onPressed: () => _showAddPageDialog(context, taskProvider),
              icon: const Icon(Icons.add_box),
              label: const Text('Add First Page'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final int targetPageId = await taskProvider
              .getTargetPageIdForNewTask();
          _showAddTaskDialog(context, targetPageId);
        },
        label: const Text('Add New Task'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskCard(
    TaskDto task,
    TaskProvider taskProvider,
    bool isDraggableAndEditable,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.status == TaskStatus.complete
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        subtitle: Text(
          'Task ID: ${task.id} (Parent: ${task.parentTaskId != null ? task.parentTaskId : 'None'})',
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: isDraggableAndEditable
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () =>
                    _confirmDeleteTask(context, taskProvider, task),
              )
            : null,
        onTap: isDraggableAndEditable
            ? () => _showEditTaskDialog(context, taskProvider, task)
            : null,
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, int targetPageId) {
    final TextEditingController taskTitleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Task'),
          content: TextField(
            controller: taskTitleController,
            decoration: InputDecoration(
              labelText: 'Task Title',
              hintText: 'Add to Page $targetPageId',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (taskTitleController.text.isNotEmpty) {
                  try {
                    await Provider.of<TaskProvider>(
                      context,
                      listen: false,
                    ).addTask(
                      taskTitleController.text,
                      TaskStatus.backlog, // New tasks start as backlog
                      pageId: targetPageId,
                    );
                    Future.microtask(
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Task added successfully!'),
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  } catch (e) {
                    Future.microtask(
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add task: $e')),
                      ),
                    );
                  }
                } else {
                  Future.microtask(
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Task title cannot be empty.'),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditTaskDialog(
    BuildContext context,
    TaskProvider taskProvider,
    TaskDto task,
  ) {
    final TextEditingController taskTitleController = TextEditingController(
      text: task.title,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Task Title'),
          content: TextField(
            controller: taskTitleController,
            decoration: const InputDecoration(labelText: 'Task Title'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (taskTitleController.text.isNotEmpty) {
                  try {
                    // Only update the title. The status remains unchanged.
                    await taskProvider.updateTask(
                      task.id,
                      taskTitleController.text,
                      task.status, // Keep the original status
                    );
                    Future.microtask(
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Task title updated successfully!'),
                        ),
                      ),
                    );
                    Navigator.pop(context); // Close dialog on success
                  } catch (e) {
                    Future.microtask(
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update task title: $e'),
                        ),
                      ),
                    );
                  }
                } else {
                  Future.microtask(
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Task title cannot be empty.'),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteTask(
    BuildContext context,
    TaskProvider taskProvider,
    TaskDto task,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: Text(
            'Are you sure you want to delete "${task.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await taskProvider.deleteTask(task.id);
                  Future.microtask(
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Task deleted successfully!'),
                      ),
                    ),
                  );
                  Navigator.pop(context); // Close dialog on success
                } catch (e) {
                  Future.microtask(
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete task: $e')),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showAddPageDialog(BuildContext context, TaskProvider taskProvider) {
    final TextEditingController diaryNoController = TextEditingController();
    DateTime? selectedPageDate = DateTime.now(); // Initialize with today's date

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text('Create New Page'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: diaryNoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Diary Number',
                      hintText: 'e.g., 1 (Diary ID)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      selectedPageDate == null
                          ? 'Select Page Date'
                          : 'Page Date: ${DateFormat('yyyy-MM-dd').format(selectedPageDate!)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedPageDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null && picked != selectedPageDate) {
                        setStateSB(() {
                          selectedPageDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'A new page will be created by the server for the specified Diary and Date. Non-completed tasks from the most recent page before this date will be carried over.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final int? diaryNo = int.tryParse(diaryNoController.text);
                    if (diaryNo == null || selectedPageDate == null) {
                      Future.microtask(
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a valid Diary Number and select a Page Date.',
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      final int? oldMostRecentPageId = taskProvider
                          .getCurrentMostRecentPageId();

                      final int newPageId = await taskProvider.createNewPage(
                        diaryNo,
                        selectedPageDate!,
                      );
                      Navigator.pop(context);

                      if (newPageId != -1) {
                        setState(() {
                          _scrollToPageId = newPageId;
                          if (oldMostRecentPageId != null) {
                            _pageExpandedState[oldMostRecentPageId] = false;
                          }
                        });
                      }

                      Future.microtask(
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'New page created and tasks migrated!',
                            ),
                          ),
                        ),
                      );
                    } catch (e) {
                      Future.microtask(
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error creating page: ${e.toString().replaceAll("Exception: ", "")}',
                            ),
                          ), // Clean up error message
                        ),
                      );
                    }
                  },
                  child: const Text('Create Page'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState(
    ThemeProvider themeProvider,
    TaskProvider taskProvider,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary Task Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add),
            tooltip: 'Add New Page',
            onPressed: () => _showAddPageDialog(context, taskProvider),
          ),
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: themeProvider.toggleTheme,
          ),
        ],
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
                _fetchErrorMessage ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _fetchErrorMessage = null;
                    });
                    _fetchTasksWithErrorHandling();
                  });
                },
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
