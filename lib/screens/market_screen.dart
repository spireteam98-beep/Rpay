import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cryptocurrency.dart';
import '../services/api_service.dart';
import '../widgets/crypto_list_item.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';
import 'buy_screen.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({Key? key}) : super(key: key);

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  static const _tabs = ['Favourites', 'Top', 'Hot', 'Gainers', 'New'];

  List<Cryptocurrency> _coins = Cryptocurrency.assets;
  String _selectedTab = 'Favourites';
  int _modeIndex = 0; // 0 = Exchange, 1 = Wallet

  List<Cryptocurrency> get _filteredCoins {
    final coins = [..._coins];
    switch (_selectedTab) {
      case 'Top':
        return coins..sort((a, b) => b.volume24h.compareTo(a.volume24h));
      case 'Hot':
        return coins..sort(
          (a, b) => b.priceChangePercentage24h.abs().compareTo(
            a.priceChangePercentage24h.abs(),
          ),
        );
      case 'Gainers':
        return coins.where((c) => c.isPriceUp).toList()..sort(
          (a, b) =>
              b.priceChangePercentage24h.compareTo(a.priceChangePercentage24h),
        );
      case 'New':
      case 'Favourites':
      default:
        return coins;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMarket();
  }

  Future<void> _loadMarket() async {
    final response = await ApiService.market();
    if (!mounted || response == null) return;
    setState(() {
      _coins = Cryptocurrency.withLiveData(
        response['assets'] as Map<String, dynamic>?,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topIconsRow(context),
            _waveHeader(),
            Expanded(child: _buildCryptoList()),
          ],
        ),
      ),
    );
  }

  Widget _topIconsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleIconButton(Icons.menu_rounded, onTap: () {}),
          Row(
            children: [
              _circleIconButton(Icons.card_giftcard_rounded, onTap: () {}),
              const SizedBox(width: 10),
              _circleIconButton(
                Icons.chat_bubble_outline_rounded,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton(IconData icon, {required VoidCallback onTap}) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: BybitPalette.surface2,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _waveHeader() {
    return SizedBox(
      height: 214,
      width: double.infinity,
      child: ClipPath(
        clipper: const BybitWaveClipper(),
        child: Container(
          color: BybitPalette.accent,
          padding: const EdgeInsets.fromLTRB(20, 92, 20, 20),
          child: Column(
            children: [
              Center(child: _exchangeWalletSegment()),
              const SizedBox(height: 14),
              _categoryTabs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exchangeWalletSegment() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_segmentOption('Exchang', 0), _segmentOption('Wallet', 1)],
      ),
    );
  }

  Widget _segmentOption(String label, int index) {
    final selected = _modeIndex == index;
    return TouchScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _modeIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _categoryTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _tabs.map((label) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _categoryTab(label),
              );
            }).toList(),
      ),
    );
  }

  Widget _categoryTab(String label) {
    final selected = _selectedTab == label;
    return TouchScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTab = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCryptoList() {
    final coins = _filteredCoins;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildTableHeader(),
        const SizedBox(height: 4),
        if (coins.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No $_selectedTab coins right now.',
                style: const TextStyle(color: BybitPalette.muted, fontSize: 13),
              ),
            ),
          ),
        ...coins.map((crypto) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: CryptoListItem(
              crypto: crypto,
              onTap:
                  () => Navigator.of(
                    context,
                  ).push(kashRoute(BuyScreen(selectedCrypto: crypto))),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 4, child: _headerLabel('Name / Turnover')),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: _headerLabel('Last Price'),
            ),
          ),
          SizedBox(
            width: 78,
            child: Align(
              alignment: Alignment.centerRight,
              child: _headerLabel('Change'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerLabel(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: BybitPalette.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 3),
        const Icon(
          Icons.unfold_more_rounded,
          size: 14,
          color: BybitPalette.muted,
        ),
      ],
    );
  }
}
