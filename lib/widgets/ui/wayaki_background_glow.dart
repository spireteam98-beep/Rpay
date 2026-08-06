import 'dart:ui';
import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

class WayakiBackgroundGlow extends StatelessWidget {
  final Widget child;

  const WayakiBackgroundGlow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background color
        Container(color: AppTheme.darkBackground),
        
        // Top right lime glow
        Positioned(
          top: -150,
          right: -100,
          width: 350,
          height: 350,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withOpacity(0.20),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: const SizedBox(),
            ),
          ),
        ),
        
        // Bottom left green glow
        Positioned(
          bottom: -150,
          left: -100,
          width: 350,
          height: 350,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.greenTech.withOpacity(0.15),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: const SizedBox(),
            ),
          ),
        ),

        // Foreground content
        Positioned.fill(child: child),
      ],
    );
  }
}
