import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../state/kash_app_state.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/code_boxes_input.dart';
import '../../widgets/kash_widgets.dart';
import '../../widgets/pin_keypad.dart';
import 'kyc_screen.dart';

enum _PinStep { create, confirm }

/// Last step of signup: a 4-digit transaction PIN, asked for once right
/// after the email is confirmed rather than deferred to the first transfer
/// — this PIN is what unlocks sending money and other transactions later.
class PinSetupScreen extends StatefulWidget {
  final String email;

  const PinSetupScreen({super.key, required this.email});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  static const _pinLength = 4;

  final TextEditingController _codeController = TextEditingController();
  _PinStep _step = _PinStep.create;
  String _firstPin = '';
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _tapKey(String v) {
    if (_codeController.text.length >= _pinLength) return;
    setState(() => _error = null);
    _codeController.text += v;
  }

  void _backspace() {
    final text = _codeController.text;
    if (text.isEmpty) return;
    _codeController.text = text.substring(0, text.length - 1);
  }

  Future<void> _onCompleted(String pin) async {
    if (_step == _PinStep.create) {
      setState(() {
        _firstPin = pin;
        _step = _PinStep.confirm;
        _codeController.clear();
      });
      return;
    }

    if (pin != _firstPin) {
      setState(() {
        _error = "PINs didn't match — start again";
        _step = _PinStep.create;
        _firstPin = '';
        _codeController.clear();
      });
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.setPin(pin: pin);
      if (!mounted) return;
      final appState = context.read<KashAppState>();
      appState.markPinSet();
      appState.verifyPhone();

      final signedIn = await AuthService.signInSavedUser();
      if (!mounted) return;
      if (!signedIn) {
        setState(() {
          _submitting = false;
          _error = 'Unable to sign in. Try again.';
          _step = _PinStep.create;
          _firstPin = '';
          _codeController.clear();
        });
        return;
      }

      Navigator.of(context).push(kashRoute(const KycScreen()));
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = err.message;
        _step = _PinStep.create;
        _firstPin = '';
        _codeController.clear();
      });
    }
  }

  String get _title {
    return _step == _PinStep.create ? 'Create your PIN' : 'Confirm your PIN';
  }

  String get _subtitle {
    return _step == _PinStep.create
        ? 'This 4-digit PIN unlocks sending money and other transactions.'
        : 'Enter it once more to confirm.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Set up your PIN'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                _title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _subtitle,
                style: const TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 14,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: BybitPalette.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: CodeBoxesInput(
                  controller: _codeController,
                  length: _pinLength,
                  onCompleted: _onCompleted,
                ),
              ),
              const SizedBox(height: 28),
              NumericKeypad(onDigit: _tapKey, onBackspace: _backspace),
              if (_submitting) ...[
                const SizedBox(height: 16),
                const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: BybitPalette.accent,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
