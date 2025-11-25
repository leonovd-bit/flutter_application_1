import 'package:flutter/material.dart';

/// A wrapper widget that enables swipe-to-go-back gesture on pages with a back button.
/// This mimics iOS-style navigation gestures on Android.
/// 
/// Usage: Wrap your Scaffold widget with SwipeablePage:
/// ```dart
/// return SwipeablePage(
///   child: Scaffold(
///     appBar: AppBar(...),
///     body: ...,
///   ),
/// );
/// ```
class SwipeablePage extends StatefulWidget {
  final Widget child;
  final bool canSwipe;
  final VoidCallback? onSwipeStart;
  final VoidCallback? onSwipeCancel;

  const SwipeablePage({
    super.key,
    required this.child,
    this.canSwipe = true,
    this.onSwipeStart,
    this.onSwipeCancel,
  });

  @override
  State<SwipeablePage> createState() => _SwipeablePageState();
}

class _SwipeablePageState extends State<SwipeablePage> {
  double _dragDistance = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.canSwipe) {
      return widget.child;
    }

    return GestureDetector(
      onHorizontalDragStart: (details) {
        // Start tracking swipe from left third of screen for easier gesture
        if (details.globalPosition.dx < MediaQuery.of(context).size.width / 3) {
          setState(() {
            _isDragging = true;
            _dragDistance = 0;
          });
          widget.onSwipeStart?.call();
        }
      },
      onHorizontalDragUpdate: (details) {
        if (_isDragging && details.delta.dx > 0) {
          setState(() {
            _dragDistance += details.delta.dx;
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (_isDragging) {
          // If swiped more than 80 pixels or velocity is moderate, trigger back
          final shouldPop = _dragDistance > 80 || 
                           (details.primaryVelocity != null && details.primaryVelocity! > 300);
          
          if (shouldPop && Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            widget.onSwipeCancel?.call();
          }
          
          setState(() {
            _isDragging = false;
            _dragDistance = 0;
          });
        }
      },
      onHorizontalDragCancel: () {
        if (_isDragging) {
          setState(() {
            _isDragging = false;
            _dragDistance = 0;
          });
          widget.onSwipeCancel?.call();
        }
      },
      child: widget.child,
    );
  }
}
