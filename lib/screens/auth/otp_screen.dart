import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../services/auth_service.dart';
import '../../state/kash_app_state.dart';
import '../../widgets/kash_widgets.dart';
import 'kyc_screen.dart';

/// Step 3: verify the phone with a 6-digit code.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<String> _digits = List.filled(6, '');
  int _filled = 0;

  void _tapKey(String v) {
    setState(() {
      if (v == '<') {
        if (_filled > 0) {
          _filled--;
          _digits[_filled] = '';
        }
      } else if (_filled < 6) {
        _digits[_filled] = v;
        _filled++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final phoneNumber = context.watch<KashAppState>().phoneNumber;
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: const KashBackBar('Verify phone'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Enter the 6-digit code',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We sent an SMS to $phoneNumber',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final active = i == _filled;
                  return Container(
                    width: 48,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.cardDarkBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            active
                                ? AppTheme.primaryColor
                                : AppTheme.glassStroke,
                        width: active ? 1.4 : 1,
                      ),
                    ),
                    child: Text(
                      _digits[i],
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Resend code (0:42)'),
                ),
              ),
              const SizedBox(height: 18),
              _keypad(),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Verify',
                onTap: _filled == 6
                    ? () async {
                        final signedIn = await AuthService.signInSavedUser();
                        if (!signedIn) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Unable to sign in. Please try again.'),
                            ),
                          );
                          return;
                        }

                        context.read<KashAppState>().verifyPhone();
                        if (!mounted) return;
                        Navigator.of(context).push(kashRoute(const KycScreen()));
                      }
                    : () {},
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keypad() {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.1,
      children:
          keys.map((k) {
            if (k.isEmpty) return const SizedBox.shrink();
            return TouchScaleKey(label: k, onTap: () => _tapKey(k));
          }).toList(),
    );
  }
}

class TouchScaleKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const TouchScaleKey({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child:
            label == '<'
                ? const Icon(
                  Icons.backspace_outlined,
                  color: AppTheme.textWhite,
                  size: 22,
                )
                : Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
      ),
    );
  }
}
