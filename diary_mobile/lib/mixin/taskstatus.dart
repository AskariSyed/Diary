import 'package:flutter/material.dart';

enum TaskStatus {
  backlog,
  inProgress,
  toDiscuss,
  toFollowUp,
  onHold,
  complete,
  deleted,
}

extension TaskStatusExtension on TaskStatus {
  String toApiString() {
    switch (this) {
      case TaskStatus.backlog:
        return 'To-Do';
      case TaskStatus.toDiscuss:
        return 'To Discuss';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.onHold:
        return 'On Hold';
      case TaskStatus.toFollowUp:
        return 'Follow-Up';
      case TaskStatus.complete:
        return 'Completed';
      case TaskStatus.deleted:
        return 'Deleted';
    }
  }

  static TaskStatus fromApiString(String statusString) {
    switch (statusString) {
      case 'To-Do':
        return TaskStatus.backlog;
      case 'To Discuss':
        return TaskStatus.toDiscuss;
      case 'In Progress':
        return TaskStatus.inProgress;
      case 'On Hold':
        return TaskStatus.onHold;
      case 'Follow-Up':
        return TaskStatus.toFollowUp;
      case 'Completed':
        return TaskStatus.complete;
      case 'Deleted':
        return TaskStatus.deleted;

      default:
        // ignore: avoid_print
        print(
          'Warning: Unknown TaskStatus string received from API: $statusString. Defaulting to backlog.',
        );

        return TaskStatus.backlog;
    }
  }
}

extension StringToTaskStatusExtension on String {
  TaskStatus fromApiString() {
    return TaskStatusExtension.fromApiString(this);
  }
}

class DiaryExpansionTileController extends ChangeNotifier
    implements ExpansibleController {
  AnimationController? _animationController;
  bool _isExpanded = false;

  @override
  bool get isExpanded => _isExpanded;
  void attach(AnimationController controller) {
    if (_animationController == controller) {
      return;
    }
    _animationController?.removeListener(_handleAnimationChange);
    _animationController = controller;
    _animationController!.addListener(_handleAnimationChange);

    _isExpanded = _animationController!.value == 1.0;
  }

  void detach() {
    _animationController?.removeListener(_handleAnimationChange);
    _animationController = null;
  }

  void _handleAnimationChange() {
    final bool newExpandedState = _animationController!.value == 1.0;
    if (_isExpanded != newExpandedState) {
      _isExpanded = newExpandedState;
      notifyListeners();
    }
  }

  @override
  void expand() {
    if (_animationController == null) {
      debugPrint('ExpansibleController: AnimationController not attached yet.');
      return;
    }
    if (_animationController!.status != AnimationStatus.completed) {
      Future.microtask(() {
        if (_animationController != null &&
            _animationController!.status != AnimationStatus.completed) {
          _animationController!.forward();
          _isExpanded = true;
          notifyListeners();
        }
      });
    }
  }

  @override
  void collapse() {
    if (_animationController == null) {
      debugPrint('ExpansibleController: AnimationController not attached yet.');
      return;
    }
    if (_animationController!.status != AnimationStatus.dismissed) {
      Future.microtask(() {
        if (_animationController != null &&
            _animationController!.status != AnimationStatus.dismissed) {
          _animationController!.reverse();
          _isExpanded = false;
          notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController?.removeListener(_handleAnimationChange);
    _animationController = null;
    super.dispose();
  }
}
