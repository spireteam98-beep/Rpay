import 'package:flutter/material.dart';

import '../constants/brand.dart';

/// The Fareenn wordmark — the exact white 3D lettering (and ®) from the
/// master logo, on a transparent background. Use it on the brand red or
/// on black. Pass [tint] only where it must sit on a light surface.
class FareennLogo extends StatelessWidget {
  final double height;
  final Color? tint;

  const FareennLogo({super.key, this.height = 32, this.tint});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: kBrandName,
      image: true,
      child: Image.asset(
        kBrandWordmarkAsset,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        color: tint,
        colorBlendMode: tint == null ? null : BlendMode.srcIn,
        // Never leave a blank gap if the asset is still loading.
        gaplessPlayback: true,
      ),
    );
  }
}
