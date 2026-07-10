import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tactile press wrapper: scales down softly and fires a light haptic,
/// so every touch feels physical — Apple-style. On mouse/trackpad input it
/// also shows a pointer cursor and a gentle hover lift, so the same widget
/// feels right whether it's tapped on a phone or clicked on web/desktop.
class TouchScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final double hoverScale;
  final bool haptic;

  const TouchScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.hoverScale = 1.02,
    this.haptic = true,
  });

  @override
  State<TouchScale> createState() => _TouchScaleState();
}

class _TouchScaleState extends State<TouchScale> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool v) => setState(() => _pressed = v);
  void _setHovered(bool v) => setState(() => _hovered = v);

  @override
  Widget build(BuildContext context) {
    final scale =
        _pressed ? widget.pressedScale : (_hovered ? widget.hoverScale : 1.0);
    return MouseRegion(
      cursor:
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: () {
          if (widget.haptic) HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: scale,
          duration: Duration(milliseconds: _pressed ? 100 : 160),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
