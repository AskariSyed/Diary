// show_add_page_dialog.dart
import 'package:diary_mobile/providers/page_provider.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:diary_mobile/widgets/shake_dialog_content.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

void showAddPageDialog(BuildContext context, TaskProvider taskProvider) {
  // Removed scrollToPageId parameter
  DateTime? selectedPageDate = DateTime.now();
  bool hasError = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: const Text('Create New Page'),
            content: ShakeDialogContent(
              shakeTrigger: hasError,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    'A new page will be created by the server for the selected date. Non-completed tasks from the most recent page before this date will be carried over.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedPageDate == null) {
                    setStateSB(() {
                      hasError = true;
                    });
                    HapticFeedback.vibrate();
                    Future.delayed(const Duration(milliseconds: 500), () {
                      setStateSB(() {
                        hasError = false;
                      });
                    });

                    Future.microtask(() {
                      showTopSnackBar(
                        Overlay.of(context),
                        const CustomSnackBar.info(
                          message: 'Please Select A Date',
                        ),
                        displayDuration: Durations.short1,
                      );
                    });
                    return;
                  }

                  taskProvider.clearErrorMessage();

                  try {
                    final int newPageId = await taskProvider.createNewPage(
                      1,
                      selectedPageDate!,
                    );

                    if (newPageId != -1) {
                      Navigator.pop(context);
                      Future.microtask(() {
                        showTopSnackBar(
                          Overlay.of(context),
                          const CustomSnackBar.success(
                            message:
                                'New page created and tasks migrated from previous page',
                          ),
                          displayDuration: Durations.short3,
                        );
                        Provider.of<TaskProvider>(
                          context,
                          listen: false,
                        ).fetchTasks();
                        Provider.of<PageProvider>(
                          context,
                          listen: false,
                        ).fetchPagesByDiary(1);
                      });
                    } else {
                      taskProvider.clearErrorMessage();
                      setStateSB(() {
                        hasError = true;
                      });
                      HapticFeedback.vibrate();
                      Future.delayed(const Duration(milliseconds: 500), () {
                        setStateSB(() {
                          hasError = false;
                        });
                      });

                      Future.microtask(() {
                        showTopSnackBar(
                          Overlay.of(context),
                          const CustomSnackBar.error(
                            message: 'Page Already Created',
                          ),
                          displayDuration: Durations.short1,
                        );
                      });
                    }
                  } catch (e) {
                    setStateSB(() {
                      hasError = true;
                    });
                    HapticFeedback.vibrate();
                    Future.delayed(const Duration(milliseconds: 500), () {
                      setStateSB(() {
                        hasError = false;
                      });
                    });

                    Future.microtask(() {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Error creating page: ${e.toString().replaceAll("Exception: ", "")}',
                          ),
                        ),
                      );
                    });
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
