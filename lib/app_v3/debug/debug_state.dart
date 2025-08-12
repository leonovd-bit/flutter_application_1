import 'package:flutter/foundation.dart';

/// Immutable snapshot of lightweight runtime debug data.
class DebugSnapshot {
  final String route;
  final String? userId;
  final bool explicitApproved;
  final DateTime updatedAt;

  const DebugSnapshot({
    required this.route,
    required this.userId,
    required this.explicitApproved,
    required this.updatedAt,
  });

  factory DebugSnapshot.initial() => DebugSnapshot(
        route: '∅',
        userId: null,
        explicitApproved: false,
        updatedAt: DateTime.now(),
      );

  DebugSnapshot copyWith({String? route, String? userId, bool? explicitApproved}) => DebugSnapshot(
        route: route ?? this.route,
        userId: userId ?? this.userId,
        explicitApproved: explicitApproved ?? this.explicitApproved,
        updatedAt: DateTime.now(),
      );
}

/// Global debug state. Lightweight and safe for release (guarded by overlay flag elsewhere).
class DebugState {
  static final ValueNotifier<DebugSnapshot> notifier =
      ValueNotifier<DebugSnapshot>(DebugSnapshot.initial());

  static void update({String? route, String? userId, bool? explicitApproved}) {
    final current = notifier.value;
    final next = current.copyWith(
      route: route,
      userId: userId,
      explicitApproved: explicitApproved,
    );
    // Avoid needless rebuilds.
    if (next.route != current.route ||
        next.userId != current.userId ||
        next.explicitApproved != current.explicitApproved) {
      notifier.value = next;
    }
  }

  static void updateRoute(String route) => update(route: route);
  static void updateUser(String? userId) => update(userId: userId);
  static void updateExplicit(bool approved) => update(explicitApproved: approved);
}
