import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/kash_account.dart';
import '../models/ledger_entry.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';
import 'account_detail_screen.dart';
import 'bill_pay_screen.dart';
import 'cash_in_screen.dart';
import 'kyc_limits_screen.dart';
import 'ledger_screen.dart';
import 'profile_screen.dart';
import 'receive_screen.dart';
import 'send_money_screen.dart';
import 'swap_screen.dart';
import '../widgets/brand_logo.dart';
import '../widgets/fareenn_card.dart';
import '../widgets/spending_insight_card.dart';
import '../widgets/my_card_panel.dart';
import 'physical_card_screen.dart';
import 'card_charge_screen.dart';
import 'merchant_screen.dart';
import 'notifications_screen.dart';
import '../widgets/verified_tick.dart';
import '../widgets/account_move_sheet.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../constants/brand.dart';

/// Wallet home — red brand header with a dotted texture, then a charcoal
/// sheet that rises over it holding quick actions, a promo card,
/// highlights, accounts and recent activity.
class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _hideBalance = false;
  bool _cardFrozen = false;

  /// Live unread count + incoming notifications (GET /social/stream).
  final _rt = RealtimeService.instance;
  StreamSubscription<Map<String, dynamic>>? _incomingSub;

  int get _unread => _rt.unreadNotifications;

  @override
  void initState() {
    super.initState();
    _rt.start();
    _rt.refreshCounts();
    _incomingSub = _rt.incoming.listen(_showBanner);
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }

  /// Pop-up the moment a notification arrives; tap View for the full message.
  void _showBanner(Map<String, dynamic> n) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          backgroundColor: BybitPalette.surface2,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n['title'] as String? ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(n['body'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: BybitPalette.muted, fontSize: 12.5)),
            ],
          ),
          action: SnackBarAction(
            label: 'View',
            textColor: BybitPalette.accent,
            onPressed: () => openNotification(context, n),
          ),
        ),
      );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(kashRoute(const NotificationsScreen()));
    _rt.refreshCounts();
  }

  /// Home shows the red wallet header; the Cards toggle swaps it for the
  /// user's card with its Manage panel.
  int _view = 0; // 0 Wallet, 1 Cards, 2 Business
  bool get _cardsView => _view == 1;
  List<dynamic>? _merchants;
  List<dynamic>? _sales;
  bool _bizLoading = false;

  Future<void> _loadBusiness() async {
    setState(() => _bizLoading = true);
    final list = await ApiService.myMerchants();
    List<dynamic>? sales;
    final active = list?.cast<Map<String, dynamic>>().where((m) => m['status'] == 'ACTIVE').toList() ?? [];
    if (active.isNotEmpty) sales = await ApiService.merchantPayments(active.first['id'] as String);
    if (!mounted) return;
    setState(() {
      _merchants = list ?? const [];
      _sales = sales;
      _bizLoading = false;
    });
  }
  final _insightKey = GlobalKey<SpendingInsightCardState>();

  static final NumberFormat _money = NumberFormat.currency(symbol: '\$');

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: BybitPalette.bg,
        body: SafeArea(
          bottom: false,
          // A one-off sync failure at app launch (weak connection, etc.)
          // otherwise leaves balances/activity stuck stale for the rest of
          // the session — syncFromBackend only runs once, in
          // MainNavigation.initState, so pull-to-refresh retries it.
          child: RefreshIndicator(
            color: BybitPalette.accent,
            backgroundColor: Colors.white,
            onRefresh: () => appState.syncFromBackend(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _insightKey.currentState?.checkVisible();
                return false;
              },
              child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(context, appState),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _view == 2
                        ? Column(
                            key: const ValueKey('business'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 6),
                              Center(child: _viewToggle()),
                              const SizedBox(height: 18),
                              _businessView(context),
                            ],
                          )
                        : _cardsView
                        ? Column(
                            key: const ValueKey('cards'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 6),
                              Center(child: _viewToggle()),
                              _kycStatusBanner(context, appState),
                              const SizedBox(height: 14),
                              // The user's card with Swap / Freeze /
                              // Send / Receive below it.
                              _myCard(context, appState),
                              const SizedBox(height: 18),
                              _tapCardTile(context),
                              const SizedBox(height: 8),
                            ],
                          )
                        : Column(
                            key: const ValueKey('wallet'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Stack(
                                children: [
                                  _waveHeader(context, appState),
                                  Positioned(
                                    top: 6,
                                    left: 0,
                                    right: 0,
                                    child: Center(child: _viewToggle()),
                                  ),
                                ],
                              ),
                              _kycStatusBanner(context, appState),
                            ],
                          ),
                  ),
                  if (_view != 2) _sheet(context, appState, showQuickActions: !_cardsView),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────

  /// Black top bar — wordmark, notifications and profile — sitting above
  /// the red wave, same arrangement as the Markets screen.
  Widget _topBar(BuildContext context, KashAppState appState) {
    final name = appState.firstName.trim();
    final initial = name.isEmpty ? 'W' : name.substring(0, 1).toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          const FareennLogo(height: 30),
          const Spacer(),
          if (_cardsView) ...[
            _headerCircle(
              color: BybitPalette.surface2,
              onTap: () => setState(() => _hideBalance = !_hideBalance),
              child: Icon(
                _hideBalance
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
          ],
          _headerCircle(
            color: BybitPalette.surface2,
            onTap: () {
              final k = _kycInfo(appState);
              if (k.status != _KycState.approved && _unread == 0) {
                // Nothing in the inbox yet: keep showing the KYC nudge.
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('${k.title}: ${k.message}')));
              }
              _openNotifications();
            },
            child: ListenableBuilder(
              listenable: _rt,
              builder: (context, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                if (_unread > 0)
                  Positioned(
                    right: -8,
                    top: -7,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: BybitPalette.accent,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: BybitPalette.surface2, width: 1.5),
                      ),
                      child: Text(
                        _unread > 99 ? '99+' : '$_unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, height: 1.1),
                      ),
                    ),
                  )
                else if (_kycInfo(appState).status != _KycState.approved)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: BybitPalette.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: BybitPalette.surface2, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            ),
          ),
          const SizedBox(width: 10),
          TouchScale(
            onTap:
                () => Navigator.of(
                  context,
                ).push(kashRoute(const ProfileScreen())),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: BybitPalette.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Approved (KYC) users get a verified tick instead of any
                // KYC banner or status text.
                if (_kycInfo(appState).status == _KycState.approved)
                  const Positioned(right: -3, bottom: -3, child: VerifiedTick(size: 17)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Red "wave scoop" panel (shared [BybitWaveClipper], as on Markets)
  /// holding the greeting, balance and the wallet/add-money row.
  Widget _waveHeader(BuildContext context, KashAppState appState) {
    final name = appState.firstName.trim();
    const height = 330.0;
    // The clipper dips 34% of the height at the centre; keep text below it.
    const topPad = height * 0.34 + 4;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipPath(
        clipper: const BybitWaveClipper(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BybitPalette.accentSoft, BybitPalette.accent],
              stops: [0, 0.45],
            ),
          ),
          child: CustomPaint(
            painter: const _DotGridPainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, topPad, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Hello' : 'Hello, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total balance',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _hideBalance ? '••••••' : appState.totalBalance,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _headerCircle(
                        size: 38,
                        onTap:
                            () =>
                                setState(() => _hideBalance = !_hideBalance),
                        child: Icon(
                          _hideBalance
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      TouchScale(
                        onTap: () => _openWalletDetails(context, appState),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Wallet details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      TouchScale(
                        onTap:
                            () => Navigator.of(
                              context,
                            ).push(kashRoute(const CashInScreen())),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.8),
                          ),
                          child: const Text(
                            'Add money',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }

  Widget _headerCircle({
    required Widget child,
    required VoidCallback onTap,
    double size = 42,
    Color? color,
  }) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? Colors.black.withOpacity(0.18),
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }

  void _openWalletDetails(BuildContext context, KashAppState appState) {
    final accounts = appState.visibleAccounts;
    if (accounts.isEmpty) {
      Navigator.of(context).push(kashRoute(const LedgerScreen()));
      return;
    }
    Navigator.of(
      context,
    ).push(kashRoute(AccountDetailScreen(account: accounts.first)));
  }

  // ── Sheet ──────────────────────────────────────────────────────────

  /// Wallet / Cards switch shown at the top of the dashboard.
  Widget _viewToggle() {
    Widget seg(String label, IconData icon, int v) {
      final selected = _view == v;
      return Expanded(
        child: TouchScale(
          onTap: () {
            if (_view == v) return;
            HapticFeedback.selectionClick();
            setState(() => _view = v);
            if (v == 2) _loadBusiness();
          },
          child: SizedBox(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : BybitPalette.muted,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : BybitPalette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: 296,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment(_view - 1.0, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: BybitPalette.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66E60000),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              seg('Wallet', Icons.account_balance_wallet_outlined, 0),
              seg('Cards', Icons.credit_card_rounded, 1),
              seg('Business', Icons.storefront_rounded, 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheet(
    BuildContext context,
    KashAppState appState, {
    bool showQuickActions = true,
  }) {
    return Container(
      color: BybitPalette.bg,
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showQuickActions) ...[
            _quickActions(context),
            const SizedBox(height: 34),
          ],
          _sectionHeading('For you'),
          const SizedBox(height: 16),
          _promoCard(context),
          const SizedBox(height: 34),
          _sectionHeading(
            'Accounts',
            action: 'Convert',
            onAction:
                () =>
                    appState.isCurrencyAdded(KashAccountType.walletKes)
                        ? _openConvertSheet(context)
                        : _openAddCurrencySheet(
                          context,
                          appState.addableCurrencies,
                        ),
          ),
          const SizedBox(height: 16),
          _accountCards(context, appState),
          const SizedBox(height: 34),
          _sectionHeading(
            'People',
            action: 'See all',
            onAction:
                () => Navigator.of(
                  context,
                ).push(kashRoute(const SendMoneyScreen())),
          ),
          const SizedBox(height: 16),
          _peopleRow(context, appState),
          const SizedBox(height: 30),
          _sectionHeading(
            'Recent activity',
            action: 'See all',
            onAction:
                () => Navigator.of(
                  context,
                ).push(kashRoute(const LedgerScreen())),
          ),
          const SizedBox(height: 16),
          _recentActivity(context, appState),
          const SizedBox(height: 24),
          _sectionHeading('Insights'),
          const SizedBox(height: 16),
          _insights(context, appState),
        ],
      ),
    );
  }

  Widget _sectionHeading(
    String title, {
    String? action,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
          ),
          if (action != null)
            TouchScale(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  action,
                  style: const TextStyle(
                    color: BybitPalette.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Quick actions ──────────────────────────────────────────────────

  Widget _quickActions(BuildContext context) {
    final actions = <(IconData, String, Widget)>[
      (Icons.north_east_rounded, 'Send', const SendMoneyScreen()),
      (Icons.south_west_rounded, 'Receive', const ReceiveScreen()),
      (Icons.smartphone_rounded, 'Cash in', const CashInScreen()),
      (Icons.receipt_long_rounded, 'Pay bills', const BillPayScreen()),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final a in actions)
            TouchScale(
              onTap: () => Navigator.of(context).push(kashRoute(a.$3)),
              child: SizedBox(
                width: 72,
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: BybitPalette.surface2,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        a.$1,
                        color: BybitPalette.accentIcon,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      a.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── For you ────────────────────────────────────────────────────────

  Widget _promoCard(BuildContext context) {
    void order() => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fareenn cards are coming soon')),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TouchScale(
        onTap: order,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: LayoutBuilder(
              builder: (context, cons) {
                final w = cons.maxWidth;
                final orb = w * 0.95;
                return Container(
                  color: const Color(0xFFA30000),
                  child: Stack(
                    children: [
                      // Brand-red disc bleeding off the top-right corner.
                      Positioned(
                        right: -w * 0.2,
                        top: -orb * 0.3,
                        width: orb,
                        height: orb,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: BybitPalette.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // The Fareenn card, tilting in 3D to touch and mouse.
                      Align(
                        alignment: const Alignment(0.3, 0.8),
                        child: SizedBox(
                          width: w * 0.58,
                          child: const TiltCard(child: FareennCard()),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        top: 18,
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Order now',
                                style: TextStyle(
                                  color: Color(0xFFA30000),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFFA30000),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Highlights ─────────────────────────────────────────────────────

  /// Where the user is in identity verification, for the top banner and
  /// the notification bell.
  _KycInfo _kycInfo(KashAppState appState) {
    final status = appState.kycStatus;
    if (status == 'APPROVED' || (status == null && appState.kycSubmitted)) {
      final id = appState.walletNumber;
      return _KycInfo(
        _KycState.approved,
        'Verified',
        id == null || id.isEmpty ? 'Your account is fully verified' : 'Your Wallet ID is $id',
      );
    }
    if (status == 'PENDING_REVIEW') {
      return const _KycInfo(
        _KycState.review,
        'Under review',
        'Your application is under review. Your Wallet ID will be issued once verification is complete.',
      );
    }
    if (status == 'REJECTED') {
      return _KycInfo(
        _KycState.rejected,
        'Unsuccessful',
        appState.kycRejectReason?.isNotEmpty == true
            ? appState.kycRejectReason!
            : 'Please update your details and try again.',
      );
    }
    return const _KycInfo(
      _KycState.pending,
      'KYC pending',
      'Finish verifying your identity to activate your card and Wallet ID.',
    );
  }

  Widget _kycStatusBanner(BuildContext context, KashAppState appState) {
    final k = _kycInfo(appState);
    // Approved users only see the verified tick on their avatar; the
    // banner is just for people still verifying or with an issue to fix.
    if (k.status == _KycState.approved) return const SizedBox.shrink();
    final (Color color, IconData icon) = switch (k.status) {
      _KycState.approved => (const Color(0xFF2BD48A), Icons.verified_rounded),
      _KycState.review => (const Color(0xFF6CB8F2), Icons.hourglass_top_rounded),
      _KycState.rejected => (const Color(0xFFFF5A5F), Icons.error_outline_rounded),
      _KycState.pending => (const Color(0xFFF5B83D), Icons.pending_actions_rounded),
    };
    final tappable =
        k.status == _KycState.pending || k.status == _KycState.rejected;
    final banner = Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'KYC status',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        k.title,
                        style: const TextStyle(
                          color: Color(0xFF0D0D0D),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  k.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 12.5, height: 1.3),
                ),
              ],
            ),
          ),
          if (tappable)
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
    if (!tappable) return banner;
    return TouchScale(
      onTap: () => Navigator.of(context).push(kashRoute(const KycLimitsScreen())),
      child: banner,
    );
  }

  /// The user's Fareenn card, issued once identity checks are complete.
  // ── Business ───────────────────────────────────────────────────────

  /// Business tab: apply to become a business, see the review status, or —
  /// once approved — use this phone as a POS terminal for Fareenn cards.
  /// The Business account: its own USD/KES balance, separate from the
  /// owner's wallet. Every sale lands here; "Move to wallet" pays the owner.
  Widget _businessAccountCard(BuildContext context, Map<String, dynamic> m) {
    final fmt = NumberFormat('#,##0.00');
    double bal(String k) => double.tryParse('${m[k] ?? 0}') ?? 0;
    final usd = bal('balance_usd'), kes = bal('balance_kes');
    Widget amount(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: BybitPalette.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_hideBalance ? '••••' : value,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              ),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded, color: BybitPalette.accentIcon, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Business account',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              TouchScale(
                onTap: () => setState(() => _hideBalance = !_hideBalance),
                child: Icon(_hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: BybitPalette.muted, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [amount('USD', '\$${fmt.format(usd)}'), amount('KES', 'KES ${fmt.format(kes)}')]),
          const SizedBox(height: 6),
          const Text('Sales are paid into this account, separate from your personal wallet.',
              style: TextStyle(color: BybitPalette.muted, fontSize: 12)),
          const SizedBox(height: 14),
          BybitPrimaryButton(
            label: 'Move to my wallet',
            enabled: usd > 0 || kes > 0,
            onTap: () => _moveToWallet(context, m, usd: usd, kes: kes),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToWallet(BuildContext context, Map<String, dynamic> m, {required double usd, required double kes}) async {
    final picked = await showAccountMoveSheet(
      context,
      title: 'Move to my wallet',
      subtitle: 'From ${m['name'] ?? 'your business'} to your personal wallet. Instant and free.',
      available: {'USD': usd, 'KES': kes},
      actionLabel: 'Move to wallet',
    );
    if (picked == null || !context.mounted) return;
    try {
      await ApiService.merchantToWallet(m['id'] as String, amount: picked.amount, currency: picked.currency);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${picked.currency} ${picked.amount.toStringAsFixed(2)} moved to your wallet'),
      ));
      _loadBusiness();
      context.read<KashAppState>().syncFromBackend();
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _businessView(BuildContext context) {
    final list = _merchants?.cast<Map<String, dynamic>>();
    if (list == null || (_bizLoading && list.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: BybitPalette.accent)),
      );
    }
    final active = list.where((m) => m['status'] == 'ACTIVE').toList();
    final pending = list.where((m) => m['status'] == 'PENDING').toList();
    Future<void> openMerchant() async {
      await Navigator.of(context).push(kashRoute(const MerchantScreen()));
      if (mounted) _loadBusiness();
    }

    Widget panel({required Widget child, Color? border}) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border ?? const Color(0x1FFFFFFF)),
          ),
          child: child,
        );

    if (active.isEmpty && pending.isEmpty) {
      Widget perk(IconData icon, String text) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(icon, color: BybitPalette.accentIcon, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5))),
              ],
            ),
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Become a business', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                const Text('Turn your Android phone into a payment terminal and accept Fareenn payments.',
                    style: TextStyle(color: BybitPalette.muted, fontSize: 14, height: 1.4)),
                const SizedBox(height: 8),
                perk(Icons.contactless_outlined, 'Accept Fareenn card taps with customer PIN'),
                perk(Icons.qr_code_2_rounded, 'Get a business ID and QR code for payments'),
                perk(Icons.receipt_long_rounded, 'Track sales and add staff tellers'),
                const SizedBox(height: 20),
                BybitPrimaryButton(label: 'Apply for a business account', onTap: openMerchant),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }
    if (active.isEmpty) {
      final m = pending.first;
      return Column(
        children: [
          panel(
            border: const Color(0x596CB8F2),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, color: BybitPalette.credit),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m['name'] as String? ?? 'Your business',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Your business application is under review. Payment features unlock once it is approved.',
                          style: TextStyle(color: BybitPalette.muted, fontSize: 13, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }
    final m = active.first;
    final sales = (_sales ?? const []).cast<Map<String, dynamic>>();
    final money = NumberFormat('#,##0.00');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['name'] as String? ?? 'Business',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text('Business ID ${m['till_number'] ?? ''}', style: const TextStyle(color: BybitPalette.muted, fontSize: 13.5)),
                  ],
                ),
              ),
              TouchScale(
                onTap: openMerchant,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(20)),
                  child: const Text('QR & staff', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _businessAccountCard(context, m),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TouchScale(
            onTap: () async {
              await Navigator.of(context).push(kashRoute(
                CardChargeScreen(merchantId: m['id'] as String, merchantName: m['name'] as String? ?? 'Business'),
              ));
              if (mounted) _loadBusiness();
            },
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF2D2D), Color(0xFFE60000), Color(0xFFB00000)],
                ),
                boxShadow: const [BoxShadow(color: Color(0x59E60000), blurRadius: 30, offset: Offset(0, 12))],
              ),
              padding: const EdgeInsets.all(22),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('POS', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2)),
                        SizedBox(height: 6),
                        Text('Charge a card', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                        SizedBox(height: 4),
                        Text('Enter amount · customer taps · PIN', style: TextStyle(color: Colors.white70, fontSize: 13.5)),
                      ],
                    ),
                  ),
                  Icon(Icons.contactless_outlined, color: Colors.white, size: 64),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _sectionHeading('Recent sales'),
        const SizedBox(height: 12),
        if (sales.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('No sales yet. Your first card payment will show here.',
                style: TextStyle(color: BybitPalette.muted, fontSize: 14)),
          )
        else
          for (final p in sales.take(8))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0x1F2BD48A),
                    child: Icon(Icons.south_west_rounded, color: Color(0xFF2BD48A), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['payer_name'] as String? ?? 'Customer',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(
                          DateFormat('d MMM, HH:mm').format(DateTime.tryParse(p['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now()),
                          style: const TextStyle(color: BybitPalette.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Text('+${p['currency']} ${money.format(double.tryParse('${p['amount']}') ?? 0)}',
                      style: const TextStyle(color: Color(0xFF2BD48A), fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Entry to the physical Fareenn tap card: link, freeze or block it.
  Widget _tapCardTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TouchScale(
        onTap: () => Navigator.of(context).push(kashRoute(const PhysicalCardScreen())),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: const Row(
            children: [
              Icon(Icons.contactless_outlined, color: BybitPalette.accentIcon, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Physical tap card', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Link, freeze or block your Fareenn card', style: TextStyle(color: BybitPalette.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: BybitPalette.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _myCard(BuildContext context, KashAppState appState) {
    void open(Widget screen) => Navigator.of(context).push(kashRoute(screen));
    void snack(String m) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
    return MyCardPanel(
      holderName:
          appState.profileName.trim().isEmpty ? 'Fareenn member' : appState.profileName,
      balanceText: appState.totalBalance,
      last4: '4821',
      expiry: '09/30',
      active: appState.kycSubmitted,
      walletNumber: appState.walletNumber,
      kycStatus: appState.kycStatus,
      kycRejectReason: appState.kycRejectReason,
      frozen: _cardFrozen,
      hideBalance: _hideBalance,
      onSwap: () => open(const SwapScreen()),
      onFreeze: () {
        setState(() => _cardFrozen = !_cardFrozen);
        snack(_cardFrozen ? 'Card frozen' : 'Card unfrozen');
      },
      onSend: () => open(const SendMoneyScreen()),
      onReceive: () => open(const ReceiveScreen()),
      onActivate: () => open(const KycLimitsScreen()),
    );
  }

  /// Animated spending card: real daily spending for this month once the
  /// user has activity, otherwise a labelled example so the chart is alive.
  Widget _insights(BuildContext context, KashAppState appState) {
    final now = DateTime.now();
    final daily = List<double>.filled(now.day, 0);
    double spent = 0, received = 0;
    for (final t in appState.ledgerTransactions) {
      if (t.entries.isEmpty) continue;
      if (t.postedAt.year != now.year || t.postedAt.month != now.month) {
        continue;
      }
      final e = t.entries.first;
      if (e.direction == LedgerDirection.debit) {
        spent += e.amountUsd;
        daily[t.postedAt.day - 1] += e.amountUsd;
      } else {
        received += e.amountUsd;
      }
    }
    final limit = appState.tier.dailyLimit;
    final double limitUsed =
        limit <= 0 ? 0.0 : (appState.spentToday / limit).clamp(0.0, 1.0).toDouble();

    final isExample = spent <= 0;
    final List<double> bars;
    final double total;
    final double saved;
    final double used;
    if (isExample) {
      // A believable month: everyday rhythm with a few bigger days.
      bars = List<double>.generate(
        now.day < 12 ? 24 : now.day,
        (i) =>
            18 +
            22 * (0.5 + 0.5 * math.sin(i * 0.9)) +
            (i % 7 == 5 ? 46 : 0) +
            (i % 11 == 3 ? 30 : 0),
      );
      total = bars.fold(0.0, (a, b) => a + b);
      saved = 0.34;
      used = 0.57;
    } else {
      bars = daily;
      total = spent;
      saved = received <= 0
          ? 0.0
          : ((received - spent) / received).clamp(0.0, 1.0).toDouble();
      used = limitUsed;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SpendingInsightCard(
        key: _insightKey,
        daily: bars,
        total: total,
        limitUsed: used,
        saved: saved,
        isExample: isExample,
        hideAmounts: _hideBalance,
        onOpen: () =>
            Navigator.of(context).push(kashRoute(const LedgerScreen())),
      ),
    );
  }

  Widget _highlights(BuildContext context, KashAppState appState) {
    final now = DateTime.now();
    double spentThisMonth = 0;
    for (final t in appState.ledgerTransactions) {
      if (t.entries.isEmpty) continue;
      if (t.postedAt.year != now.year || t.postedAt.month != now.month) {
        continue;
      }
      final entry = t.entries.first;
      if (entry.direction == LedgerDirection.debit) {
        spentThisMonth += entry.amountUsd;
      }
    }

    final limit = appState.tier.dailyLimit;
    final used = appState.spentToday;
    final progress = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _highlightCard(
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const LedgerScreen())),
                icon: Icons.show_chart_rounded,
                title: 'Spending',
                value: _money.format(spentThisMonth),
                children: [
                  const Text(
                    'This month',
                    style: TextStyle(color: BybitPalette.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'View insights',
                    style: TextStyle(
                      color: Color(0xFFC7C7CC),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _highlightCard(
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const KycLimitsScreen())),
                icon: Icons.track_changes_rounded,
                title: 'Daily limit',
                value: '${(progress * 100).round()}%',
                children: [
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Stack(
                      children: [
                        Container(height: 6, color: const Color(0xFF3A3A3C)),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 6,
                            color: BybitPalette.accentSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_money.format(used)} of ${_money.format(limit)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BybitPalette.muted,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlightCard({
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required String value,
    required List<Widget> children,
  }) {
    return TouchScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }

  // ── People (only when the user has real frequent recipients) ───────

  /// Horizontal, swipeable row of people to pay: real frequent recipients
  /// when there are any, otherwise example contacts, always ending with a
  /// brand-red "More" button that opens Send.
  Widget _peopleRow(BuildContext context, KashAppState appState) {
    final real = appState.frequentRecipients;
    const palette = [
      Color(0xFF3B82F6),
      Color(0xFFA855F7),
      Color(0xFF14B8A6),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF22C55E),
      Color(0xFF6366F1),
    ];
    final people = <({String name, String? id})>[
      if (real.isNotEmpty)
        for (final p in real)
          (
            name: (p['label'] as String?)?.trim().isNotEmpty == true
                ? p['label'] as String
                : '?',
            id: p['identifier'] as String?,
          )
      else
        for (final n in const [
          'Omar',
          'Amina',
          'Hodan',
          'Abdi',
          'Fatima',
          'Yusuf',
          'Layla',
        ])
          (name: n, id: null),
    ];

    void openSend([String? id]) => Navigator.of(context).push(
          kashRoute(SendMoneyScreen(initialRecipient: id)),
        );

    Widget bubble({required Widget face, required String label, VoidCallback? onTap}) =>
        TouchScale(
          onTap: onTap,
          child: SizedBox(
            width: 72,
            child: Column(
              children: [
                face,
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFBDBDC2),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );

    final items = <Widget>[
      for (var i = 0; i < people.length; i++)
        bubble(
          label: people[i].name.split(' ').first,
          onTap: () => openSend(people[i].id),
          face: Container(
            width: 66,
            height: 66,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x2EFFFFFF), width: 1.2),
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette[i % palette.length],
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials(people[i].name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      bubble(
        label: 'More',
        onTap: () => openSend(),
        face: Container(
          width: 66,
          height: 66,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: BybitPalette.accent,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    ];

    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return (first + last).toUpperCase();
  }

  // ── Accounts ───────────────────────────────────────────────────────

  void _openConvertSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ConvertSheet(),
    );
  }

  Widget _accountCards(BuildContext context, KashAppState appState) {
    final accounts = appState.visibleAccounts;
    final addable = appState.addableCurrencies;
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: accounts.length + (addable.isNotEmpty ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          if (i >= accounts.length) {
            return _addCurrencyCard(context, addable);
          }
          final account = accounts[i];
          return TouchScale(
            onTap:
                () => Navigator.of(
                  context,
                ).push(kashRoute(AccountDetailScreen(account: account))),
            child: Container(
              width: 168,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BybitPalette.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: BybitPalette.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          account.icon,
                          color: BybitPalette.accentIcon,
                          size: 18,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        account.currency,
                        style: const TextStyle(
                          color: BybitPalette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    account.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BybitPalette.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hideBalance ? '••••' : account.balance,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Dashed "Add currency" tile appended after the user's real accounts —
  /// opens a sheet listing every currency wallet they haven't added yet
  /// (KES today; any later one shows up here with no extra UI code).
  Widget _addCurrencyCard(BuildContext context, List<KashAccount> addable) {
    return TouchScale(
      onTap: () => _openAddCurrencySheet(context, addable),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BybitPalette.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 22),
            SizedBox(height: 8),
            Text(
              'Add currency',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddCurrencySheet(BuildContext context, List<KashAccount> addable) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddCurrencySheet(addable: addable),
    );
  }

  // ── Recent activity ────────────────────────────────────────────────

  static const _creditGreen = Color(0xFF2BD48A);
  static const _debitRed = Color(0xFFFF5A5F);

  /// Each transaction is its own frosted-glass tile: avatar, title and
  /// time on the left, amount (green in, red out) and a second line on
  /// the right. Until the user has real activity, labelled examples show
  /// what the list will look like.
  Widget _recentActivity(BuildContext context, KashAppState appState) {
    final recent =
        appState.ledgerTransactions
            .where((t) => t.entries.isNotEmpty)
            .take(6)
            .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child:
          recent.isEmpty
              ? _sampleActivity()
              : Column(
                children: [
                  for (final t in recent) ...[
                    _activityRow(context, t),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
    );
  }

  /// Frosted glass surface on the dark sheet: a faint white fill, a
  /// hairline highlight border and a soft blur of whatever is behind.
  Widget _glassTile({required Widget child, VoidCallback? onTap}) {
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x1AFFFFFF), Color(0x0AFFFFFF)],
            ),
            border: Border.all(color: const Color(0x1FFFFFFF), width: 1),
          ),
          child: child,
        ),
      ),
    );
    return onTap == null ? tile : TouchScale(onTap: onTap, child: tile);
  }

  Widget _activityLayout({
    required Widget avatar,
    required String title,
    required String when,
    required String amount,
    required bool credit,
    required String sideNote,
  }) {
    return Row(
      children: [
        avatar,
        const SizedBox(width: 14),
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
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                when,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: BybitPalette.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _hideBalance ? '••••' : amount,
              style: TextStyle(
                color: credit ? _creditGreen : _debitRed,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _hideBalance ? '••••' : sideNote,
              style: const TextStyle(color: BybitPalette.muted, fontSize: 12.5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _circle({required Widget child, Color color = const Color(0x1FFFFFFF)}) =>
      Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: child,
      );

  /// Shown until the user has real transactions: a clearly labelled set
  /// of example activity, so the screen shows what it will look like.
  Widget _sampleActivity() {
    final now = DateTime.now();
    final items = <_SampleTx>[
      _SampleTx.icon('USD → KES', 'Converted', 120.00,
          credit: true, icon: Icons.swap_horiz_rounded,
          color: Colors.white, at: now.subtract(const Duration(minutes: 18))),
      _SampleTx.person('Omar Hassan', 'Received', 250.00,
          credit: true, initials: 'OH', color: const Color(0xFF3B82F6),
          at: now.subtract(const Duration(minutes: 42))),
      _SampleTx.logo('Netflix', 'Subscription', 15.49,
          asset: 'assets/images/netflix.jpg',
          at: now.subtract(const Duration(hours: 3))),
      _SampleTx.person('Amina Yusuf', 'Sent', 40.00,
          initials: 'AY', color: const Color(0xFFA855F7),
          at: now.subtract(const Duration(hours: 6))),
      _SampleTx.logo('Starbucks', 'Card tap', 6.80,
          asset: 'assets/images/starbuxks.jpg',
          at: now.subtract(const Duration(days: 1, hours: 2))),
      _SampleTx.icon('KPLC Electricity', 'Bill payment', 18.20,
          icon: Icons.bolt_rounded, color: const Color(0xFFF59E0B),
          at: now.subtract(const Duration(days: 1, hours: 5))),
      _SampleTx.logo('M-Pesa top up', 'Top up', 100.00,
          credit: true, asset: 'assets/images/mpesa.png',
          at: now.subtract(const Duration(days: 2, hours: 1))),
      _SampleTx.logo('Apple', 'App Store', 2.99,
          asset: 'assets/images/apple.png',
          at: now.subtract(const Duration(days: 4, hours: 3))),
    ];
    // Running balance after each example, newest first.
    var balance = 4250.80;
    final balances = <double>[];
    for (final t in items) {
      balances.add(balance);
      balance -= t.credit ? t.amount : -t.amount;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'EXAMPLES',
                  style: TextStyle(
                    color: BybitPalette.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your own transactions will show here.',
                  style: TextStyle(color: BybitPalette.muted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < items.length; i++) ...[
          _glassTile(
            child: _activityLayout(
              avatar: _sampleAvatar(items[i]),
              title: items[i].title,
              when: '${items[i].subtitle} · ${_when(items[i].at)}',
              amount:
                  '${items[i].credit ? '+' : '-'}${_money.format(items[i].amount)}',
              credit: items[i].credit,
              sideNote: _money.format(balances[i]),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _sampleAvatar(_SampleTx t) {
    if (t.asset != null) {
      return _circle(
        color: Colors.white,
        child: Image.asset(t.asset!, width: 48, height: 48, fit: BoxFit.cover),
      );
    }
    if (t.initials != null) {
      return _circle(
        color: t.color,
        child: Text(
          t.initials!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return _circle(child: Icon(t.icon, color: t.color, size: 24));
  }

  String _when(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final time = DateFormat('H:mm').format(t);
    if (day == today) return 'Today, $time';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }
    return DateFormat('MMM d, H:mm').format(t);
  }

  Widget _activityRow(BuildContext context, LedgerTransaction transaction) {
    final isTopUp = transaction.title.toLowerCase().contains('cash-in');
    final entry = transaction.entries.first;
    final isCredit = entry.direction == LedgerDirection.credit;
    final label =
        isTopUp ? '${displayRail(transaction.rail)} Top-up' : transaction.title;

    final IconData icon;
    final Color iconColor;
    if (isTopUp) {
      icon = Icons.add_rounded;
      iconColor = _creditGreen;
    } else if (isCredit) {
      icon = Icons.south_west_rounded;
      iconColor = _creditGreen;
    } else {
      icon = Icons.north_east_rounded;
      iconColor = BybitPalette.accentIcon;
    }

    return _glassTile(
      onTap: () => Navigator.of(context).push(kashRoute(const LedgerScreen())),
      child: _activityLayout(
        avatar: _circle(child: Icon(icon, color: iconColor, size: 22)),
        title: label,
        when: _when(transaction.postedAt),
        amount: entry.amountLabel,
        credit: isCredit,
        sideNote: entry.accountName,
      ),
    );
  }
}

/// Faint dot lattice over the red header, like the reference texture.
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1F000000);
    const gap = 9.0;
    for (double y = gap / 2; y < size.height; y += gap) {
      for (double x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom sheet that moves value between the user's own Fareenn USD and
/// Fareenn KES accounts — the one deliberate bridge between the two
/// currencies (everything else stays strictly separated).
/// Lists the currency wallets the user hasn't added yet (KES today) and
/// unlocks whichever one they pick via [KashAppState.addCurrency].
class _AddCurrencySheet extends StatelessWidget {
  final List<KashAccount> addable;

  const _AddCurrencySheet({required this.addable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      decoration: const BoxDecoration(
        color: BybitPalette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BybitPalette.muted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Add a currency',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Unlock another wallet to send, receive and pay in that currency.',
            style: TextStyle(color: BybitPalette.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          for (final account in addable)
            TouchScale(
              onTap: () {
                context.read<KashAppState>().addCurrency(account.type);
                Navigator.of(context).pop();
                BybitToast.success(
                  context,
                  '${account.currency} wallet added',
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BybitPalette.surface2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: BybitPalette.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        account.icon,
                        color: BybitPalette.accentIcon,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            account.subtitle,
                            style: const TextStyle(
                              color: BybitPalette.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.add_circle_rounded,
                      color: BybitPalette.accentIcon,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConvertSheet extends StatefulWidget {
  const _ConvertSheet();

  @override
  State<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends State<_ConvertSheet> {
  final TextEditingController _amountController = TextEditingController();
  bool _kesToUsd = true;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    final from = _kesToUsd ? 'KES' : 'USD';
    final to = _kesToUsd ? 'USD' : 'KES';
    final fromAccount = appState.accountByType(
      _kesToUsd ? KashAccountType.walletKes : KashAccountType.walletUsd,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BybitPalette.muted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Convert currency',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Available: ${fromAccount.balance}',
              style: const TextStyle(color: BybitPalette.muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _CurrencyPill(label: from)),
                TouchScale(
                  onTap:
                      _submitting
                          ? null
                          : () => setState(() => _kesToUsd = !_kesToUsd),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: BybitPalette.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sync_alt_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                ),
                Expanded(child: _CurrencyPill(label: to)),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: BybitPalette.surface2,
                hintText: 'Amount in $from',
                hintStyle: const TextStyle(color: BybitPalette.muted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            BybitPrimaryButton(
              label: _submitting ? 'Converting…' : 'Convert',
              enabled: !_submitting,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter an amount greater than 0.')));
      return;
    }
    setState(() => _submitting = true);
    final result = await context.read<KashAppState>().convertCurrency(
      from: _kesToUsd ? 'KES' : 'USD',
      to: _kesToUsd ? 'USD' : 'KES',
      amount: amount,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) Navigator.of(context).pop();
  }
}

class _CurrencyPill extends StatelessWidget {
  final String label;

  const _CurrencyPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BybitPalette.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242832)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// One example row for the empty "Recent activity" list.
class _SampleTx {
  final String title;
  final String subtitle;
  final double amount;
  final bool credit;
  final DateTime at;
  final String? asset;
  final String? initials;
  final IconData? icon;
  final Color color;

  _SampleTx.person(this.title, this.subtitle, this.amount,
      {this.credit = false,
      required String this.initials,
      required this.color,
      required this.at})
      : asset = null,
        icon = null;

  _SampleTx.logo(this.title, this.subtitle, this.amount,
      {this.credit = false, required String this.asset, required this.at})
      : initials = null,
        icon = null,
        color = Colors.white;

  _SampleTx.icon(this.title, this.subtitle, this.amount,
      {this.credit = false,
      required IconData this.icon,
      required this.color,
      required this.at})
      : asset = null,
        initials = null;
}

enum _KycState { pending, review, rejected, approved }

class _KycInfo {
  final _KycState status;
  final String title;
  final String message;
  const _KycInfo(this.status, this.title, this.message);
}
