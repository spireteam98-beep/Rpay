import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/cryptocurrency.dart';
import '../services/api_service.dart';

/// Real crypto-to-crypto swap: sells the "From" asset for USD, then buys
/// the "To" asset with the proceeds — two chained calls to the same
/// `/trade` endpoints `trading_screen.dart` and `buy_screen.dart` use
/// (Binance testnet when configured, otherwise an internal fill at the
/// live price). Fiat-to-fiat (KES↔USD) conversion isn't part of this —
/// there's no FX/rate-engine endpoint for that yet.
class SwapScreen extends StatefulWidget {
  const SwapScreen({Key? key}) : super(key: key);

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  List<Cryptocurrency> _coins = Cryptocurrency.assets;
  Map<String, double> _holdings = {};
  late Cryptocurrency _fromCrypto;
  late Cryptocurrency _toCrypto;
  final TextEditingController _fromAmountController = TextEditingController();
  final TextEditingController _toAmountController = TextEditingController();
  bool _swapping = false;

  @override
  void initState() {
    super.initState();
    _fromCrypto = Cryptocurrency.assets[0]; // BTC
    _toCrypto = Cryptocurrency.assets[1]; // ETH
    _fromAmountController.text = '1';
    _loadMarket();
  }

  @override
  void dispose() {
    _fromAmountController.dispose();
    _toAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadMarket() async {
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
      _coins = coins;
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
      final double fromAmount = double.parse(_fromAmountController.text);
      if (_toCrypto.currentPrice <= 0) {
        _toAmountController.text = '';
        return;
      }
      final double fromValueInUsd = fromAmount * _fromCrypto.currentPrice;
      final double toAmount = fromValueInUsd / _toCrypto.currentPrice;
      _toAmountController.text = toAmount.toStringAsFixed(8);
    } catch (e) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Swap Crypto',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFromCryptoField(),
            const SizedBox(height: 16),
            _buildSwapButton(),
            const SizedBox(height: 16),
            _buildToCryptoField(),
            const SizedBox(height: 24),
            _buildExchangeRate(),
            const SizedBox(height: 24),
            _buildSwapNowButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFromCryptoField() {
    final available = _holdings[_fromCrypto.symbol] ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDarkBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'From',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fromAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: AppTheme.textGrey),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    _calculateToAmount();
                  },
                ),
              ),
              InkWell(
                onTap: () {
                  _showCryptoSelectionBottomSheet(true);
                },
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.cardLightBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          _fromCrypto.symbol.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _fromCrypto.symbol.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.textGrey,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Available: ${available.toStringAsFixed(6)} ${_fromCrypto.symbol.toUpperCase()}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapButton() {
    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: IconButton(
          icon: const Icon(Icons.swap_vert, color: Colors.white),
          onPressed: _swapCurrencies,
        ),
      ),
    );
  }

  Widget _buildToCryptoField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDarkBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'To',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _toAmountController,
                  readOnly: true,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: AppTheme.textGrey),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  _showCryptoSelectionBottomSheet(false);
                },
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.cardLightBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          _toCrypto.symbol.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _toCrypto.symbol.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.textGrey,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You will receive: ${_toAmountController.text} ${_toCrypto.symbol.toUpperCase()}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeRate() {
    final rate = _toCrypto.currentPrice > 0
        ? _fromCrypto.currentPrice / _toCrypto.currentPrice
        : 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDarkBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Exchange Rate',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGrey,
            ),
          ),
          Text(
            '1 ${_fromCrypto.symbol.toUpperCase()} = ${rate.toStringAsFixed(6)} ${_toCrypto.symbol.toUpperCase()}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textWhite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapNowButton() {
    return ElevatedButton(
      onPressed: _swapping ? null : _showSwapConfirmationDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Center(
        child: Text(
          _swapping ? 'Swapping...' : 'Swap Now',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showCryptoSelectionBottomSheet(bool isFromCrypto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDarkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                isFromCrypto ? 'Select Source Coin' : 'Select Destination Coin',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._coins.where((crypto) {
              return isFromCrypto
                  ? crypto.symbol != _toCrypto.symbol
                  : crypto.symbol != _fromCrypto.symbol;
            }).map((crypto) {
              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.cardLightBackground,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      crypto.symbol.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  crypto.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textWhite,
                  ),
                ),
                subtitle: Text(
                  crypto.symbol.toUpperCase(),
                  style: const TextStyle(color: AppTheme.textGrey),
                ),
                trailing: Text(
                  crypto.formattedPrice,
                  style: const TextStyle(color: AppTheme.textWhite),
                ),
                onTap: () {
                  setState(() {
                    if (isFromCrypto) {
                      _fromCrypto = crypto;
                    } else {
                      _toCrypto = crypto;
                    }
                    _calculateToAmount();
                  });
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        );
      },
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
    );
  }

  void _showSwapConfirmationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppTheme.cardDarkBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirm Swap',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 24),
              _buildSwapDetailsRow(
                'You Pay',
                _fromAmountController.text,
                _fromCrypto.symbol.toUpperCase(),
              ),
              const SizedBox(height: 16),
              _buildSwapDetailsRow(
                'You Receive (est.)',
                _toAmountController.text,
                _toCrypto.symbol.toUpperCase(),
              ),
              const SizedBox(height: 16),
              _buildSwapDetailsRow(
                'Exchange Rate',
                '1 ${_fromCrypto.symbol.toUpperCase()}',
                '${(_toCrypto.currentPrice > 0 ? _fromCrypto.currentPrice / _toCrypto.currentPrice : 0).toStringAsFixed(6)} ${_toCrypto.symbol.toUpperCase()}',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.textGrey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textWhite,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _executeSwap();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onLime,
                        ),
                      ),
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

  Widget _buildSwapDetailsRow(String label, String amount, String symbol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppTheme.textGrey),
        ),
        Row(
          children: [
            Text(
              amount,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textWhite,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              symbol,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textWhite,
              ),
            ),
          ],
        ),
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
      await _loadMarket();
      _showSwapSuccessDialog(qtyReceived);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _swapping = false);
      _showSwapErrorDialog(err.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _swapping = false);
      _showSwapErrorDialog('Unexpected error while swapping.');
    }
  }

  void _showSwapErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppTheme.cardDarkBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Swap failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textLightGrey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onLime),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSwapSuccessDialog(double qtyReceived) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppTheme.cardDarkBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.onLime,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Swap Successful!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You have successfully swapped ${_fromAmountController.text} ${_fromCrypto.symbol.toUpperCase()} for ${qtyReceived.toStringAsFixed(6)} ${_toCrypto.symbol.toUpperCase()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textLightGrey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onLime,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
