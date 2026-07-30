import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/pin_keypad.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';

/// Real transaction-PIN management (backed by /auth/pin, /auth/pin/verify)
/// plus device-level toggles. Biometric login and trusted-device are
/// explicitly local preferences only — Flutter Web has no real biometric
/// API to hook into, so they're labeled honestly rather than pretending to
/// enforce something the platform can't actually check here.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Security'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TouchScale(
                onTap: () => _openPinFlow(context, appState),
                child: BybitCard(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      const CircleIconWrap(icon: Icons.pin_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.hasPin
                                  ? 'Change transaction PIN'
                                  : 'Set transaction PIN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              appState.hasPin
                                  ? 'Required to confirm money movement'
                                  : 'Not set yet — required before your next send',
                              style: const TextStyle(
                                color: BybitPalette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: BybitPalette.muted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TouchScale(
                onTap: () => _openPasswordFlow(context, appState),
                child: BybitCard(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      const CircleIconWrap(icon: Icons.password_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.hasPassword
                                  ? 'Change password'
                                  : 'Set password',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              appState.hasPassword
                                  ? 'Used to sign in with email + password'
                                  : 'Not set yet — you can add one for password sign-in',
                              style: const TextStyle(
                                color: BybitPalette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: BybitPalette.muted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _toggleRow(
                icon: Icons.fingerprint_rounded,
                title: 'Biometric login',
                subtitle: 'Use your device\'s screen lock, where supported',
                checked: appState.biometricEnabled,
                onChanged: appState.setBiometricEnabled,
              ),
              _toggleRow(
                icon: Icons.phonelink_lock_rounded,
                title: 'Trusted device',
                subtitle: 'Skip extra checks on this device',
                checked: appState.trustedDevice,
                onChanged: appState.setTrustedDevice,
              ),
              const SizedBox(height: 12),
              BybitCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: BybitPalette.accent,
                      size: 21,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assistant boundary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'No automated flow enters your PIN, password, OTP, or biometrics on your behalf.',
                            style: TextStyle(
                              color: BybitPalette.muted,
                              fontSize: 11.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool checked,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TouchScale(
        onTap: () => onChanged(!checked),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: BybitPalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF242832)),
          ),
          child: Row(
            children: [
              CircleIconWrap(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BybitPalette.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 26,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: checked ? BybitPalette.accent : BybitPalette.surface2,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Align(
                  alignment:
                      checked ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: checked ? Colors.black : BybitPalette.muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPinFlow(BuildContext context, KashAppState appState) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PinFlowSheet(hasPin: appState.hasPin),
    );
  }

  void _openPasswordFlow(BuildContext context, KashAppState appState) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PasswordFlowSheet(hasPassword: appState.hasPassword),
    );
  }
}

class CircleIconWrap extends StatelessWidget {
  final IconData icon;
  const CircleIconWrap({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: BybitPalette.surface2,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: BybitPalette.accent, size: 19),
    );
  }
}

enum _PinStep { current, create, confirm }

/// Set-or-change PIN flow: if a PIN already exists, first confirm it, then
/// capture the new PIN twice (create + confirm) before saving.
class _PinFlowSheet extends StatefulWidget {
  final bool hasPin;
  const _PinFlowSheet({required this.hasPin});

  @override
  State<_PinFlowSheet> createState() => _PinFlowSheetState();
}

class _PinFlowSheetState extends State<_PinFlowSheet> {
  static const _pinLength = 4;
  late _PinStep _step = widget.hasPin ? _PinStep.current : _PinStep.create;
  String _currentPin = '';
  String _newPin = '';
  String _pin = '';
  bool _busy = false;
  String? _error;

  String get _title {
    switch (_step) {
      case _PinStep.current:
        return 'Enter current PIN';
      case _PinStep.create:
        return 'Create a new PIN';
      case _PinStep.confirm:
        return 'Confirm your PIN';
    }
  }

  void _tapDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 180), _advance);
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _advance() async {
    if (!mounted) return;
    switch (_step) {
      case _PinStep.current:
        setState(() => _busy = true);
        final ok = await ApiService.verifyPin(_pin);
        if (!mounted) return;
        if (!ok) {
          setState(() {
            _busy = false;
            _pin = '';
            _error = 'Incorrect PIN — try again';
          });
          return;
        }
        setState(() {
          _busy = false;
          _currentPin = _pin;
          _pin = '';
          _step = _PinStep.create;
        });
        return;
      case _PinStep.create:
        setState(() {
          _newPin = _pin;
          _pin = '';
          _step = _PinStep.confirm;
        });
        return;
      case _PinStep.confirm:
        if (_pin != _newPin) {
          setState(() {
            _pin = '';
            _newPin = '';
            _step = _PinStep.create;
            _error = "PINs didn't match — start again";
          });
          return;
        }
        setState(() => _busy = true);
        try {
          await ApiService.setPin(
            pin: _newPin,
            currentPin: widget.hasPin ? _currentPin : null,
          );
          if (!mounted) return;
          context.read<KashAppState>().markPinSet();
          Navigator.of(context).pop();
          BybitToast.success(context, 'Transaction PIN saved');
        } on ApiException catch (err) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _pin = '';
            _step = _PinStep.create;
            _error = err.message;
          });
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TouchScale(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: BybitPalette.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: BybitPalette.muted2,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: List.generate(_pinLength, (index) {
                final filled = index < _pin.length;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Container(
                    width: 42,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BybitPalette.input,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          filled
                              ? Border.all(color: BybitPalette.accent)
                              : null,
                    ),
                    child:
                        filled
                            ? const Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 12,
                            )
                            : null,
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: BybitPalette.red,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _busy
                ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: BybitPalette.accent,
                    ),
                  ),
                )
                : NumericKeypad(onDigit: _tapDigit, onBackspace: _backspace),
          ],
        ),
      ),
    );
  }
}

/// Set-or-change password flow. Only asks for the current password when
/// one already exists — accounts created via Telegram or OTP-only sign-in
/// may have none yet.
class _PasswordFlowSheet extends StatefulWidget {
  final bool hasPassword;
  const _PasswordFlowSheet({required this.hasPassword});

  @override
  State<_PasswordFlowSheet> createState() => _PasswordFlowSheetState();
}

class _PasswordFlowSheetState extends State<_PasswordFlowSheet> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPassword = _newController.text;
    if (newPassword.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (newPassword != _confirmController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiService.changePassword(
        newPassword: newPassword,
        currentPassword:
            widget.hasPassword ? _currentController.text : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      BybitToast.success(
        context,
        widget.hasPassword ? 'Password changed' : 'Password set',
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = err.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.hasPassword ? 'Change password' : 'Set password',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TouchScale(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: BybitPalette.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: BybitPalette.muted2,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (widget.hasPassword) ...[
                BybitTextField(
                  label: 'Current password',
                  hint: 'Enter your current password',
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                  controller: _currentController,
                ),
                const SizedBox(height: 18),
              ],
              BybitTextField(
                label: 'New password',
                hint: 'At least 8 characters',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                controller: _newController,
              ),
              const SizedBox(height: 18),
              BybitTextField(
                label: 'Confirm new password',
                hint: 'Re-enter your new password',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                controller: _confirmController,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: BybitPalette.red,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              BybitPrimaryButton(
                label: _submitting ? 'Saving…' : 'Save',
                enabled: !_submitting,
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
