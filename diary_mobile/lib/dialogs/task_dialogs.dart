// import 'package:diary_pta/mixin/taskstatus.dart';
// import 'package:diary_pta/providers/task_provider.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';

// void showAddTaskDialog(BuildContext context, int targetPageId) {
//   final TextEditingController taskTitleController = TextEditingController();
//   showDialog(
//     context: context,
//     builder: (context) {
//       return AlertDialog(
//         title: const Text('Add New Task'),
//         content: TextField(
//           controller: taskTitleController,
//           decoration: InputDecoration(
//             labelText: 'Task Title',
//             hintText: 'Add to Page $targetPageId',
//           ),
//           autofocus: true,
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               if (taskTitleController.text.isNotEmpty) {
//                 try {
//                   await Provider.of<TaskProvider>(
//                     context,
//                     listen: false,
//                   ).addTask(
//                     taskTitleController.text,
//                     TaskStatus.backlog,
//                     pageId: targetPageId,
//                   );
//                   Future.microtask(
//                     () => ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text('Task added successfully!')),
//                     ),
//                   );
//                   Navigator.pop(context);
//                 } catch (e) {
//                   Future.microtask(
//                     () => ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(
//                           'Failed to add task: ${Provider.of<TaskProvider>(context, listen: false).errorMessage}',
//                         ),
//                       ),
//                     ),
//                   );
//                 }
//               } else {
//                 Future.microtask(
//                   () => ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('Task title cannot be empty.'),
//                     ),
//                   ),
//                 );
//               }
//             },
//             child: const Text('Add'),
//           ),
//         ],
//       );
//     },
//   );
// }

// void showAddPageDialog(
//   BuildContext context,
//   TaskProvider taskProvider,
//   void Function(VoidCallback fn) setState,
//   void Function(int) onPageCreated, // callback to set scroll target
//   Map<int, bool> pageExpandedState,
// ) {
//   final TextEditingController diaryNoController = TextEditingController();
//   DateTime? selectedPageDate = DateTime.now();

//   showDialog(
//     context: context,
//     builder: (context) {
//       return StatefulBuilder(
//         builder: (context, setStateSB) {
//           return AlertDialog(
//             title: const Text('Create New Page'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 TextField(
//                   controller: diaryNoController,
//                   keyboardType: TextInputType.number,
//                   decoration: const InputDecoration(
//                     labelText: 'Diary Number',
//                     hintText: 'e.g., 1 (Diary ID)',
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 ListTile(
//                   title: Text(
//                     selectedPageDate == null
//                         ? 'Select Page Date'
//                         : 'Page Date: ${DateFormat('yyyy-MM-dd').format(selectedPageDate!)}',
//                   ),
//                   trailing: const Icon(Icons.calendar_today),
//                   onTap: () async {
//                     final DateTime? picked = await showDatePicker(
//                       context: context,
//                       initialDate: selectedPageDate ?? DateTime.now(),
//                       firstDate: DateTime(2000),
//                       lastDate: DateTime(2101),
//                     );
//                     if (picked != null && picked != selectedPageDate) {
//                       setStateSB(() {
//                         selectedPageDate = picked;
//                       });
//                     }
//                   },
//                 ),
//                 const SizedBox(height: 16),
//                 const Text(
//                   'A new page will be created by the server for the specified Diary and Date. Non-completed tasks from the most recent page before this date will be carried over.',
//                   style: TextStyle(fontSize: 12, color: Colors.grey),
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text('Cancel'),
//               ),
//               ElevatedButton(
//                 onPressed: () async {
//                   final int? diaryNo = int.tryParse(diaryNoController.text);
//                   if (diaryNo == null || selectedPageDate == null) {
//                     Future.microtask(
//                       () => ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text(
//                             'Please enter a valid Diary Number and select a Page Date.',
//                           ),
//                         ),
//                       ),
//                     );
//                     return;
//                   }

//                   try {
//                     final int? oldMostRecentPageId =
//                         taskProvider.getCurrentMostRecentPageId();

//                     final int newPageId = await taskProvider.createNewPage(
//                       diaryNo,
//                       selectedPageDate!,
//                     );
//                     Navigator.pop(context);

//                     if (newPageId != -1) {
//                       setState(() {
//                         onPageCreated(newPageId); // ✅ Use this
//                         if (oldMostRecentPageId != null) {
//                           pageExpandedState[oldMostRecentPageId] = false;
//                         }
//                       });
//                     }

//                     Future.microtask(
//                       () => ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text('New page created and tasks migrated!'),
//                         ),
//                       ),
//                     );
//                   } catch (e) {
//                     Future.microtask(
//                       () => ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text(
//                             'Error creating page: ${taskProvider.errorMessage}',
//                           ),
//                         ),
//                       ),
//                     );
//                   }
//                 },
//                 child: const Text('Create Page'),
//               ),
//             ],
//           );
//         },
//       );
//     },
//   );
// }
