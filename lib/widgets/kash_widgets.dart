import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_theme.dart';
import 'touch_scale.dart';

/// Shared building blocks for the Wayaki neon-glass design system.

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  final bool isLoading;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading;
    return IgnorePointer(
      ignoring: disabled,
      child: TouchScale(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: disabled ? 0.55 : 1,
          child: Container(
            width: double.infinity,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: outlined ? Colors.transparent : AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(100),
              border:
                  outlined
                      ? Border.all(color: const Color(0x33FFFFFF), width: 1.2)
                      : null,
            ),
            child:
                isLoading
                    ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(
                          outlined ? AppTheme.textWhite : AppTheme.onLime,
                        ),
                      ),
                    )
                    : Text(
                      label,
                      style: TextStyle(
                        color: outlined ? AppTheme.textWhite : AppTheme.onLime,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}

class KashTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  const KashTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.controller,
    this.errorText,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textGrey,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: Icon(icon, color: AppTheme.textGrey, size: 20),
          ),
        ),
      ],
    );
  }
}

class GlassTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const GlassTile({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: double.infinity,
      padding: padding,
      decoration: AppTheme.glassCard,
      child: child,
    );
    return onTap == null ? tile : TouchScale(onTap: onTap, child: tile);
  }
}

class CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? bg;
  final double size;
  const CircleIcon(this.icon, {super.key, this.color, this.bg, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? AppTheme.cardLightBackground,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.glassStroke),
      ),
      child: Icon(
        icon,
        color: color ?? AppTheme.primaryColor,
        size: size * 0.45,
      ),
    );
  }
}

class KashBackBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const KashBackBar(this.title, {super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: TouchScale(
        onTap: () => Navigator.of(context).maybePop(),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppTheme.textWhite,
          size: 20,
        ),
      ),
      title: Text(title),
    );
  }
}

/// Fade+slide page route used across the app.
Route<T> kashRoute<T>(Widget screen) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder:
        (_, animation, __) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: screen,
          ),
        ),
  );
}
