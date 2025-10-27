import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/feature_flags.dart';
import '../services/data_clear_service.dart';
import 'debug_state.dart';

/// A small draggable / tappable overlay showing current route, user id, and setup approval.
class DebugOverlay extends StatefulWidget {
  const DebugOverlay({super.key});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  bool _expanded = false;
  Offset _offset = const Offset(8, 60);

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode || !FeatureFlags.showDebugOverlay) return const SizedBox.shrink();
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // Constrain a little so it stays visible
            final dx = (_offset.dx + details.delta.dx).clamp(0, MediaQuery.of(context).size.width - 40);
            final dy = (_offset.dy + details.delta.dy).clamp(kToolbarHeight, MediaQuery.of(context).size.height - 40);
            _offset = Offset(dx.toDouble(), dy.toDouble());
          });
        },
        child: _buildCard(),
      ),
    );
  }

  Widget _buildCard({double opacity = 1}) {
    return ValueListenableBuilder(
      valueListenable: DebugState.notifier,
      builder: (context, snap, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.70 * opacity),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 2)),
              ],
            ),
            width: _expanded ? 260 : 130,
            child: DefaultTextStyle(
              style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('DEBUG', style: TextStyle(fontWeight: FontWeight.bold)),
                        Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 14, color: Colors.white70),
                      ],
                    ),
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 4),
                    _kv('Route', snap.route),
                    _kv('User', snap.userId?.substring(0, snap.userId!.length.clamp(0, 8)) ?? '∅'),
                    _kv('Approved', snap.explicitApproved ? 'yes' : 'no'),
                    _kv('Updated', _timeSince(snap.updatedAt)),
                    const SizedBox(height: 8),
                    _buildClearDataButton(),
                    const SizedBox(height: 4),
                    const Text('Tap header to collapse', style: TextStyle(fontSize: 9, color: Colors.white54)),
                  ]
                ],
              ),
            ),
        );
      },
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(text: '$k: ', style: const TextStyle(color: Colors.white70)),
            TextSpan(text: v, style: const TextStyle(color: Colors.white)),
          ]),
        ),
      );

  String _timeSince(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }

  Widget _buildClearDataButton() {
    return GestureDetector(
      onTap: () async {
        try {
          await DataClearService.clearAllLocalData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All local data cleared'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error clearing data: $e'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.withOpacity(0.5)),
        ),
        child: const Text(
          'Clear All Data',
          style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
