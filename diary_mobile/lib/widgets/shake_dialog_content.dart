import 'package:flutter/material.dart';

class ShakeDialogContent extends StatefulWidget {
  final Widget child;
  final bool shakeTrigger;

  const ShakeDialogContent({
    super.key,
    required this.child,
    required this.shakeTrigger,
  });

  @override
  State<ShakeDialogContent> createState() => _ShakeDialogContentState();
}

class _ShakeDialogContentState extends State<ShakeDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    final double shakeDistance = 8.0;

    _offsetAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -shakeDistance),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -shakeDistance, end: shakeDistance),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: shakeDistance, end: -shakeDistance),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -shakeDistance, end: shakeDistance),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: shakeDistance, end: 0.0),
        weight: 1,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant ShakeDialogContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeTrigger && !oldWidget.shakeTrigger) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
