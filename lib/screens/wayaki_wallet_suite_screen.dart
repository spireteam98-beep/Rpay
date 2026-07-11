import 'package:flutter/material.dart';

import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/touch_scale.dart';
import 'cash_in_screen.dart';
import 'ledger_screen.dart';
import 'receive_screen.dart';
import 'send_money_screen.dart';

class WayakiWalletSuiteScreen extends StatelessWidget {
  const WayakiWalletSuiteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const KashBackBar('Wayaki Wallet'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HeroHeader(),
              const SizedBox(height: 16),
              _ScreenSection(
                title: 'Wallet home',
                subtitle: 'Balance, actions, wallet status, and activity.',
                child: _WalletHomeMock(
                  onSend:
                      () => Navigator.of(
                        context,
                      ).push(kashRoute(const SendMoneyScreen())),
                  onReceive:
                      () => Navigator.of(
                        context,
                      ).push(kashRoute(const ReceiveScreen())),
                  onTopUp:
                      () => Navigator.of(
                        context,
                      ).push(kashRoute(const CashInScreen())),
                  onHistory:
                      () => Navigator.of(
                        context,
                      ).push(kashRoute(const LedgerScreen())),
                ),
              ),
              const _ScreenSection(
                title: 'Issue Wayaki Card',
                subtitle: 'User chooses card type before final checks.',
                child: _IssueCardMock(),
              ),
              const _ScreenSection(
                title: 'Wayaki Card',
                subtitle: 'Mastercard/Visa-ready card control surface.',
                child: _CardManagementMock(),
              ),
              const _ScreenSection(
                title: 'Send money',
                subtitle: 'Recipient, amount, review, then auth stop.',
                child: _SendMoneyMock(),
              ),
              const _ScreenSection(
                title: 'Pay bills',
                subtitle: 'Merchant, bill number, card or wallet funding.',
                child: _BillPayMock(),
              ),
              const _ScreenSection(
                title: 'Transaction detail',
                subtitle: 'Receipt, status, reference, and support action.',
                child: _TransactionDetailMock(),
              ),
              const _ScreenSection(
                title: 'KYC and limits',
                subtitle: 'Verification progress and unlocked limits.',
                child: _KycLimitsMock(),
              ),
              const _ScreenSection(
                title: 'Security',
                subtitle: 'PIN, biometrics, device, and auth boundary.',
                child: _SecurityMock(),
              ),
              const _ScreenSection(
                title: 'Settings',
                subtitle: 'Account controls for the wallet product.',
                child: _SettingsMock(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: BybitPalette.accent.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WayakiWordmark(size: 38),
          const SizedBox(height: 10),
          const Text(
            'Wallet, cards, transfers and authentication screens for Kashflip.',
            style: TextStyle(
              color: BybitPalette.muted,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              _MetricPill('KES wallet'),
              SizedBox(width: 8),
              _MetricPill('Virtual card'),
              SizedBox(width: 8),
              _MetricPill('Auth safe'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScreenSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ScreenSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: BybitPalette.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _PhonePanel(child: child),
        ],
      ),
    );
  }
}

class _PhonePanel extends StatelessWidget {
  final Widget child;

  const _PhonePanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF090A0B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child: child,
    );
  }
}

class _WalletHomeMock extends StatelessWidget {
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onTopUp;
  final VoidCallback onHistory;

  const _WalletHomeMock({
    required this.onSend,
    required this.onReceive,
    required this.onTopUp,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            _WayakiWordmark(size: 28),
            _RoundIcon(Icons.notifications_none_rounded),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE9FF3D), BybitPalette.accent],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Available balance',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'KES 128,450.00',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Wallet active - KYC verified',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _ActionButton(
              icon: Icons.arrow_upward_rounded,
              label: 'Send',
              onTap: onSend,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.arrow_downward_rounded,
              label: 'Receive',
              onTap: onReceive,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.add_rounded,
              label: 'Top Up',
              onTap: onTopUp,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.history_rounded,
              label: 'History',
              onTap: onHistory,
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _ListRow(
          icon: Icons.local_cafe_rounded,
          title: 'Java House',
          subtitle: 'Card payment',
          trailing: '-KES 820',
          danger: true,
        ),
        const _ListRow(
          icon: Icons.phone_android_rounded,
          title: 'M-Pesa Top Up',
          subtitle: 'Wallet deposit',
          trailing: '+KES 12,000',
          positive: true,
        ),
      ],
    );
  }
}

class _IssueCardMock extends StatelessWidget {
  const _IssueCardMock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WayakiWordmark(size: 28),
        const SizedBox(height: 14),
        const Text(
          'Choose your card',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        const _WayakiCard(network: 'Mastercard', compact: true),
        const SizedBox(height: 10),
        const _WayakiCard(network: 'Visa', compact: true),
        const SizedBox(height: 14),
        const _InfoBand(
          icon: Icons.verified_user_rounded,
          title: 'Ready after verification',
          body: 'We confirm identity and limits before issuing.',
        ),
        const SizedBox(height: 12),
        const _PrimaryMockButton('Continue'),
      ],
    );
  }
}

class _CardManagementMock extends StatelessWidget {
  const _CardManagementMock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _WayakiCard(network: 'Mastercard'),
        SizedBox(height: 14),
        _ToggleRow(
          icon: Icons.lock_rounded,
          title: 'Freeze card',
          subtitle: 'Block all card spending',
          checked: false,
        ),
        _ToggleRow(
          icon: Icons.public_rounded,
          title: 'Online payments',
          subtitle: 'Allow web and app purchases',
          checked: true,
        ),
        _ToggleRow(
          icon: Icons.payments_rounded,
          title: 'Daily limit',
          subtitle: 'KES 50,000 available today',
          checked: true,
        ),
      ],
    );
  }
}

class _SendMoneyMock extends StatelessWidget {
  const _SendMoneyMock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Send money',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 12),
        _FieldPreview(label: 'Recipient', value: '+254 748 666 773'),
        SizedBox(height: 8),
        _FieldPreview(label: 'Amount', value: 'KES 2,500'),
        SizedBox(height: 8),
        _FieldPreview(label: 'Fee', value: 'KES 0'),
        SizedBox(height: 14),
        _InfoBand(
          icon: Icons.lock_outline_rounded,
          title: 'Authentication required',
          body: 'The assistant stops before PIN, password, biometric, or OTP.',
        ),
        SizedBox(height: 12),
        _PrimaryMockButton('Review transfer'),
      ],
    );
  }
}

class _BillPayMock extends StatelessWidget {
  const _BillPayMock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Pay bill',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 12),
        _FieldPreview(label: 'Merchant', value: 'KPLC Prepaid'),
        SizedBox(height: 8),
        _FieldPreview(label: 'Account', value: '5467 8821 09'),
        SizedBox(height: 8),
        _FieldPreview(label: 'Funding', value: 'Wayaki Card'),
        SizedBox(height: 14),
        _InfoBand(
          icon: Icons.receipt_long_rounded,
          title: 'Bill confirmation',
          body: 'Receipt and token appear after provider confirmation.',
        ),
        SizedBox(height: 12),
        _PrimaryMockButton('Continue to pay'),
      ],
    );
  }
}

class _TransactionDetailMock extends StatelessWidget {
  const _TransactionDetailMock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ReceiptStatus(),
        SizedBox(height: 12),
        _FieldPreview(label: 'Status', value: 'Completed'),
        SizedBox(height: 8),
        _FieldPreview(label: 'Reference', value: 'WYK-2846-1290'),
        SizedBox(height: 8),
        _FieldPreview(label: 'Date', value: 'Jul 11, 2026'),
        SizedBox(height: 12),
        _PrimaryMockButton('Download receipt'),
      ],
    );
  }
}

class _KycLimitsMock extends StatelessWidget {
  const _KycLimitsMock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Verification',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 12),
        _ProgressStep(title: 'Phone verified', done: true),
        _ProgressStep(title: 'ID document captured', done: true),
        _ProgressStep(title: 'Selfie match', done: true),
        _ProgressStep(title: 'Enhanced limits review', done: false),
        SizedBox(height: 12),
        _FieldPreview(label: 'Daily send limit', value: 'KES 150,000'),
        SizedBox(height: 8),
        _FieldPreview(label: 'Card limit', value: 'KES 50,000'),
      ],
    );
  }
}

class _SecurityMock extends StatelessWidget {
  const _SecurityMock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ToggleRow(
          icon: Icons.fingerprint_rounded,
          title: 'Biometric login',
          subtitle: 'Use device biometrics',
          checked: true,
        ),
        _ToggleRow(
          icon: Icons.pin_rounded,
          title: 'Transaction PIN',
          subtitle: 'Required for money movement',
          checked: true,
        ),
        _ToggleRow(
          icon: Icons.phonelink_lock_rounded,
          title: 'Trusted device',
          subtitle: 'This phone is trusted',
          checked: true,
        ),
        _InfoBand(
          icon: Icons.shield_rounded,
          title: 'Assistant boundary',
          body:
              'No automated flow enters PIN, password, OTP, CVV, or biometrics.',
        ),
      ],
    );
  }
}

class _SettingsMock extends StatelessWidget {
  const _SettingsMock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ListRow(
          icon: Icons.person_outline_rounded,
          title: 'Personal details',
          subtitle: 'Name, phone, email',
          trailing: 'Edit',
        ),
        _ListRow(
          icon: Icons.account_balance_rounded,
          title: 'Linked accounts',
          subtitle: 'Banks and mobile money',
          trailing: '3',
        ),
        _ListRow(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          subtitle: 'Push, SMS, email',
          trailing: 'On',
        ),
        _ListRow(
          icon: Icons.support_agent_rounded,
          title: 'Support',
          subtitle: 'Disputes and card help',
          trailing: 'Open',
        ),
      ],
    );
  }
}

class _WayakiWordmark extends StatelessWidget {
  final double size;
  const _WayakiWordmark({this.size = 32});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: r'\W',
            style: TextStyle(
              color: BybitPalette.accent,
              fontSize: size,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              height: 1,
            ),
          ),
          TextSpan(
            text: 'ayaki',
            style: TextStyle(
              color: BybitPalette.accent,
              fontSize: size,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _WayakiCard extends StatelessWidget {
  final String network;
  final bool compact;

  const _WayakiCard({required this.network, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: compact ? 132 : 190,
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1E20), Color(0xFF050506), Color(0xFF1F260A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BybitPalette.accent.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _WayakiWordmark(size: compact ? 24 : 30),
              Text(
                network,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (!compact)
            Row(
              children: [
                Container(
                  width: 40,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9B56E),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '****  ****  ****  2846',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _CardMeta(label: 'CARD HOLDER', value: 'WAYAKI USER'),
              _CardMeta(label: 'VALID', value: '08/29', alignEnd: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardMeta extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _CardMeta({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: BybitPalette.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TouchScale(
        onTap: onTap,
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: BybitPalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF242832)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: BybitPalette.accent, size: 20),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  const _RoundIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: BybitPalette.surface2,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _ListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final bool danger;
  final bool positive;

  const _ListRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.danger = false,
    this.positive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: BybitPalette.surface2,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: BybitPalette.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BybitPalette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              color:
                  positive
                      ? BybitPalette.green
                      : danger
                      ? BybitPalette.red
                      : BybitPalette.accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool checked;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.checked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child: Row(
        children: [
          _RoundIcon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: BybitPalette.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 26,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: checked ? BybitPalette.accent : BybitPalette.surface2,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Align(
              alignment: checked ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: checked ? Colors.black : BybitPalette.muted,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldPreview extends StatelessWidget {
  final String label;
  final String value;

  const _FieldPreview({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: BybitPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBand extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoBand({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BybitPalette.accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BybitPalette.accent.withOpacity(0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BybitPalette.accent, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: BybitPalette.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
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

class _MetricPill extends StatelessWidget {
  final String label;
  const _MetricPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: BybitPalette.accent.withOpacity(0.18)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: BybitPalette.accent,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PrimaryMockButton extends StatelessWidget {
  final String label;
  const _PrimaryMockButton(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BybitPalette.accent,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReceiptStatus extends StatelessWidget {
  const _ReceiptStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: const [
          CircleAvatar(
            radius: 28,
            backgroundColor: BybitPalette.accent,
            child: Icon(Icons.check_rounded, color: Colors.black, size: 34),
          ),
          SizedBox(height: 12),
          Text(
            'KES 2,500 sent',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'To +254 748 666 773',
            style: TextStyle(
              color: BybitPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final String title;
  final bool done;

  const _ProgressStep({required this.title, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: done ? BybitPalette.accent : BybitPalette.surface2,
            child: Icon(
              done ? Icons.check_rounded : Icons.more_horiz_rounded,
              color: done ? Colors.black : BybitPalette.muted,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
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
