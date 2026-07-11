import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';

/// The four real Settings destinations: Personal details (read-only — no
/// PATCH /auth/me exists yet, so this deliberately isn't a fake edit form),
/// Linked accounts (the same three real wallet accounts shown elsewhere),
/// Notifications (client-side preference toggles, no backend dispatch
/// system to wire them to), and Support (the shared contact dialog).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Settings'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            children: [
              _tile(
                context,
                Icons.person_outline_rounded,
                'Personal details',
                'Name, phone',
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const _PersonalDetailsScreen())),
              ),
              _tile(
                context,
                Icons.account_balance_rounded,
                'Linked accounts',
                'Banks and mobile money',
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const _LinkedAccountsScreen())),
              ),
              _tile(
                context,
                Icons.notifications_none_rounded,
                'Notifications',
                'Push, SMS, email',
                onTap:
                    () => Navigator.of(
                      context,
                    ).push(kashRoute(const _NotificationsScreen())),
              ),
              _tile(
                context,
                Icons.support_agent_rounded,
                'Support',
                'Disputes and card help',
                onTap: () => showSupportDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TouchScale(
        onTap: onTap,
        child: BybitCard(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: BybitPalette.surface2,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: BybitPalette.accent, size: 19),
              ),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BybitPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: BybitPalette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalDetailsScreen extends StatelessWidget {
  const _PersonalDetailsScreen();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Personal details'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('Full name', appState.profileName),
              const SizedBox(height: 10),
              _field('Phone', appState.phoneNumber),
              const SizedBox(height: 10),
              _field(
                'Verification',
                appState.phoneVerified ? 'Phone verified' : 'Phone unverified',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value) {
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

class _LinkedAccountsScreen extends StatelessWidget {
  const _LinkedAccountsScreen();

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<KashAppState>().accounts;
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Linked accounts'),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BybitCard(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: account.accent.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        account.icon,
                        color: account.accent,
                        size: 19,
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
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            account.subtitle,
                            style: const TextStyle(
                              color: BybitPalette.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      account.balance,
                      style: const TextStyle(
                        color: BybitPalette.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationsScreen extends StatelessWidget {
  const _NotificationsScreen();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<KashAppState>();
    return Scaffold(
      backgroundColor: BybitPalette.bg,
      appBar: const BybitSubHeader('Notifications'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              _toggle(
                context,
                Icons.notifications_none_rounded,
                'Push notifications',
                'Alerts for transfers and activity',
                appState.notifyPush,
                (v) => appState.setNotificationPrefs(push: v),
              ),
              _toggle(
                context,
                Icons.sms_outlined,
                'SMS notifications',
                'Text alerts for money movement',
                appState.notifySms,
                (v) => appState.setNotificationPrefs(sms: v),
              ),
              _toggle(
                context,
                Icons.email_outlined,
                'Email notifications',
                'Statements and account updates',
                appState.notifyEmail,
                (v) => appState.setNotificationPrefs(email: v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    bool checked,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TouchScale(
        onTap: () => onChanged(!checked),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: BybitPalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF242832)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: BybitPalette.surface2,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: BybitPalette.accent, size: 19),
              ),
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 26,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: checked ? BybitPalette.accent : BybitPalette.surface2,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Align(
                  alignment:
                      checked ? Alignment.centerRight : Alignment.centerLeft,
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
        ),
      ),
    );
  }
}
