import 'package:diary_mobile/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:diary_mobile/widgets/shake_dialog_content.dart';
import 'package:flutter/services.dart'; // For vibration/haptic feedback

void showAddPageDialog(
  BuildContext context,
  TaskProvider taskProvider,
  int? scrollToPageId,
  // REMOVED: Map<int, bool> pageExpandedState, // This parameter is removed
) {
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a Page Date.'),
                        ),
                      );
                    });
                    return;
                  }

                  taskProvider.clearErrorMessage();

                  try {
                    // This line is fine, it just gets the ID, doesn't depend on state.
                    final int? oldMostRecentPageId = taskProvider
                        .getCurrentMostRecentPageId();

                    final int newPageId = await taskProvider.createNewPage(
                      1, // Hardcoded Diary No
                      selectedPageDate!,
                    );

                    if (newPageId != -1) {
                      Navigator.pop(context);
                      setStateSB(() {
                        // The `scrollToPageId = newPageId;` line only updates a local variable
                        // within the dialog's scope, which is fine.
                        // It doesn't directly affect the TaskBoardScreen's _pageToScrollTo
                        // unless you pass it back via Navigator.pop's result or a callback.
                        // If TaskBoardScreen relies on this to scroll after the dialog closes,
                        // you'll need to adjust how TaskBoardScreen consumes this.
                        scrollToPageId =
                            newPageId; // Still fine for local usage
                        // REMOVED: if (oldMostRecentPageId != null) {
                        // REMOVED:   pageExpandedState[oldMostRecentPageId] = false;
                        // REMOVED: } // This block is removed
                      });
                      Future.microtask(() {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'New page created and tasks migrated!',
                            ),
                          ),
                        );
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              taskProvider.errorMessage ??
                                  'Failed to create page.',
                            ),
                          ),
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
