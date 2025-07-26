// import 'package:flutter/material.dart';
// import 'package:diary_pta/models/task_dto.dart';
// import 'package:diary_pta/providers/task_provider.dart';
// import 'package:diary_pta/mixin/taskstatus.dart';

// Widget buildTaskCard(
//   BuildContext context,
//   TaskDto task,
//   TaskProvider taskProvider,
//   bool isDraggableAndEditable,
// ) {
//   final Brightness currentBrightness = Theme.of(context).brightness;

//   final card = GestureDetector(
//     onTap: () {
//       if (isDraggableAndEditable) {
//         _showEditTaskDialog(context, taskProvider, task);
//       }
//     },
//     child: Card(
//       margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
//       elevation: 1.0,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
//       color:
//           currentBrightness == Brightness.dark
//               ? Colors.grey[850]
//               : Colors.white,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
//         child: Row(
//           children: [
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     task.title,
//                     style: TextStyle(
//                       fontSize: 15.0,
//                       fontWeight: FontWeight.w500,
//                       decoration:
//                           task.status == TaskStatus.complete
//                               ? TextDecoration.lineThrough
//                               : null,
//                       color: Theme.of(context).textTheme.bodyLarge?.color,
//                     ),
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 4.0),
//                   Text(
//                     'ID: ${task.id} ${task.parentTaskId != null ? '(Parent: ${task.parentTaskId})' : ''}',
//                     style: TextStyle(fontSize: 11.0, color: Colors.grey[600]),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );

//   if (isDraggableAndEditable) {
//     return LongPressDraggable<TaskDto>(
//       data: task,
//       feedback: Material(
//         elevation: 4.0,
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 200),
//           child: card,
//         ),
//       ),
//       childWhenDragging: Opacity(opacity: 0.5, child: card),
//       child: card,
//     );
//   } else {
//     return card;
//   }
// }

// void _showEditTaskDialog(
//   BuildContext context,
//   TaskProvider taskProvider,
//   TaskDto task,
// ) {
//   final TextEditingController taskTitleController = TextEditingController(
//     text: task.title,
//   );
//   showDialog(
//     context: context,
//     builder: (context) {
//       return AlertDialog(
//         title: const Text('Edit Task Title'),
//         content: TextField(
//           controller: taskTitleController,
//           decoration: const InputDecoration(labelText: 'Task Title'),
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
//                   await taskProvider.updateTask(
//                     task.id,
//                     taskTitleController.text,
//                     task.status,
//                   );
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('Task title updated successfully!'),
//                     ),
//                   );
//                   Navigator.pop(context);
//                 } catch (e) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(
//                         'Failed to update task title: ${taskProvider.errorMessage}',
//                       ),
//                     ),
//                   );
//                 }
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Task title cannot be empty.')),
//                 );
//               }
//             },
//             child: const Text('Update'),
//           ),
//         ],
//       );
//     },
//   );
// }

// void _confirmDeleteTask(
//   BuildContext context,
//   TaskProvider taskProvider,
//   TaskDto task,
// ) {
//   showDialog(
//     context: context,
//     builder: (context) {
//       return AlertDialog(
//         title: const Text('Delete Task'),
//         content: Text('Are you sure you want to delete "${task.title}"?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               try {
//                 await taskProvider.deleteTask(task.id);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Task deleted successfully!')),
//                 );
//                 Navigator.pop(context);
//               } catch (e) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(
//                       'Failed to delete task: ${taskProvider.errorMessage}',
//                     ),
//                   ),
//                 );
//               }
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text('Delete'),
//           ),
//         ],
//       );
//     },
//   );
// }
