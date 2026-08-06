import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

class WayakiGlowButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isPrimary;

  const WayakiGlowButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isPrimary = true,
  });

  @override
  State<WayakiGlowButton> createState() => _WayakiGlowButtonState();
}

class _WayakiGlowButtonState extends State<WayakiGlowButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null || widget.isLoading;

    Color backgroundColor = widget.isPrimary ? AppTheme.primaryColor : Colors.transparent;
    Color textColor = widget.isPrimary ? AppTheme.onLime : Colors.white;
    
    if (isDisabled && widget.isPrimary) {
      backgroundColor = AppTheme.cardLightBackground;
      textColor = AppTheme.textGrey;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: isDisabled ? null : widget.onPressed,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(_isPressed ? 0.98 : (_isHovered && !isDisabled ? 1.02 : 1.0)),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.rPill),
            border: widget.isPrimary ? null : Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              if (widget.isPrimary && !isDisabled && (_isHovered || _isPressed))
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(_isPressed ? 0.4 : 0.25),
                  blurRadius: _isPressed ? 20 : 30,
                  offset: Offset(0, _isPressed ? 4 : 8),
                )
              else if (widget.isPrimary && !isDisabled)
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                else ...[
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (widget.icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(widget.icon, color: textColor, size: 20),
                  ]
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
