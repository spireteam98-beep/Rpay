import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';
import 'agent_screen.dart';
import 'buy_screen.dart';
import 'cash_in_screen.dart';
import 'ledger_screen.dart';
import 'merchant_screen.dart';
import 'profile_screen.dart';
import 'send_money_screen.dart';
import 'swap_screen.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  static const Color _lime = Color(0xFFDDF716);
  static const Color _limeDark = Color(0xFFA9CE13);
  static const Color _panel = Color(0xFF111214);
  static const Color _panel2 = Color(0xFF1E2024);
  static const Color _muted = Color(0xFF7B8089);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(context, appState),
              const SizedBox(height: 22),
              _balanceBlock(context, appState),
              const SizedBox(height: 22),
              _actionGrid(context),
              const SizedBox(height: 24),
              _homeHero(appState),
              const SizedBox(height: 14),
              _widgetStrip(),
              const SizedBox(height: 14),
              _marketPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, KashAppState appState) {
    return Row(
      children: [
        TouchScale(
          onTap:
              () =>
                  Navigator.of(context).push(kashRoute(const ProfileScreen())),
          child: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFFFA733), _limeDark]),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.black,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1C20),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_rounded, color: Color(0xFF555A63), size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'HYPE/USDT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF555A63),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(
          Icons.qr_code_scanner_rounded,
          color: Colors.white,
          size: 25,
        ),
        const SizedBox(width: 14),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 26,
            ),
            Positioned(
              right: -7,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3767),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  '99+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _balanceBlock(BuildContext context, KashAppState appState) {
    return SizedBox(
      height: 88,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: CustomPaint(
                size: const Size(150, 76),
                painter: _BarsPainter(),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Total Assets',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.visibility_outlined,
                          color: _muted,
                          size: 15,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            appState.totalBalance.replaceAll('\$', ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.1,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 3),
                          child: Text(
                            'USD',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 3),
                          child: Icon(
                            Icons.arrow_drop_down_rounded,
                            color: _muted,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TouchScale(
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const CashInScreen())),
                child: Container(
                  width: 88,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_lime, _limeDark]),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'Deposit',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionGrid(BuildContext context) {
    final actions = [
      _DashAction(Icons.bolt_rounded, 'P2P SuperDeal', const BuyScreen()),
      _DashAction(
        Icons.account_balance_wallet_outlined,
        'Deposit',
        const CashInScreen(),
      ),
      _DashAction(
        Icons.card_giftcard_rounded,
        'Rewards Hub',
        const LedgerScreen(),
      ),
      _DashAction(Icons.storefront_rounded, 'Merchant', const MerchantScreen()),
      _DashAction(Icons.sync_rounded, 'Convert', const SwapScreen()),
      _DashAction(
        Icons.handshake_outlined,
        'P2P Trading',
        const SendMoneyScreen(),
      ),
      _DashAction(
        Icons.group_add_outlined,
        'Invite Friends',
        const ProfileScreen(),
      ),
      _DashAction(Icons.support_agent_rounded, 'Agent', const AgentScreen()),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 18,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return TouchScale(
          onTap: () => Navigator.of(context).push(kashRoute(action.screen)),
          child: Column(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: const BoxDecoration(
                  color: _panel2,
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: Colors.white, size: 21),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _homeHero(KashAppState appState) {
    return Container(
      height: 96,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.blur_on_rounded, color: _lime, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '${appState.firstName.toUpperCase()} HOME PAGE',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _widgetStrip() {
    return Container(
      height: 58,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF181A1F), Color(0xFF391A38), Color(0xFF151619)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.dashboard_customize_rounded,
              color: _lime,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Customize your homepage with widgets.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted, size: 22),
        ],
      ),
    );
  }

  Widget _marketPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: BouncingScrollPhysics(),
            child: Row(
              children: [
                _TopTab('Favorites', false),
                _TopTab('Hot', true),
                _TopTab('New', false, dot: true),
                _TopTab('Gainers', false),
                _TopTab('Losers', false),
                _TopTab('Turnover', false),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              _SubTab('Spot', true),
              _SubTab('Alpha', false, flame: true),
              _SubTab('Derivatives', false),
              _SubTab('TradFi', false),
            ],
          ),
          const SizedBox(height: 14),
          TouchScale(
            onTap:
                () => Navigator.of(context).push(kashRoute(const BuyScreen())),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7B500),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'B',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'BTC',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '/USDT',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 5),
                          _LeveragePill(),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        '1.05B USDT',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '87,426.1',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 62,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BybitPalette.green,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    '+1.64%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashAction {
  final IconData icon;
  final String label;
  final Widget screen;

  const _DashAction(this.icon, this.label, this.screen);
}

class _TopTab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dot;

  const _TopTab(this.label, this.selected, {this.dot = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : HomeDashboardScreen._muted,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          if (dot) ...[
            const SizedBox(width: 2),
            const Text(
              '*',
              style: TextStyle(
                color: Color(0xFFFF3767),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubTab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool flame;

  const _SubTab(this.label, this.selected, {this.flame = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : HomeDashboardScreen._muted,
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          if (flame) ...[
            const SizedBox(width: 3),
            const Icon(
              Icons.local_fire_department_rounded,
              color: HomeDashboardScreen._lime,
              size: 11,
            ),
          ],
        ],
      ),
    );
  }
}

class _LeveragePill extends StatelessWidget {
  const _LeveragePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF303238),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        '10x',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFF15170F)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    const bars = 18;
    for (var i = 0; i < bars; i++) {
      final x = size.width - (i * 7.4);
      final height = 10 + (i * 3.1);
      final opacity = (0.08 + i * 0.018).clamp(0.0, 0.35);
      paint.color = HomeDashboardScreen._lime.withOpacity(opacity);
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
