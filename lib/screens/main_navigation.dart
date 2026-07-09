import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import 'home_screen.dart';
import 'market_screen.dart';
import 'trading_screen.dart';
import 'wallet_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const WalletScreen(),
    const MarketScreen(),
    const TradingScreen(),
    const HomeScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Replace the local placeholder balances with the real Postgres-backed
    // numbers as soon as the app shell is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<KashAppState>().syncFromBackend();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: BybitPalette.surface,
          border: Border(top: BorderSide(color: Color(0xFF292C32))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            HapticFeedback.selectionClick();
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: BybitPalette.accent,
          unselectedItemColor: BybitPalette.muted,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Wallet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.candlestick_chart_outlined),
              activeIcon: Icon(Icons.candlestick_chart_rounded),
              label: 'Markets',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.swap_vert_circle_outlined),
              activeIcon: Icon(Icons.swap_vert_circle_rounded),
              label: 'Trade',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Hub',
            ),
          ],
        ),
      ),
    );
  }
}
