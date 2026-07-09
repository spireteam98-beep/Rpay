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

class _MarketScreenState extends State<MarketScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Cryptocurrency> _coins = Cryptocurrency.assets;
  String _selectedFilter = 'All';

  List<Cryptocurrency> get _filteredCoins {
    final coins = [..._coins];
    switch (_selectedFilter) {
      case 'Gainers':
        return coins.where((c) => c.isPriceUp).toList()
          ..sort((a, b) => b.priceChangePercentage24h
              .compareTo(a.priceChangePercentage24h));
      case 'Losers':
        return coins.where((c) => !c.isPriceUp).toList()
          ..sort((a, b) => a.priceChangePercentage24h
              .compareTo(b.priceChangePercentage24h));
      case 'Volume':
        return coins..sort((a, b) => b.volume24h.compareTo(a.volume24h));
      case 'Market Cap':
        return coins..sort((a, b) => b.marketCap.compareTo(a.marketCap));
      default:
        return coins;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: AppBar(
        backgroundColor: BybitPalette.bg,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Markets',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: BybitPalette.surface2,
              child: Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: BybitPalette.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: BybitPalette.selected,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: BybitPalette.muted,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Spot'),
                Tab(text: 'Futures'),
                Tab(text: 'New'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilters(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCryptoList(),
                _buildCryptoList(), // Placeholder for Spot tab
                _buildCryptoList(), // Placeholder for Futures tab
                _buildCryptoList(), // Placeholder for New tab
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by token name or address',
          hintStyle: const TextStyle(color: BybitPalette.muted),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: BybitPalette.muted,
          ),
          filled: true,
          fillColor: BybitPalette.input,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(
              color: BybitPalette.accent,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    const filters = ['All', 'Gainers', 'Losers', 'Volume', 'Market Cap'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: filters.map((label) {
          return _buildFilterChip(label, label == _selectedFilter);
        }).toList(),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TouchScale(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilter = label);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: isSelected ? BybitPalette.selected : BybitPalette.surface2,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : BybitPalette.muted,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCryptoList() {
    final coins = _filteredCoins;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildMarketSummary(),
        const SizedBox(height: 16),
        _buildTableHeader(),
        const SizedBox(height: 8),
        if (coins.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No $_selectedFilter coins right now.',
                style: const TextStyle(color: BybitPalette.muted, fontSize: 13),
              ),
            ),
          ),
        ...coins.map((crypto) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CryptoListItem(
              crypto: crypto,
              onTap: () => Navigator.of(context).push(
                kashRoute(BuyScreen(selectedCrypto: crypto)),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 40), // Space for icon
          const SizedBox(width: 12),
          const Expanded(
            flex: 3,
            child: Text(
              'Name',
              style: TextStyle(color: BybitPalette.muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            flex: 3,
            child: Text(
              '24h',
              style: TextStyle(color: BybitPalette.muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Price',
                style: TextStyle(color: BybitPalette.muted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketSummary() {
    final gainers = _coins.where((coin) => coin.isPriceUp).length;
    return BybitCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _summaryMetric('Listed', '${_coins.length}', 'tokens'),
          _summaryDivider(),
          _summaryMetric('Gainers', '$gainers', '24h'),
          _summaryDivider(),
          _summaryMetric('Mode', 'Web3', 'spot'),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value, String caption) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: BybitPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(color: BybitPalette.muted2, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: BybitPalette.surface2,
    );
  }
}
