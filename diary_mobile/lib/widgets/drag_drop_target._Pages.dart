import 'package:flutter/material.dart';
import 'package:diary_mobile/mixin/taskstatus.dart';
import 'package:diary_mobile/providers/task_provider.dart';
import 'package:diary_mobile/widgets/status_drop_target.dart';

class DragDropTargetForPage extends StatelessWidget {
  const DragDropTargetForPage({
    super.key,
    required this.taskProvider,
    required this.currentBrightness,
  });

  final TaskProvider taskProvider;
  final Brightness currentBrightness;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Theme.of(context).cardColor.withOpacity(1),
        padding: const EdgeInsets.all(4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: TaskStatus.values
              .where((status) => status != TaskStatus.deleted)
              .map(
                (status) => buildStatusDropTarget(
                  context,
                  status,
                  taskProvider,
                  currentBrightness,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
