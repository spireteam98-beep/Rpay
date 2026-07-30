import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../state/kash_app_state.dart';
import '../widgets/bybit_wallet_ui.dart';
import '../widgets/kash_widgets.dart';
import '../widgets/polish.dart';
import '../widgets/touch_scale.dart';
import 'auth/welcome_screen.dart';

/// The real Settings destinations: Personal details (name and email are
/// editable — email requires re-verifying the new address; phone is
/// locked, shown but not editable, per compliance — it's the account's
/// KYC-linked identifier), Linked accounts (the same three real wallet
/// accounts shown elsewhere),
/// Notifications (client-side preference toggles, no backend dispatch
/// system to wire them to), Support (the shared contact dialog), and Delete
/// account (in-app deletion request, required by App Store Guideline
/// 5.1.1(v) — see POST /auth/delete-account).
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
                'Name, email, phone',
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
              _tile(
                context,
                Icons.policy_outlined,
                'Legal & privacy',
                'Policies, data choices and support',
                onTap: () => _showLegalCenter(context),
              ),
              const SizedBox(height: 8),
              _tile(
                context,
                Icons.delete_outline_rounded,
                'Delete account',
                'Permanently close your Wayaki account',
                onTap: () => _confirmDeleteAccount(context),
                destructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: BybitPalette.surface,
            title: const Text(
              'Delete your account?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'This closes your Wayaki account and signs you out on every '
              'device. Financial and identity records we\'re legally required '
              'to retain will be kept for the mandated period and then '
              'deleted — see our Privacy Policy for details. This can\'t be '
              'undone from the app.',
              style: TextStyle(color: BybitPalette.muted2),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ApiService.deleteAccount();
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $err')),
      );
      return;
    }

    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      kashRoute(const WelcomeScreen()),
      (route) => false,
    );
  }

  void _showLegalCenter(BuildContext context) {
    const links = [
      ('Privacy Policy', '/privacy'),
      ('Terms of Service', '/terms'),
      ('Data & account deletion', '/data-deletion'),
      ('KYC Policy', '/kyc-policy'),
      ('AML Policy', '/aml-policy'),
      ('Cookie Policy', '/cookies'),
      ('Refund Policy', '/refund-policy'),
      ('Risk disclosure', '/disclaimer'),
      ('Support', '/support'),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BybitPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (sheetContext) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Legal & privacy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        links
                            .map(
                              (link) => ActionChip(
                                label: Text(link.$1),
                                onPressed:
                                    () => launchUrl(
                                      Uri.parse('https://wayaki.com${link.$2}'),
                                      mode: LaunchMode.externalApplication,
                                    ),
                              ),
                            )
                            .toList(),
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
    bool destructive = false,
  }) {
    final iconColor = destructive ? Colors.redAccent : BybitPalette.accent;
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
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: destructive ? Colors.redAccent : Colors.white,
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
              _field(
                context,
                'Full name',
                appState.profileName,
                onTap: () => _editName(context, appState.profileName),
              ),
              const SizedBox(height: 10),
              _field(
                context,
                'Email',
                appState.email.isEmpty ? 'Not set' : appState.email,
                onTap: () => _changeEmail(context),
              ),
              const SizedBox(height: 10),
              _field(context, 'Phone', appState.phoneNumber, locked: true),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  "Phone number can't be changed — it's tied to your verified identity for compliance.",
                  style: TextStyle(color: BybitPalette.muted, fontSize: 11.5, height: 1.3),
                ),
              ),
              const SizedBox(height: 10),
              _field(
                context,
                'Verification',
                appState.phoneVerified ? 'Phone verified' : 'Phone unverified',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editName(BuildContext context, String currentName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditNameSheet(currentName: currentName),
    );
  }

  void _changeEmail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangeEmailSheet(),
    );
  }

  Widget _field(
    BuildContext context,
    String label,
    String value, {
    VoidCallback? onTap,
    bool locked = false,
  }) {
    final card = Container(
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
          if (locked) ...[
            const SizedBox(width: 8),
            const Icon(Icons.lock_outline_rounded, color: BybitPalette.muted, size: 15),
          ] else if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, color: BybitPalette.accent, size: 15),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return TouchScale(onTap: onTap, child: card);
  }
}

/// Bottom sheet: edit full name (no re-verification needed).
class _EditNameSheet extends StatefulWidget {
  final String currentName;
  const _EditNameSheet({required this.currentName});

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.currentName);
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your full name');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiService.updateFullName(name);
      if (!mounted) return;
      context.read<KashAppState>().updateProfileNameLocal(name);
      Navigator.of(context).pop();
      BybitToast.success(context, 'Name updated');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = err.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetShell(
      title: 'Edit full name',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BybitTextField(
            label: 'Full name',
            hint: 'Mohamed Ali',
            icon: Icons.person_outline_rounded,
            controller: _controller,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: BybitPalette.red, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 20),
          BybitPrimaryButton(
            label: _submitting ? 'Saving…' : 'Save',
            enabled: !_submitting,
            onTap: _save,
          ),
        ],
      ),
    );
  }
}

enum _EmailChangeStep { enterEmail, enterCode }

/// Bottom sheet: change email — a two-step flow (enter new address, then
/// the code sent to it) since email is a login credential and lookup key,
/// unlike the full name.
class _ChangeEmailSheet extends StatefulWidget {
  const _ChangeEmailSheet();

  @override
  State<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<_ChangeEmailSheet> {
  _EmailChangeStep _step = _EmailChangeStep.enterEmail;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String _pendingEmail = '';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiService.requestEmailChange(email);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _pendingEmail = email;
        _step = _EmailChangeStep.enterCode;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = err.message;
      });
    }
  }

  Future<void> _confirmCode() async {
    final code = _codeController.text.trim();
    if (code.length != 4) {
      setState(() => _error = 'Enter the 4-digit code');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final newEmail = await ApiService.confirmEmailChange(code);
      if (!mounted) return;
      context.read<KashAppState>().updateEmailLocal(newEmail);
      Navigator.of(context).pop();
      BybitToast.success(context, 'Email updated');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = err.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _EmailChangeStep.enterEmail) {
      return _BottomSheetShell(
        title: 'Change email',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BybitTextField(
              label: 'New email address',
              hint: 'you@example.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: BybitPalette.red, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 20),
            BybitPrimaryButton(
              label: _submitting ? 'Sending…' : 'Send code',
              enabled: !_submitting,
              onTap: _sendCode,
            ),
          ],
        ),
      );
    }
    return _BottomSheetShell(
      title: 'Enter the code',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We sent a code to $_pendingEmail.',
            style: const TextStyle(color: BybitPalette.muted2, fontSize: 13),
          ),
          const SizedBox(height: 16),
          BybitTextField(
            label: 'Verification code',
            hint: '0000',
            icon: Icons.password_rounded,
            keyboardType: TextInputType.number,
            controller: _codeController,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: BybitPalette.red, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 20),
          BybitPrimaryButton(
            label: _submitting ? 'Confirming…' : 'Confirm',
            enabled: !_submitting,
            onTap: _confirmCode,
          ),
        ],
      ),
    );
  }
}

/// Shared bottom-sheet chrome (title + close button) used by the personal
/// details / security edit sheets.
class _BottomSheetShell extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: BybitPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TouchScale(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: BybitPalette.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: BybitPalette.muted2,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _LinkedAccountsScreen extends StatelessWidget {
  const _LinkedAccountsScreen();

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<KashAppState>().visibleAccounts;
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
