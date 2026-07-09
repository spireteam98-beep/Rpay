import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cryptocurrency.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';
import 'package:fl_chart/fl_chart.dart';

class TradingScreen extends StatefulWidget {
  const TradingScreen({Key? key}) : super(key: key);

  @override
  State<TradingScreen> createState() => _TradingScreenState();
}

class _TradingScreenState extends State<TradingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _timeIntervals = ['1H', '4H', '1D', '1W', '1M', '1Y'];
  String _selectedTimeInterval = '1D';
  bool _isBuying = true;
  bool _placingOrder = false;
  final TextEditingController _usdAmountController = TextEditingController();

  // Simulate selected crypto - in real app this would be passed in or managed with state management
  final Cryptocurrency _selectedCrypto = Cryptocurrency.mockData[0];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Rebuild when the tab changes so the page shows the right form
    // inside the single scroll view (prevents nested-scroll conflicts).
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usdAmountController.dispose();
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
        title: Row(
          children: [
            _buildCryptoIconSmall(),
            const SizedBox(width: 10),
            Text(
              '${_selectedCrypto.name}/${_selectedCrypto.symbol.toUpperCase()}',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          _appBarAction(Icons.star_border_rounded, () {}),
          const SizedBox(width: 8),
          _appBarAction(Icons.more_horiz_rounded, () {}),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            _buildPriceHeader(),
            _buildTimeIntervals(),
            _buildPriceChart(),
            _buildTabBar(),
            // One scroll surface for the whole page — the selected tab's
            // content lives inline, so nothing overlaps while scrolling.
            if (_tabController.index == 0)
              _buildSpotTrading()
            else if (_tabController.index == 1)
              _buildFuturesTrading()
            else
              _buildMarginTrading(),
          ],
        ),
      ),
    );
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: BybitPalette.surface2,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildCryptoIconSmall() {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: BybitPalette.accent,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _selectedCrypto.symbol.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedCrypto.formattedPrice,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _selectedCrypto.isPriceUp
                              ? BybitPalette.green.withOpacity(0.15)
                              : BybitPalette.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedCrypto.formattedPriceChange,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color:
                            _selectedCrypto.isPriceUp
                                ? BybitPalette.green
                                : BybitPalette.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '24h Change',
                    style: TextStyle(fontSize: 12, color: BybitPalette.muted),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildStatItem('24h High', '\$${_selectedCrypto.high24h}'),
              const SizedBox(width: 20),
              _buildStatItem('24h Low', '\$${_selectedCrypto.low24h}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: BybitPalette.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeIntervals() {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _timeIntervals.length,
        itemBuilder: (context, index) {
          final interval = _timeIntervals[index];
          final isSelected = interval == _selectedTimeInterval;
          return TouchScale(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedTimeInterval = interval;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? BybitPalette.selected : BybitPalette.surface2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                interval,
                style: TextStyle(
                  color: isSelected ? Colors.white : BybitPalette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceChart() {
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            verticalInterval: 1,
            getDrawingHorizontalLine: _getDrawingLine,
            getDrawingVerticalLine: _getDrawingLine,
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(
                    color: BybitPalette.muted,
                    fontSize: 10,
                  );
                  Widget text;
                  switch (value.toInt()) {
                    case 0:
                      text = const Text('Jan', style: style);
                      break;
                    case 2:
                      text = const Text('Mar', style: style);
                      break;
                    case 4:
                      text = const Text('May', style: style);
                      break;
                    case 6:
                      text = const Text('Jul', style: style);
                      break;
                    case 8:
                      text = const Text('Sep', style: style);
                      break;
                    case 10:
                      text = const Text('Nov', style: style);
                      break;
                    default:
                      text = const Text('');
                      break;
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: text,
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return Container();
                  }
                  return Text(
                    '\$${value.toInt()}K',
                    style: const TextStyle(
                      color: BybitPalette.muted,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.left,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 11,
          minY: 0,
          maxY: 6,
          lineBarsData: [
            LineChartBarData(
              spots: const [
                FlSpot(0, 3),
                FlSpot(1, 2.5),
                FlSpot(2, 3.1),
                FlSpot(3, 3.2),
                FlSpot(4, 2.8),
                FlSpot(5, 3.5),
                FlSpot(6, 3.9),
                FlSpot(7, 3.2),
                FlSpot(8, 4),
                FlSpot(9, 3.8),
                FlSpot(10, 4.2),
                FlSpot(11, 4.5),
              ],
              isCurved: true,
              color: BybitPalette.accent,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    BybitPalette.accent.withOpacity(0.28),
                    BybitPalette.accent.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: BybitPalette.surface2.withOpacity(0.9),
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  return LineTooltipItem(
                    '\$${(barSpot.y * 1000).toInt()}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  static FlLine _getDrawingLine(double value) {
    return const FlLine(color: BybitPalette.surface2, strokeWidth: 1);
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        tabs: const [
          Tab(text: 'Spot'),
          Tab(text: 'Futures'),
          Tab(text: 'Margin'),
        ],
      ),
    );
  }

  Widget _buildSpotTrading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBuySellToggle(),
          const SizedBox(height: 20),
          _buildAmountInput('Amount to ${_isBuying ? 'buy' : 'sell'} (USD)', 'USD',
              controller: _usdAmountController),
          const SizedBox(height: 16),
          _buildTotalSection(),
          const SizedBox(height: 24),
          _buildTradeButton(),
        ],
      ),
    );
  }

  Widget _buildBuySellToggle() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: BybitPalette.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: TouchScale(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isBuying = true;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isBuying ? BybitPalette.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Buy',
                    style: TextStyle(
                      color: _isBuying ? Colors.black : BybitPalette.muted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TouchScale(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isBuying = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isBuying ? BybitPalette.red : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Sell',
                    style: TextStyle(
                      color: !_isBuying ? Colors.white : BybitPalette.muted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput(String label, String currency,
      {TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: BybitPalette.muted, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: const TextStyle(color: BybitPalette.muted),
            filled: true,
            fillColor: BybitPalette.input,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: BybitPalette.accent,
                width: 1.4,
              ),
            ),
            suffixText: currency,
            suffixStyle: const TextStyle(
              color: BybitPalette.muted,
              fontWeight: FontWeight.bold,
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildTotalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total',
          style: TextStyle(color: BybitPalette.muted, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BybitPalette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF242832)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0.00',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'USDT',
                style: TextStyle(color: BybitPalette.muted, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTradeButton() {
    final symbol = _selectedCrypto.symbol.toUpperCase();
    return TouchScale(
      onTap: _placingOrder ? () {} : _placeOrder,
      child: Container(
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isBuying ? BybitPalette.green : BybitPalette.red,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          _placingOrder
              ? 'Placing order…'
              : (_isBuying ? 'Buy $symbol' : 'Sell $symbol'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _isBuying ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    final usd = double.tryParse(_usdAmountController.text.trim()) ?? 0;
    if (usd <= 0) {
      _showSnack('Enter a USD amount first.');
      return;
    }
    if (!ApiService.hasSession) {
      _showSnack(
        'Live trading needs the backend: run run_backend.bat, then sign up or log in.',
      );
      return;
    }

    setState(() => _placingOrder = true);
    try {
      final fill = await ApiService.trade(
        side: _isBuying ? 'buy' : 'sell',
        asset: _selectedCrypto.symbol.toUpperCase(),
        usdAmount: usd,
      );
      final qty = (fill['qty'] as num).toDouble();
      final price = (fill['price'] as num).toDouble();
      final mode = fill['executionMode'] == 'external-market'
          ? 'Binance testnet'
          : 'internal fill @ live price';
      _usdAmountController.clear();
      _showSnack(
        '${_isBuying ? 'Bought' : 'Sold'} ${qty.toStringAsFixed(6)} '
        '${fill['asset']} @ \$${price.toStringAsFixed(2)} — $mode',
      );
    } on ApiException catch (err) {
      _showSnack(err.message);
    } catch (_) {
      _showSnack('Order failed — is the backend running?');
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Placeholder widgets for other trading types
  Widget _buildFuturesTrading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60, horizontal: 16),
      child: Center(
        child: Text(
          'Futures Trading Interface',
          style: TextStyle(color: BybitPalette.muted),
        ),
      ),
    );
  }

  Widget _buildMarginTrading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60, horizontal: 16),
      child: Center(
        child: Text(
          'Margin Trading Interface',
          style: TextStyle(color: BybitPalette.muted),
        ),
      ),
    );
  }
}
