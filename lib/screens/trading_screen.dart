import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cryptocurrency.dart';
import '../services/api_service.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';
import 'package:fl_chart/fl_chart.dart';
import 'trending_data_screen.dart';

class TradingScreen extends StatefulWidget {
  const TradingScreen({Key? key}) : super(key: key);

  @override
  State<TradingScreen> createState() => _TradingScreenState();
}

class _TradingScreenState extends State<TradingScreen> {
  static const _topTabs = ['Market', 'Swap', 'Spot', 'Derivativ'];
  static const _swapSubTabs = ['Swap', 'Bridge', 'Limit order'];

  int _topTabIndex = 0;
  int _swapSubTabIndex = 0;

  // ── Market/Spot trading state ────────────────────────────────────
  final List<String> _timeIntervals = ['1H', '4H', '1D', '1W', '1M', '1Y'];
  String _selectedTimeInterval = '1D';
  bool _isBuying = true;
  bool _placingOrder = false;
  final TextEditingController _usdAmountController = TextEditingController();
  final Cryptocurrency _selectedCrypto = Cryptocurrency.mockData[0];

  // ── Swap state ────────────────────────────────────────────────────
  List<Cryptocurrency> _swapCoins = Cryptocurrency.assets;
  Map<String, double> _holdings = {};
  Cryptocurrency _fromCrypto = Cryptocurrency.assets[0];
  Cryptocurrency _toCrypto = Cryptocurrency.assets[1];
  final TextEditingController _fromAmountController =
      TextEditingController(text: '1');
  final TextEditingController _toAmountController = TextEditingController();
  bool _swapping = false;

  @override
  void initState() {
    super.initState();
    _loadSwapMarket();
  }

  Future<void> _loadSwapMarket() async {
    final results = await Future.wait([
      ApiService.market(),
      ApiService.tradeBalances(),
    ]);
    if (!mounted) return;
    final market = results[0];
    final balances = results[1];

    final coins = Cryptocurrency.withLiveData(
      market?['assets'] as Map<String, dynamic>?,
    );
    final holdings = <String, double>{};
    for (final holding in (balances?['holdings'] as List? ?? [])) {
      final map = holding as Map<String, dynamic>;
      holdings[map['asset'] as String] = (map['amount'] as num?)?.toDouble() ?? 0;
    }

    setState(() {
      _swapCoins = coins;
      _holdings = holdings;
      _fromCrypto = coins.firstWhere((c) => c.symbol == _fromCrypto.symbol, orElse: () => _fromCrypto);
      _toCrypto = coins.firstWhere((c) => c.symbol == _toCrypto.symbol, orElse: () => _toCrypto);
      _calculateToAmount();
    });
  }

  void _calculateToAmount() {
    if (_fromAmountController.text.isEmpty) {
      _toAmountController.text = '';
      return;
    }
    try {
      final fromAmount = double.parse(_fromAmountController.text);
      if (_toCrypto.currentPrice <= 0) {
        _toAmountController.text = '';
        return;
      }
      final fromValueInUsd = fromAmount * _fromCrypto.currentPrice;
      final toAmount = fromValueInUsd / _toCrypto.currentPrice;
      _toAmountController.text = toAmount.toStringAsFixed(8);
    } catch (_) {
      _toAmountController.text = '';
    }
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCrypto;
      _fromCrypto = _toCrypto;
      _toCrypto = temp;
      final tempAmount = _fromAmountController.text;
      _fromAmountController.text = _toAmountController.text;
      _toAmountController.text = tempAmount;
    });
  }

  @override
  void dispose() {
    _usdAmountController.dispose();
    _fromAmountController.dispose();
    _toAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _titleRow(),
            _waveTabsHeader(),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _titleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Trade',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          Row(
            children: [
              _circleIconButton(
                Icons.tune_rounded,
                onTap: () => Navigator.of(context).push(
                  kashRoute(TrendingDataScreen(crypto: _selectedCrypto)),
                ),
              ),
              const SizedBox(width: 10),
              _circleIconButton(Icons.more_horiz_rounded, onTap: () {}),
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
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: BybitPalette.surface2, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }

  Widget _waveTabsHeader() {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: ClipPath(
        clipper: const BybitWaveClipper(),
        child: Container(
          color: BybitPalette.accent,
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
          child: _topTabsRow(),
        ),
      ),
    );
  }

  Widget _topTabsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_topTabs.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _topTab(_topTabs[i], i),
          );
        }),
      ),
    );
  }

  Widget _topTab(String label, int index) {
    final selected = _topTabIndex == index;
    return TouchScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _topTabIndex = index);
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

  Widget _content() {
    switch (_topTabIndex) {
      case 1:
        return _swapTab();
      case 3:
        return _derivativeStub();
      default:
        return _marketTab();
    }
  }

  // ── Market / Spot tab ────────────────────────────────────────────

  Widget _marketTab() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          _buildPriceHeader(),
          _buildTimeIntervals(),
          _buildPriceChart(),
          _buildSpotTrading(),
        ],
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
              Row(
                children: [
                  _buildCryptoIconSmall(),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedCrypto.name}/${_selectedCrypto.symbol.toUpperCase()}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (_selectedCrypto.isPriceUp ? BybitPalette.green : BybitPalette.red)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedCrypto.formattedPriceChange,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _selectedCrypto.isPriceUp ? BybitPalette.green : BybitPalette.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('24h Change', style: TextStyle(fontSize: 12, color: BybitPalette.muted)),
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

  Widget _buildCryptoIconSmall() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(color: BybitPalette.accent, shape: BoxShape.circle),
      child: Center(
        child: Text(
          _selectedCrypto.symbol.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: BybitPalette.muted)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }

  Widget _buildTimeIntervals() {
    return SizedBox(
      height: 36,
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
              setState(() => _selectedTimeInterval = interval);
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
      height: 220,
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
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(color: BybitPalette.muted, fontSize: 10);
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
                  return SideTitleWidget(axisSide: meta.axisSide, space: 8, child: text);
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) return Container();
                  return Text(
                    '\$${value.toInt()}K',
                    style: const TextStyle(color: BybitPalette.muted, fontSize: 10),
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
                FlSpot(0, 3), FlSpot(1, 2.5), FlSpot(2, 3.1), FlSpot(3, 3.2),
                FlSpot(4, 2.8), FlSpot(5, 3.5), FlSpot(6, 3.9), FlSpot(7, 3.2),
                FlSpot(8, 4), FlSpot(9, 3.8), FlSpot(10, 4.2), FlSpot(11, 4.5),
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
                  colors: [BybitPalette.accent.withOpacity(0.28), BybitPalette.accent.withOpacity(0.0)],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: BybitPalette.surface2.withOpacity(0.9),
              getTooltipItems: (spots) => spots.map((spot) {
                return LineTooltipItem(
                  '\$${(spot.y * 1000).toInt()}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  static FlLine _getDrawingLine(double value) => const FlLine(color: BybitPalette.surface2, strokeWidth: 1);

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
      decoration: BoxDecoration(color: BybitPalette.surface2, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: TouchScale(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isBuying = true);
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
                setState(() => _isBuying = false);
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

  Widget _buildAmountInput(String label, String currency, {TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: BybitPalette.muted, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: const TextStyle(color: BybitPalette.muted),
            filled: true,
            fillColor: BybitPalette.input,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: BybitPalette.accent, width: 1.4),
            ),
            suffixText: currency,
            suffixStyle: const TextStyle(color: BybitPalette.muted, fontWeight: FontWeight.bold),
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
        const Text('Total', style: TextStyle(color: BybitPalette.muted, fontSize: 14)),
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
              Text('0.00', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('USDT', style: TextStyle(color: BybitPalette.muted, fontSize: 16)),
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
          _placingOrder ? 'Placing order…' : (_isBuying ? 'Buy $symbol' : 'Sell $symbol'),
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
      _showSnack('Live trading needs the backend: run run_backend.bat, then sign up or log in.');
      return;
    }

    setState(() => _placingOrder = true);
    try {
      final fill = await ApiService.trade(
        side: _isBuying ? 'buy' : 'sell',
        asset: _selectedCrypto.symbol,
        usdAmount: usd,
      );
      final qty = (fill['qty'] as num).toDouble();
      final price = (fill['price'] as num).toDouble();
      final mode = fill['executionMode'] == 'external-market' ? 'Binance testnet' : 'internal fill @ live price';
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

  // ── Swap tab ─────────────────────────────────────────────────────

  Widget _swapTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _swapSubTabsRow(),
          const SizedBox(height: 8),
          if (_swapSubTabIndex == 0)
            _swapBody()
          else
            _comingSoonStub(_swapSubTabs[_swapSubTabIndex]),
        ],
      ),
    );
  }

  Widget _swapSubTabsRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: BybitPalette.surface2, borderRadius: BorderRadius.circular(100)),
      child: Row(
        children: List.generate(_swapSubTabs.length, (i) {
          return Expanded(child: _swapSubTabItem(_swapSubTabs[i], i));
        }),
      ),
    );
  }

  Widget _swapSubTabItem(String label, int index) {
    final selected = _swapSubTabIndex == index;
    return TouchScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _swapSubTabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? BybitPalette.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? BybitPalette.accent : BybitPalette.muted,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _swapBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        children: [
          _swapCard(
            label: 'From',
            crypto: _fromCrypto,
            controller: _fromAmountController,
            readOnly: false,
            onPickToken: () => _showTokenPicker(true),
            onChanged: _calculateToAmount,
          ),
          const SizedBox(height: 10),
          Center(
            child: TouchScale(
              onTap: () {
                HapticFeedback.selectionClick();
                _swapCurrencies();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: BybitPalette.surface2, shape: BoxShape.circle),
                child: const Icon(Icons.swap_vert_rounded, color: BybitPalette.accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _swapCard(
            label: 'To',
            crypto: _toCrypto,
            controller: _toAmountController,
            readOnly: true,
            onPickToken: () => _showTokenPicker(false),
            onChanged: null,
          ),
          const SizedBox(height: 20),
          _swapActionButton(),
        ],
      ),
    );
  }

  Widget _swapCard({
    required String label,
    required Cryptocurrency crypto,
    required TextEditingController controller,
    required bool readOnly,
    required VoidCallback onPickToken,
    required VoidCallback? onChanged,
  }) {
    final available = _holdings[crypto.symbol] ?? 0;
    final usdValue = (double.tryParse(controller.text) ?? 0) * crypto.currentPrice;
    return BybitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: BybitPalette.muted, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              const Text('· Ethereum', style: TextStyle(color: BybitPalette.muted, fontSize: 12)),
              const Spacer(),
              const Icon(Icons.account_balance_wallet_outlined, size: 13, color: BybitPalette.muted),
              const SizedBox(width: 4),
              Text(available.toStringAsFixed(available == available.toInt() ? 0 : 4),
                  style: const TextStyle(color: BybitPalette.muted, fontSize: 12)),
              if (label == 'From') ...[
                const SizedBox(width: 8),
                const Text('Add funds',
                    style: TextStyle(color: BybitPalette.accent, fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _tokenPill(crypto, onTap: onPickToken),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: controller,
                      readOnly: readOnly,
                      textAlign: TextAlign.end,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: BybitPalette.muted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: onChanged == null ? null : (_) => onChanged(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${usdValue.toStringAsFixed(usdValue < 1 ? 5 : 2)}',
                      style: const TextStyle(color: BybitPalette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tokenPill(Cryptocurrency crypto, {required VoidCallback onTap}) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: BybitPalette.surface2, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: BybitPalette.accent, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  crypto.symbol.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(crypto.symbol.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _swapActionButton() {
    final fromQty = double.tryParse(_fromAmountController.text) ?? 0;
    final available = _holdings[_fromCrypto.symbol] ?? 0;
    final insufficient = fromQty > 0 && fromQty > available;
    return BybitPrimaryButton(
      label: _swapping
          ? 'Swapping…'
          : insufficient
              ? 'Insufficient balance of ${_fromCrypto.symbol}'
              : 'Swap',
      enabled: !_swapping,
      onTap: () {
        if (insufficient) {
          _showSnack('Not enough ${_fromCrypto.symbol} to swap that amount.');
          return;
        }
        if (fromQty <= 0) {
          _showSnack('Enter an amount to swap.');
          return;
        }
        _showSwapConfirmation();
      },
    );
  }

  void _showTokenPicker(bool isFrom) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BybitPalette.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(isFrom ? 'Select source token' : 'Select destination token',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _swapCoins.where((c) {
                    return isFrom ? c.symbol != _toCrypto.symbol : c.symbol != _fromCrypto.symbol;
                  }).map((crypto) {
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(color: BybitPalette.surface2, shape: BoxShape.circle),
                        child: Center(
                          child: Text(crypto.symbol.substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ),
                      title: Text(crypto.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                      subtitle: Text(crypto.symbol.toUpperCase(), style: const TextStyle(color: BybitPalette.muted)),
                      trailing: Text(crypto.formattedPrice, style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        setState(() {
                          if (isFrom) {
                            _fromCrypto = crypto;
                          } else {
                            _toCrypto = crypto;
                          }
                          _calculateToAmount();
                        });
                        Navigator.pop(sheetContext);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showSwapConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: BybitPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Confirm Swap',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 20),
              _confirmRow('You Pay', '${_fromAmountController.text} ${_fromCrypto.symbol.toUpperCase()}'),
              const SizedBox(height: 12),
              _confirmRow('You Receive (est.)', '${_toAmountController.text} ${_toCrypto.symbol.toUpperCase()}'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: BybitPalette.surface2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _executeSwap();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BybitPalette.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Confirm',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: BybitPalette.muted, fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Future<void> _executeSwap() async {
    final fromAmount = double.tryParse(_fromAmountController.text) ?? 0;
    if (fromAmount <= 0) return;
    setState(() => _swapping = true);
    try {
      final fromValueUsd = fromAmount * _fromCrypto.currentPrice;
      final sellFill = await ApiService.trade(
        side: 'sell',
        asset: _fromCrypto.symbol,
        usdAmount: fromValueUsd,
        quoteCurrency: 'USD',
      );
      final proceedsUsd = (sellFill['usd'] as num?)?.toDouble() ?? fromValueUsd;
      final buyFill = await ApiService.trade(
        side: 'buy',
        asset: _toCrypto.symbol,
        usdAmount: proceedsUsd,
        quoteCurrency: 'USD',
      );
      if (!mounted) return;
      final qtyReceived = (buyFill['qty'] as num?)?.toDouble() ?? 0;
      setState(() => _swapping = false);
      await _loadSwapMarket();
      _showSnack('Swapped for ${qtyReceived.toStringAsFixed(6)} ${_toCrypto.symbol.toUpperCase()}');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _swapping = false);
      _showSnack(err.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _swapping = false);
      _showSnack('Unexpected error while swapping.');
    }
  }

  // ── Derivatives stub ─────────────────────────────────────────────

  Widget _derivativeStub() => _comingSoonStub('Derivatives');

  Widget _comingSoonStub(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
      child: BybitCard(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: BybitPalette.surface2, shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_top_rounded, color: BybitPalette.accent, size: 24),
            ),
            const SizedBox(height: 14),
            Text('$label is coming soon',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'This is part of the RoyallPay Phase 2 roadmap.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BybitPalette.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
