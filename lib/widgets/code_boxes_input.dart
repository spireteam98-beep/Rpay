import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bybit_wallet_ui.dart';

/// Row of code-entry boxes bound to [controller] — digits typed on an
/// external [NumericKeypad] land here by writing straight to the
/// controller, and a transparent real text field stacked on top of the
/// boxes also accepts native OS paste (long-press paste, Cmd/Ctrl+V), so a
/// copied code can be dropped in with one action instead of tapped digit
/// by digit. Calls [onCompleted] once the moment the code reaches
/// [length].
class CodeBoxesInput extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;

  const CodeBoxesInput({
    super.key,
    required this.controller,
    required this.length,
    this.onCompleted,
  });

  @override
  State<CodeBoxesInput> createState() => _CodeBoxesInputState();
}

class _CodeBoxesInputState extends State<CodeBoxesInput> {
  final FocusNode _focusNode = FocusNode();
  String _lastCompleted = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChange);
  }

  void _handleChange() {
    if (!mounted) return;
    setState(() {});
    final text = widget.controller.text;
    if (text.length == widget.length && text != _lastCompleted) {
      _lastCompleted = text;
      widget.onCompleted?.call(text);
    } else if (text.length < widget.length) {
      _lastCompleted = '';
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (i) {
              final active = i == text.length;
              final filled = i < text.length;
              return Container(
                width: 48,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BybitPalette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        active
                            ? BybitPalette.accent
                            : const Color(0xFF242832),
                    width: active ? 1.4 : 1,
                  ),
                ),
                child: Text(
                  filled ? text[i] : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                autofocus: true,
                showCursor: false,
                cursorWidth: 0,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
