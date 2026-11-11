import 'package:flutter/material.dart';

/// Blue "verified" badge shown on the avatar of KYC-approved users.
class VerifiedTick extends StatelessWidget {
  final double size;
  const VerifiedTick({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1D9BF0),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: size * 0.11),
      ),
      child: Icon(Icons.check_rounded, color: Colors.white, size: size * 0.68),
    );
  }
}
