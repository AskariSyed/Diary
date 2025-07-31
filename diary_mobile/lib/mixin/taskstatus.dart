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
        return 'backlog';
      case TaskStatus.toDiscuss:
        return 'To Discuss';
      case TaskStatus.inProgress:
        return 'in process';
      case TaskStatus.onHold:
        return 'on hold';
      case TaskStatus.toFollowUp:
        return 'To follow up';
      case TaskStatus.complete:
        return 'completed';
      case TaskStatus.deleted:
        return 'deleted';
    }
  }

  // A static method to create from a string
  static TaskStatus fromApiString(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'backlog':
        return TaskStatus.backlog;
      case 'to discuss':
        return TaskStatus.toDiscuss;
      case 'in process':
        return TaskStatus.inProgress;
      case 'on hold':
        return TaskStatus.onHold;
      case 'to follow up':
        return TaskStatus.toFollowUp;
      case 'completed':
        return TaskStatus.complete;
      case 'deleted':
        return TaskStatus.deleted;

      default:
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

// This is the correct way to implement a custom controller for ExpansionTile
class DiaryExpansionTileController extends ChangeNotifier
    implements ExpansibleController {
  AnimationController? _animationController;
  bool _isExpanded = false; // Internal state to track expansion

  @override
  bool get isExpanded => _isExpanded;

  // Called by ExpansionTile to provide its internal AnimationController
  // This method is part of the ExpansionTileController interface

  void attach(AnimationController controller) {
    if (_animationController == controller) {
      return; // Already attached to this controller
    }
    _animationController?.removeListener(
      _handleAnimationChange,
    ); // Clean up old listener
    _animationController = controller;
    _animationController!.addListener(_handleAnimationChange);
    // Initialize _isExpanded based on the current state of the animation controller
    _isExpanded = _animationController!.value == 1.0;
  }

  // Called by ExpansionTile when it's detached (e.g., widget removed from tree)
  // This method is part of the ExpansionTileController interface

  void detach() {
    _animationController?.removeListener(_handleAnimationChange);
    _animationController = null;
  }

  void _handleAnimationChange() {
    // Determine expanded state based on animation value
    final bool newExpandedState = _animationController!.value == 1.0;
    if (_isExpanded != newExpandedState) {
      _isExpanded = newExpandedState;
      // Notify listeners (e.g., your UI or state managers)
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
      // Defer the animation call to the next frame to avoid conflicts during build
      Future.microtask(() {
        if (_animationController != null &&
            _animationController!.status != AnimationStatus.completed) {
          _animationController!.forward();
          _isExpanded = true; // Optimistic update
          notifyListeners(); // Notify listeners of the state change
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
      // Defer the animation call to the next frame
      Future.microtask(() {
        if (_animationController != null &&
            _animationController!.status != AnimationStatus.dismissed) {
          _animationController!.reverse();
          _isExpanded = false; // Optimistic update
          notifyListeners(); // Notify listeners of the state change
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
