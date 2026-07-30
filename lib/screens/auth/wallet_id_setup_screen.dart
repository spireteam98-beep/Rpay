import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../state/kash_app_state.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/kash_widgets.dart';
import '../../widgets/touch_scale.dart';
import 'pin_setup_screen.dart';

enum _WalletIdOption { phone, email, username }

/// New signup step: lets the user pick which identifier they hand out to
/// receive money from other Wayaki users — their phone number, their email,
/// or a custom handle. Runs right after email verification and before the
/// transaction PIN is set.
class WalletIdSetupScreen extends StatefulWidget {
  final String email;

  const WalletIdSetupScreen({super.key, required this.email});

  @override
  State<WalletIdSetupScreen> createState() => _WalletIdSetupScreenState();
}

class _WalletIdSetupScreenState extends State<WalletIdSetupScreen> {
  _WalletIdOption _selected = _WalletIdOption.phone;
  final TextEditingController _usernameController = TextEditingController();
  Timer? _debounce;
  bool _checking = false;
  bool? _available;
  bool _submitting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    setState(() => _available = null);
    _debounce?.cancel();
    final username = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _checking = true);
      final available = await ApiService.checkUsernameAvailable(username);
      if (!mounted) return;
      setState(() {
        _checking = false;
        _available = available;
      });
    });
  }

  bool get _canContinue {
    if (_submitting) return false;
    if (_selected != _WalletIdOption.username) return true;
    return _available == true;
  }

  Future<void> _continue() async {
    if (!_canContinue) return;
    setState(() => _submitting = true);
    try {
      await ApiService.setWalletId(
        type: _selected.name,
        username:
            _selected == _WalletIdOption.username
                ? _usernameController.text.trim().toLowerCase()
                : null,
      );
      if (!mounted) return;
      context.read<KashAppState>().setWalletIdLocal(
        type: _selected.name,
        username:
            _selected == _WalletIdOption.username
                ? _usernameController.text.trim().toLowerCase()
                : null,
      );
      Navigator.of(
        context,
      ).push(kashRoute(PinSetupScreen(email: widget.email)));
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Set up your Wallet ID'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose your Wallet ID',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This is what you\'ll share so other Wayaki users can send you money.',
                style: TextStyle(color: BybitPalette.muted2, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _optionTile(
                option: _WalletIdOption.phone,
                icon: Icons.phone_iphone_rounded,
                title: 'Phone number',
                subtitle: appState.phoneNumber,
              ),
              const SizedBox(height: 12),
              _optionTile(
                option: _WalletIdOption.email,
                icon: Icons.alternate_email_rounded,
                title: 'Email address',
                subtitle: widget.email,
              ),
              const SizedBox(height: 12),
              _optionTile(
                option: _WalletIdOption.username,
                icon: Icons.badge_outlined,
                title: 'Custom username',
                subtitle: 'Pick a handle, e.g. @mohamed',
              ),
              if (_selected == _WalletIdOption.username) ...[
                const SizedBox(height: 14),
                _usernameField(),
              ],
              const SizedBox(height: 28),
              BybitPrimaryButton(
                label: _submitting ? 'Saving…' : 'Continue',
                enabled: _canContinue,
                onTap: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionTile({
    required _WalletIdOption option,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final active = _selected == option;
    return TouchScale(
      onTap: () => setState(() => _selected = option),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? BybitPalette.accent : const Color(0xFF242832),
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    active
                        ? BybitPalette.accent.withValues(alpha: 0.16)
                        : BybitPalette.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: active ? BybitPalette.accent : BybitPalette.muted,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BybitPalette.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              active
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: active ? BybitPalette.accent : BybitPalette.muted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _usernameField() {
    return TextField(
      controller: _usernameController,
      onChanged: _onUsernameChanged,
      autofocus: true,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
        LengthLimitingTextInputFormatter(20),
      ],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'username',
        prefixText: '@',
        prefixStyle: const TextStyle(color: BybitPalette.muted),
        hintStyle: const TextStyle(color: BybitPalette.muted),
        suffixIcon:
            _checking
                ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BybitPalette.accent,
                    ),
                  ),
                )
                : _available == null
                ? null
                : Icon(
                  _available!
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: _available! ? BybitPalette.green : BybitPalette.red,
                ),
        filled: true,
        fillColor: BybitPalette.input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
