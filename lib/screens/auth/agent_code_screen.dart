import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'auth_flow.dart';
import 'onboarding_ui.dart';

/// Optional step: the referral code of the Fareenn agent who registered the
/// customer. Linking it credits that agent for the onboarding and for their
/// share of the customer's activity. Skippable.
class AgentCodeScreen extends StatefulWidget {
  final OnboardingData data;
  const AgentCodeScreen({super.key, required this.data});

  @override
  State<AgentCodeScreen> createState() => _AgentCodeScreenState();
}

class _AgentCodeScreenState extends State<AgentCodeScreen> {
  final _code = TextEditingController();
  bool _saving = false;
  String? _error;
  String? _linkedName;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _canSubmit => _code.text.trim().length >= 3;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_linkedName != null) {
      AuthFlow.afterAgent(context, widget.data);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final name = await ApiService.linkAgent(_code.text.trim());
      if (!mounted) return;
      setState(() {
        _saving = false;
        _linkedName = name;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = err.message;
      });
    }
  }

  void _skip() => AuthFlow.afterAgent(context, widget.data);

  @override
  Widget build(BuildContext context) {
    final linked = _linkedName != null;
    return FzStepScaffold(
      step: 10,
      chapter: 'REFERRAL',
      eyebrow: 'OPTIONAL',
      title: 'Referral code',
      subtitle: 'If you were registered by a Fareenn agent, enter their referral code.',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!linked) ...[
            FzTextButton('Skip for now', onTap: _saving ? null : _skip),
            const SizedBox(height: 6),
          ],
          FzNavBar(
            onBack: () => Navigator.of(context).maybePop(),
            onNext: _submit,
            nextLabel: linked ? 'Continue' : 'Apply code',
            nextEnabled: linked || _canSubmit,
            busy: _saving,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[FzError(_error!), const SizedBox(height: 16)],
          if (linked)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x1A2BD48A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x802BD48A)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: Fz.green, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: Fz.bg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _linkedName!,
                          style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        const Text('Authorised agent', style: TextStyle(color: Fz.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            FzBigField(
              label: 'REFERRAL CODE',
              controller: _code,
              hint: 'AG1023',
              mono: true,
              autofocus: true,
              capitalization: TextCapitalization.characters,
              action: TextInputAction.done,
              onSubmitted: (_) {
                if (_canSubmit && !_saving) _submit();
              },
            ),
          const SizedBox(height: 14),
          const FzTip(
            Icons.storefront_outlined,
            'Agents provide cash deposits, withdrawals and card collection. The code is displayed at their outlet.',
          ),
        ],
      ),
    );
  }
}
