import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_theme.dart';
import 'touch_scale.dart';

class BybitPalette {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF14171C);
  static const surface2 = Color(0xFF1E2227);
  static const input = Color(0xFF272A2F);
  static const segment = Color(0xFF23262C);
  static const selected = Color(0xFF4B525F);
  static const muted = Color(0xFF80848D);
  static const muted2 = Color(0xFF777B84);
  /// RoyallPay's signature neon-lime brand accent (matches [AppTheme.primaryColor]).
  static const accent = Color(0xFFDDF716);
  static const green = Color(0xFF20C997);
  static const red = Color(0xFFFF4D57);
}

class BybitScreen extends StatelessWidget {
  final Widget child;
  final bool includeStatusBar;

  const BybitScreen({
    super.key,
    required this.child,
    this.includeStatusBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (includeStatusBar) const BybitStatusBar(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class BybitStatusBar extends StatelessWidget {
  const BybitStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text(
            '11:35',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          Row(
            children: [
              Icon(Icons.wifi_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Icon(Icons.signal_cellular_alt_rounded,
                  color: Colors.white, size: 21),
              SizedBox(width: 8),
              Icon(Icons.battery_full_rounded, color: Colors.white, size: 23),
              SizedBox(width: 3),
              Text(
                '91%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BybitTopBar extends StatelessWidget {
  const BybitTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Row(
        children: [
          const Icon(Icons.hexagon_outlined, color: Colors.white, size: 38),
          const Spacer(),
          Container(
            width: 190,
            height: 52,
            decoration: BoxDecoration(
              color: BybitPalette.segment,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(child: _segment('Exchange', false)),
                Expanded(child: _segment('WEB3', true)),
              ],
            ),
          ),
          const Spacer(),
          const Icon(Icons.qr_code_scanner_rounded,
              color: Colors.white, size: 34),
        ],
      ),
    );
  }

  Widget _segment(String label, bool selected) {
    return Container(
      height: 52,
      alignment: Alignment.center,
      decoration: selected
          ? BoxDecoration(
              color: BybitPalette.selected,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFFB7BBC3),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class BybitSearchBar extends StatelessWidget {
  const BybitSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      margin: const EdgeInsets.fromLTRB(24, 26, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: BybitPalette.input,
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, color: BybitPalette.muted, size: 27),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Search by token name or address',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: BybitPalette.muted, fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class BybitSubHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const BybitSubHeader(this.title, {super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: BybitPalette.bg,
      elevation: 0,
      centerTitle: true,
      leading: TouchScale(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          margin: const EdgeInsets.only(left: 16),
          decoration: const BoxDecoration(
            color: BybitPalette.surface2,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: BybitPalette.surface2,
            child: Icon(Icons.more_horiz_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class BybitCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const BybitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class BybitActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const BybitActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TouchScale(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: BybitPalette.surface2,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class BybitTokenData {
  final String symbol;
  final String price;
  final String change;
  final Color changeColor;
  final Color color;
  final String mark;
  final Color chainColor;

  const BybitTokenData({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changeColor,
    required this.color,
    required this.mark,
    required this.chainColor,
  });
}

const bybitTokens = [
  BybitTokenData(
    symbol: 'ETH',
    price: '\$3.09K',
    change: '+2.78%',
    changeColor: BybitPalette.green,
    color: Color(0xFF627EEA),
    mark: 'E',
    chainColor: Color(0xFF6789FF),
  ),
  BybitTokenData(
    symbol: 'USDC',
    price: '\$0.99',
    change: '-0.10%',
    changeColor: BybitPalette.red,
    color: Color(0xFF2775CA),
    mark: '\$',
    chainColor: Color(0xFF6789FF),
  ),
  BybitTokenData(
    symbol: 'USDT',
    price: '\$1.00',
    change: '+0.01%',
    changeColor: BybitPalette.green,
    color: Color(0xFF00D17D),
    mark: 'T',
    chainColor: Color(0xFF6789FF),
  ),
  BybitTokenData(
    symbol: 'SOL',
    price: '\$162.88',
    change: '-0.75%',
    changeColor: BybitPalette.red,
    color: Color(0xFF050506),
    mark: 'S',
    chainColor: Color(0xFFF5F2FF),
  ),
  BybitTokenData(
    symbol: 'bbSOL',
    price: '\$177.75',
    change: '-1.23%',
    changeColor: BybitPalette.red,
    color: Color(0xFF111111),
    mark: 'bb',
    chainColor: Color(0xFFF5F2FF),
  ),
  BybitTokenData(
    symbol: 'BNB',
    price: '\$687.19',
    change: '-0.64%',
    changeColor: BybitPalette.red,
    color: Color(0xFFF3BA2F),
    mark: 'B',
    chainColor: Color(0xFFF3BA2F),
  ),
  BybitTokenData(
    symbol: 'BTC',
    price: '\$116.86K',
    change: '-0.37%',
    changeColor: BybitPalette.red,
    color: Color(0xFFF7931A),
    mark: 'B',
    chainColor: Color(0xFFF7931A),
  ),
];

class BybitTokenIcon extends StatelessWidget {
  final BybitTokenData token;
  final double size;

  const BybitTokenIcon({
    super.key,
    required this.token,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: token.color, shape: BoxShape.circle),
            child: Center(
              child: token.symbol == 'SOL'
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        _SolStripe(Color(0xFF14F195)),
                        SizedBox(height: 3),
                        _SolStripe(Color(0xFF9945FF)),
                        SizedBox(height: 3),
                        _SolStripe(Color(0xFF14F195)),
                      ],
                    )
                  : Text(
                      token.mark,
                      style: TextStyle(
                        color: token.symbol == 'USDT'
                            ? Colors.black
                            : Colors.white,
                        fontSize: token.mark.length > 1 ? size * 0.28 : size * 0.42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                color: token.chainColor,
                shape: BoxShape.circle,
                border: Border.all(color: BybitPalette.bg, width: 1.5),
              ),
              child: Center(
                child: Text(
                  token.chainColor == const Color(0xFFF5F2FF) ? 'S' : 'E',
                  style: TextStyle(
                    color: token.chainColor == const Color(0xFFF5F2FF)
                        ? const Color(0xFF765AF6)
                        : Colors.white,
                    fontSize: size * 0.16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SolStripe extends StatelessWidget {
  final Color color;
  const _SolStripe(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 31,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}

class BybitTokenRow extends StatelessWidget {
  final BybitTokenData token;
  final String amount;
  final String value;
  final VoidCallback? onTap;

  const BybitTokenRow({
    super.key,
    required this.token,
    this.amount = '0.00',
    this.value = '0 USD',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          BybitTokenIcon(token: token),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: BybitPalette.muted2,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(text: '${token.price} '),
                      TextSpan(
                        text: token.change,
                        style: TextStyle(color: token.changeColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: BybitPalette.muted2,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return onTap == null ? row : TouchScale(onTap: onTap!, child: row);
  }
}

class BybitPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const BybitPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TouchScale(
      onTap: enabled ? onTap : () {},
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? BybitPalette.accent : const Color(0xFF333843),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.black : BybitPalette.muted,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class BybitTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const BybitTextField({
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
            color: BybitPalette.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: Icon(icon, color: BybitPalette.muted, size: 20),
            filled: true,
            fillColor: BybitPalette.input,
            hintStyle: const TextStyle(color: BybitPalette.muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: BybitPalette.accent,
                width: 1.4,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: BybitPalette.red, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

class BybitInfoLine extends StatelessWidget {
  final String label;
  final String value;

  const BybitInfoLine(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: BybitPalette.muted2, fontSize: 13),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
