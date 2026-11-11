import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../widgets/bybit_wallet_ui.dart';
import '../../widgets/touch_scale.dart';
import 'auth_flow.dart';
import 'onboarding_ui.dart';

class _Country {
  final String flag;
  final String name;
  final String dial;
  const _Country(this.flag, this.name, this.dial);
}

/// Region codes used in the Fareenn Wallet ID.
const _regions = <String, String>{
  '2': 'Banadir',
  '3': 'Galmudug',
  '4': 'Hirshabelle',
  '5': 'Puntland',
  '6': 'Jubaland',
  '7': 'South West',
  '8': 'Somaliland',
  '9': 'Outside Somalia',
};

const _countries = [
  _Country('🇸🇴', 'Somalia', '+252'),
  _Country('🇰🇪', 'Kenya', '+254'),
  _Country('🇪🇹', 'Ethiopia', '+251'),
  _Country('🇺🇬', 'Uganda', '+256'),
  _Country('🇹🇿', 'Tanzania', '+255'),
  _Country('🇷🇼', 'Rwanda', '+250'),
  _Country('🇩🇯', 'Djibouti', '+253'),
  _Country('🇦🇪', 'United Arab Emirates', '+971'),
  _Country('🇸🇦', 'Saudi Arabia', '+966'),
  _Country('🇹🇷', 'Türkiye', '+90'),
  _Country('🇬🇧', 'United Kingdom', '+44'),
  _Country('🇺🇸', 'United States', '+1'),
  _Country('🇨🇦', 'Canada', '+1'),
  _Country('🇸🇪', 'Sweden', '+46'),
  _Country('🇳🇴', 'Norway', '+47'),
];

/// The questions of the identity (KYC) step, one per screen.
enum _Q { name, phone, gender, region, address, docType, front, back, selfie }

/// Identity verification, asked one question per screen right after Google
/// confirms the account: legal name, mobile number, gender, region,
/// residential address, document type, both sides of the document and a
/// selfie. Everything is sent together at the end for review.
class ProfileSetupScreen extends StatefulWidget {
  final OnboardingData data;
  const ProfileSetupScreen({super.key, required this.data});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  String? _gender; // 'male' | 'female'
  String _idType = 'nira_id';
  String? _region; // region code, see _regions
  final Map<String, List<int>> _photos = {};
  final Map<String, String> _photoTypes = {};
  _Country _country = _countries.first;

  int _index = 0;
  String? _fieldError;
  String? _error;
  bool _submitting = false;
  int _submitStage = 0; // 0..4 items ticked on the submitting screen

  _Q get _q => _Q.values[_index];

  @override
  void initState() {
    super.initState();
    _first = TextEditingController(text: widget.data.firstName);
    _last = TextEditingController(text: widget.data.lastName);
    for (final c in [_first, _last, _phone, _address]) {
      c.addListener(() {
        if (_fieldError != null) _fieldError = null;
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  String get _localDigits => _phone.text.replaceAll(RegExp(r'\D'), '');

  /// E.164: dial code + local number without its leading trunk 0.
  String get _e164 {
    var local = _localDigits;
    if (local.startsWith('0')) local = local.substring(1);
    return '${_country.dial}$local';
  }

  static final _nameOk = RegExp(r"^[\p{L}\p{M}' .-]{1,50}$", unicode: true);

  /// Whether the current question has an answer, so Next can light up.
  bool get _answered {
    switch (_q) {
      case _Q.name:
        return _first.text.trim().isNotEmpty && _last.text.trim().isNotEmpty;
      case _Q.phone:
        return _localDigits.length >= 6;
      case _Q.gender:
        return _gender != null;
      case _Q.region:
        return _region != null;
      case _Q.address:
        return _address.text.trim().length >= 5;
      case _Q.docType:
        return true;
      case _Q.front:
        return _photos.containsKey('front');
      case _Q.back:
        return _photos.containsKey('back');
      case _Q.selfie:
        return _photos.containsKey('selfie');
    }
  }

  /// Checks the answer in detail when Next is pressed.
  String? _check() {
    switch (_q) {
      case _Q.name:
        if (!_nameOk.hasMatch(_first.text.trim()) || !_nameOk.hasMatch(_last.text.trim())) {
          return 'Use letters only, as shown on your identity document.';
        }
        return null;
      case _Q.phone:
        return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(_e164) ? null : 'Enter a valid mobile number.';
      default:
        return null;
    }
  }

  void _next() {
    if (!_answered) return;
    final problem = _check();
    if (problem != null) {
      HapticFeedback.heavyImpact();
      setState(() => _fieldError = problem);
      return;
    }
    FocusScope.of(context).unfocus();
    if (_q == _Q.selfie) {
      _submit();
      return;
    }
    setState(() {
      _fieldError = null;
      _error = null;
      _index++;
    });
  }

  void _back() {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (_index == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _fieldError = null;
      _error = null;
      _index--;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitStage = 0;
      _error = null;
    });
    // Tick the packaging steps while the upload runs.
    for (var i = 1; i <= 2; i++) {
      Future.delayed(Duration(milliseconds: 500 * i), () {
        if (mounted && _submitting && _submitStage < i) setState(() => _submitStage = i);
      });
    }
    try {
      await ApiService.completeProfile(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        phone: _e164,
        gender: _gender!,
        address: _address.text.trim(),
        idType: _idType,
        idNumber: '',
        regionCode: _region!,
        idFrontBytes: _photos['front']!,
        idFrontContentType: _photoTypes['front']!,
        idBackBytes: _photos['back']!,
        idBackContentType: _photoTypes['back']!,
        selfieBytes: _photos['selfie']!,
        selfieContentType: _photoTypes['selfie']!,
      );
      if (!mounted) return;
      setState(() => _submitStage = 4);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      widget.data
        ..firstName = _first.text.trim()
        ..lastName = _last.text.trim()
        ..phone = _e164;
      setState(() => _submitting = false);
      AuthFlow.afterProfile(context, widget.data);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = err.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = "Couldn't submit your application. Check your connection and try again.";
      });
    }
  }

  Future<void> _pickPhoto(String slot, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        preferredCameraDevice: slot == 'selfie' ? CameraDevice.front : CameraDevice.rear,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _photos[slot] = bytes;
        _photoTypes[slot] = file.mimeType ?? 'image/jpeg';
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't open the photo. Please try again.");
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<_Country>(
      context: context,
      backgroundColor: const Color(0xFF151517),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            for (final c in _countries)
              ListTile(
                onTap: () => Navigator.of(context).pop(c),
                leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                trailing: Text(c.dial, style: const TextStyle(color: BybitPalette.muted)),
                selected: c == _country,
                selectedTileColor: BybitPalette.surface2,
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _country = picked);
  }

  String get _docName => _idType == 'nira_id' ? 'NIRA ID' : 'passport';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0 && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: _submitting ? _submittingView() : _questionView(),
    );
  }

  Widget _questionView() {
    final (eyebrow, title, subtitle) = _copy();
    final isPhoto = _q == _Q.front || _q == _Q.back || _q == _Q.selfie;
    final slot = switch (_q) {
      _Q.front => 'front',
      _Q.back => 'back',
      _ => 'selfie',
    };
    final needsCapture = isPhoto && !_photos.containsKey(slot);
    return FzStepScaffold(
      step: _index + 1,
      chapter: 'ID',
      eyebrow: eyebrow,
      title: title,
      subtitle: subtitle,
      animationKey: _q,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (needsCapture) ...[
            Row(
              children: [
                FzPillButton(
                  icon: Icons.upload_rounded,
                  label: 'Upload',
                  onTap: () => _pickPhoto(slot, ImageSource.gallery),
                ),
                const Spacer(),
                FzShutter(onTap: () => _pickPhoto(slot, ImageSource.camera)),
                const Spacer(),
                const SizedBox(width: 104),
              ],
            ),
            const SizedBox(height: 14),
          ],
          FzNavBar(
            onBack: _back,
            onNext: _next,
            nextLabel: _q == _Q.selfie ? 'Submit' : 'Next',
            nextEnabled: _answered,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[FzError(_error!), const SizedBox(height: 16)],
          _questionBody(),
        ],
      ),
    );
  }

  (String, String, String) _copy() {
    switch (_q) {
      case _Q.name:
        return ('PERSONAL INFORMATION', 'Full legal name', 'Enter your name exactly as it appears on your identity document.');
      case _Q.phone:
        return ('PERSONAL INFORMATION', 'Mobile number', 'This number will be registered to your account and used for verification and transfers.');
      case _Q.gender:
        return ('PERSONAL INFORMATION', 'Gender', 'Select the gender stated on your identity document.');
      case _Q.region:
        return ('PERSONAL INFORMATION', 'Region of residence', 'Select the region where you currently reside.');
      case _Q.address:
        return ('PERSONAL INFORMATION', 'Residential address', 'Enter your current district and neighbourhood.');
      case _Q.docType:
        return ('IDENTITY VERIFICATION', 'Identity document', 'Select the government-issued document you will upload.');
      case _Q.front:
        return _photos.containsKey('front')
            ? ('IDENTITY VERIFICATION · 1 OF 3', 'Front of document', 'Make sure all details are clear and readable before you continue.')
            : ('IDENTITY VERIFICATION · 1 OF 3', 'Front of document', 'Place the front of your $_docName within the frame.');
      case _Q.back:
        return _photos.containsKey('back')
            ? ('IDENTITY VERIFICATION · 2 OF 3', 'Back of document', 'Make sure all details are clear and readable before you continue.')
            : ('IDENTITY VERIFICATION · 2 OF 3', 'Back of document', 'Place the back of your $_docName within the frame.');
      case _Q.selfie:
        return ('IDENTITY VERIFICATION · 3 OF 3', 'Selfie verification', 'Take a clear photo of your face to confirm you are the document holder.');
    }
  }

  Widget _questionBody() {
    switch (_q) {
      case _Q.name:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FzBigField(
              label: 'FIRST NAME',
              controller: _first,
              hint: 'Amina',
              autofocus: _first.text.isEmpty,
              capitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.givenName],
            ),
            const SizedBox(height: 14),
            FzBigField(
              label: 'LAST NAME',
              controller: _last,
              hint: 'Hassan',
              capitalization: TextCapitalization.words,
              action: TextInputAction.done,
              autofillHints: const [AutofillHints.familyName],
              onSubmitted: (_) => _next(),
              errorText: _fieldError,
            ),
            const SizedBox(height: 14),
            const FzTip(Icons.verified_user_outlined, 'Your information is encrypted and used only for identity verification.'),
          ],
        );
      case _Q.phone:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FzBigField(
              label: 'MOBILE NUMBER',
              controller: _phone,
              hint: '61 234 5678',
              mono: true,
              autofocus: true,
              keyboardType: TextInputType.phone,
              action: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              onSubmitted: (_) => _next(),
              errorText: _fieldError,
              prefix: TouchScale(
                onTap: _pickCountry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Fz.glass,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Fz.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_country.flag, style: const TextStyle(fontSize: 17)),
                      const SizedBox(width: 6),
                      Text(_country.dial, style: Fz.mono(15, color: Colors.white, spacing: 0.2)),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Fz.muted, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const FzTip(Icons.info_outline_rounded, 'The number must be registered in your name and active.'),
          ],
        );
      case _Q.gender:
        return Row(
          children: [
            Expanded(
              child: FzChoiceCard(
                title: 'Female',
                icon: Icons.female_rounded,
                tall: true,
                selected: _gender == 'female',
                onTap: () => setState(() => _gender = 'female'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FzChoiceCard(
                title: 'Male',
                icon: Icons.male_rounded,
                tall: true,
                selected: _gender == 'male',
                onTap: () => setState(() => _gender = 'male'),
              ),
            ),
          ],
        );
      case _Q.region:
        final entries = _regions.entries.toList();
        return Column(
          children: [
            for (var i = 0; i < entries.length; i += 2) ...[
              if (i > 0) const SizedBox(height: 10),
              Row(
                children: [
                  for (var j = i; j < i + 2 && j < entries.length; j++) ...[
                    if (j > i) const SizedBox(width: 10),
                    Expanded(
                      child: FzTile(
                        label: entries[j].value,
                        selected: _region == entries[j].key,
                        onTap: () => setState(() => _region = entries[j].key),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      case _Q.address:
        return FzBigField(
          label: 'RESIDENTIAL ADDRESS',
          controller: _address,
          hint: 'Hodan District, Mogadishu',
          autofocus: true,
          maxLines: 3,
          icon: Icons.location_on_outlined,
          capitalization: TextCapitalization.words,
          keyboardType: TextInputType.streetAddress,
          action: TextInputAction.done,
          autofillHints: const [AutofillHints.fullStreetAddress],
          onSubmitted: (_) => _next(),
        );
      case _Q.docType:
        return Column(
          children: [
            FzChoiceCard(
              title: 'NIRA ID',
              subtitle: 'Somali national identity card',
              icon: Icons.badge_outlined,
              selected: _idType == 'nira_id',
              onTap: () => setState(() => _idType = 'nira_id'),
            ),
            const SizedBox(height: 12),
            FzChoiceCard(
              title: 'Passport',
              subtitle: 'Valid passport from any country',
              icon: Icons.menu_book_outlined,
              selected: _idType == 'passport',
              onTap: () => setState(() => _idType = 'passport'),
            ),
          ],
        );
      case _Q.front:
        return _documentCapture('front', back: false);
      case _Q.back:
        return _documentCapture('back', back: true);
      case _Q.selfie:
        return _selfieCapture();
    }
  }

  Widget _documentCapture(String slot, {required bool back}) {
    final bytes = _photos[slot];
    if (bytes != null) {
      return Column(
        children: [
          FzViewfinder(
            scanning: false,
            height: 260,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover),
                    ),
                  ),
                ),
                Positioned(top: 18, left: 0, right: 0, child: Center(child: _capturedBadge())),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FzPillButton(
            icon: Icons.refresh_rounded,
            label: 'Retake',
            onTap: () => _pickPhoto(slot, ImageSource.camera),
          ),
        ],
      );
    }
    return Column(
      children: [
        FzViewfinder(
          height: 260,
          child: Center(
            child: Container(
              width: 260,
              height: 164,
              decoration: BoxDecoration(
                color: const Color(0x0DFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x40FFFFFF), width: 1.5),
              ),
              child: back
                  ? Column(
                      children: [
                        const SizedBox(height: 20),
                        Container(height: 26, color: const Color(0x14FFFFFF)),
                      ],
                    )
                  : Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.only(left: 16, top: 22),
                        width: 54,
                        height: 68,
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const FzHintChips(['Good lighting', 'No glare', 'All corners visible']),
      ],
    );
  }

  Widget _capturedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x2E2BD48A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Fz.green),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, color: Fz.green, size: 14),
          SizedBox(width: 6),
          Text('Captured', style: TextStyle(color: Fz.green, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _selfieCapture() {
    final bytes = _photos['selfie'];
    final face = ClipOval(
      child: SizedBox.square(
        dimension: 236,
        child: bytes != null
            ? Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover)
            : const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.25),
                    colors: [Color(0xFF2C2C33), Color(0xFF141417)],
                  ),
                ),
                child: Icon(Icons.person_rounded, size: 190, color: Color(0xFF3A3A44)),
              ),
      ),
    );
    return Column(
      children: [
        Center(
          child: FzSpinRing(size: 266, stroke: 5, child: face),
        ),
        const SizedBox(height: 16),
        if (bytes != null) ...[
          _capturedBadge(),
          const SizedBox(height: 12),
          FzPillButton(
            icon: Icons.refresh_rounded,
            label: 'Retake',
            onTap: () => _pickPhoto('selfie', ImageSource.camera),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0x26FF2D2D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Fz.hot),
            ),
            child: Text('POSITION YOUR FACE IN THE FRAME', style: Fz.mono(11.5, color: Fz.hot, spacing: 0.8)),
          ),
          const SizedBox(height: 14),
          const FzHintChips(['Face the camera', 'No hat or glasses', 'Good lighting']),
        ],
      ],
    );
  }

  Widget _submittingView() {
    Widget row(String label, int stage) {
      final done = _submitStage >= stage;
      final running = !done && _submitStage == stage - 1;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Fz.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Fz.line),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 28,
              child: done
                  ? Container(
                      decoration: const BoxDecoration(color: Fz.green, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 18, color: Fz.bg),
                    )
                  : running
                      ? const CircularProgressIndicator(strokeWidth: 3, color: Fz.hot, backgroundColor: Color(0xFF2A2A30))
                      : Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF2A2A30), width: 2),
                          ),
                        ),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: done || running ? Colors.white : const Color(0xFF5C5C64),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Fz.bg,
      body: FzBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 70, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: FzSpinRing(
                    size: 180,
                    stroke: 8,
                    sweep: 0.85,
                    period: const Duration(milliseconds: 1400),
                    child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 52),
                  ),
                ),
                const SizedBox(height: 34),
                Text('Submitting your application', textAlign: TextAlign.center, style: Fz.head(28, spacing: -1)),
                const SizedBox(height: 8),
                const Text(
                  'Your information is being encrypted and submitted securely.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Fz.muted, fontSize: 15),
                ),
                const SizedBox(height: 30),
                row('Personal information', 1),
                const SizedBox(height: 10),
                row('Identity document', 2),
                const SizedBox(height: 10),
                row('Selfie verification', 3),
                const SizedBox(height: 10),
                row('Submitted for review', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
