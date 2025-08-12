import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Floating badge to visually confirm refined OneDrive project build.
class BuildBadge extends StatelessWidget {
  final String label;
  const BuildBadge({super.key, this.label = 'REFINED BUILD'});

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
