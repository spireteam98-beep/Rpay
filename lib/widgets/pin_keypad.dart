import 'package:flutter/material.dart';
import 'bybit_wallet_ui.dart';
import 'touch_scale.dart';

/// Circular passcode-style keypad — 1-9, blank, 0, backspace — shared by
/// every PIN and one-time-code screen. Mirrors the native iOS/Android
/// passcode keypad look (filled circular digit keys, bare backspace icon)
/// instead of the plain grid-button layout it replaces.
class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'del'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          _rows.map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map(_key).toList(),
              ),
            );
          }).toList(),
    );
  }

  Widget _key(String key) {
    if (key.isEmpty) return const SizedBox(width: 68, height: 68);
    if (key == 'del') {
      return TouchScale(
        onTap: onBackspace,
        pressedScale: 0.88,
        child: const SizedBox(
          width: 68,
          height: 68,
          child: Icon(
            Icons.backspace_outlined,
            color: BybitPalette.muted2,
            size: 24,
          ),
        ),
      );
    }
    return TouchScale(
      onTap: () => onDigit(key),
      pressedScale: 0.9,
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: BybitPalette.surface2,
          shape: BoxShape.circle,
        ),
        child: Text(
          key,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
