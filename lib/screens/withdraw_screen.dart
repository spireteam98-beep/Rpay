import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cryptocurrency.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/touch_scale.dart';

class WithdrawScreen extends StatefulWidget {
  final Cryptocurrency? selectedCrypto;

  const WithdrawScreen({Key? key, this.selectedCrypto}) : super(key: key);

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  Cryptocurrency? _selectedCrypto;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final String _network = 'Ethereum (ERC20)';
  final double _fee = 0.005;
  final double _availableBalance = 2.5;

  @override
  void initState() {
    super.initState();
    _selectedCrypto = widget.selectedCrypto ?? Cryptocurrency.mockData[0];
  }

  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Withdraw Crypto'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCryptoSelector(),
            const SizedBox(height: 24),
            _buildNetworkSelector(),
            const SizedBox(height: 24),
            _buildAmountField(),
            const SizedBox(height: 24),
            _buildAddressField(),
            const SizedBox(height: 24),
            _buildMemoField(),
            const SizedBox(height: 24),
            _buildWithdrawSummary(),
            const SizedBox(height: 24),
            _buildWithdrawButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Coin',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        TouchScale(
          onTap: () {
            _showCryptoSelectionBottomSheet();
          },
          child: BybitCard(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: BybitPalette.surface2,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _selectedCrypto!.symbol.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCrypto!.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _selectedCrypto!.symbol.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: BybitPalette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: BybitPalette.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCryptoSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BybitPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: BybitPalette.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select Coin to Withdraw',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search coins',
                  hintStyle: const TextStyle(color: BybitPalette.muted),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: BybitPalette.muted,
                  ),
                  filled: true,
                  fillColor: BybitPalette.input,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: Cryptocurrency.mockData.length,
                itemBuilder: (context, index) {
                  final crypto = Cryptocurrency.mockData[index];
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: BybitPalette.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          crypto.symbol.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      crypto.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      '${crypto.symbol.toUpperCase()} • Available: 2.5',
                      style: const TextStyle(color: BybitPalette.muted),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCrypto = crypto;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
    );
  }

  Widget _buildNetworkSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Network',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        BybitCard(
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ethereum (ERC20)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Network Fee: 0.005 ETH',
                      style: TextStyle(fontSize: 12, color: BybitPalette.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: BybitPalette.muted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        BybitCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: BybitPalette.muted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Text(
                    _selectedCrypto!.symbol.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available: $_availableBalance ${_selectedCrypto!.symbol.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: BybitPalette.muted,
                    ),
                  ),
                  TouchScale(
                    onTap: () {
                      setState(() {
                        _amountController.text = _availableBalance.toString();
                      });
                    },
                    child: const Text(
                      'MAX',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: BybitPalette.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Withdrawal Address',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        BybitCard(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addressController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter or paste address',
                    hintStyle: TextStyle(color: BybitPalette.muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    setState(() {
                      _addressController.text = data!.text!;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Address pasted from clipboard'),
                        backgroundColor: BybitPalette.surface2,
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.paste_rounded,
                  color: BybitPalette.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Memo (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Tooltip(
              message: 'Some exchanges require a memo/tag for deposits',
              child: Icon(
                Icons.info_outline_rounded,
                color: BybitPalette.muted,
                size: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BybitCard(
          child: TextField(
            controller: _memoController,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter memo if required',
              hintStyle: TextStyle(color: BybitPalette.muted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawSummary() {
    double amount = double.tryParse(_amountController.text) ?? 0;
    double totalAmount = amount - _fee;
    if (totalAmount < 0) totalAmount = 0;

    return BybitCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Network Fee',
                style: TextStyle(fontSize: 14, color: BybitPalette.muted2),
              ),
              Text(
                '$_fee ${_selectedCrypto!.symbol.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: BybitPalette.surface2),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'You will receive',
                style: TextStyle(fontSize: 14, color: BybitPalette.muted2),
              ),
              Text(
                '$totalAmount ${_selectedCrypto!.symbol.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawButton() {
    return BybitPrimaryButton(
      label: 'Withdraw',
      onTap: () {
        if (_addressController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a withdrawal address'),
              backgroundColor: BybitPalette.red,
            ),
          );
          return;
        }

        if (_amountController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter an amount'),
              backgroundColor: BybitPalette.red,
            ),
          );
          return;
        }

        _showWithdrawConfirmationDialog();
      },
    );
  }

  void _showWithdrawConfirmationDialog() {
    double amount = double.tryParse(_amountController.text) ?? 0;
    double totalAmount = amount - _fee;
    if (totalAmount < 0) totalAmount = 0;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: BybitPalette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Confirm Withdrawal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please confirm your withdrawal details',
                  style: TextStyle(fontSize: 14, color: BybitPalette.muted2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildConfirmationRow(
                  'Coin',
                  '${_selectedCrypto!.name} (${_selectedCrypto!.symbol.toUpperCase()})',
                ),
                const SizedBox(height: 12),
                _buildConfirmationRow('Network', _network),
                const SizedBox(height: 12),
                _buildConfirmationRow(
                  'Amount',
                  '$amount ${_selectedCrypto!.symbol.toUpperCase()}',
                ),
                const SizedBox(height: 12),
                _buildConfirmationRow(
                  'Fee',
                  '$_fee ${_selectedCrypto!.symbol.toUpperCase()}',
                ),
                const SizedBox(height: 12),
                _buildConfirmationRow(
                  'You will receive',
                  '$totalAmount ${_selectedCrypto!.symbol.toUpperCase()}',
                ),
                const SizedBox(height: 12),
                _buildConfirmationRow('Address', _addressController.text),
                if (_memoController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildConfirmationRow('Memo', _memoController.text),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: BybitPalette.surface2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showWithdrawSuccessDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BybitPalette.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: BybitPalette.muted2),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showWithdrawSuccessDialog() {
    double amount = double.tryParse(_amountController.text) ?? 0;
    double totalAmount = amount - _fee;
    if (totalAmount < 0) totalAmount = 0;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: BybitPalette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: BybitPalette.accent,
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.black,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Withdrawal Successful',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalAmount ${_selectedCrypto!.symbol.toUpperCase()} has been sent to your wallet',
                  style: const TextStyle(
                    fontSize: 14,
                    color: BybitPalette.muted2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                BybitPrimaryButton(
                  label: 'Done',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }
}
