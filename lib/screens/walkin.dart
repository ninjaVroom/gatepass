import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets.dart';

/// Screens 9–11 / Flow C: government ID → details → same-day pass.
class WalkinScreen extends StatefulWidget {
  const WalkinScreen({super.key});
  @override
  State<WalkinScreen> createState() => _WalkinScreenState();
}

class _WalkinScreenState extends State<WalkinScreen> {
  int _step = 0;
  IdType _idType = IdType.ghanaCard;
  final _id = TextEditingController();
  bool _sighted = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _org = TextEditingController();
  Category _cat = Category.delegate;
  Pass? _issued;
  bool _wasExisting = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_id, _name, _phone, _org]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_id, _name, _phone, _org]) {
      c.dispose();
    }
    super.dispose();
  }

  void _reset() => setState(() {
    _step = 0;
    _id.clear();
    _name.clear();
    _phone.clear();
    _org.clear();
    _sighted = false;
    _tried = false;
    _cat = Category.delegate;
    _issued = null;
  });

  bool get _idValid => _idType.valid(_id.text);
  Pass? get _today => _idValid ? server.walkinToday(_idType, _id.text) : null;
  Pass? get _earlier => _idValid ? server.walkinEarlier(_idType, _id.text) : null;

  void _continue() {
    final existing = _today;
    if (existing != null) {
      setState(() {
        _issued = existing;
        _wasExisting = true;
        _step = 2;
      });
      return;
    }
    final prev = _earlier;
    if (prev != null && _name.text.isEmpty) {
      // Day 2 re-issue: details come from yesterday's pass, one tap to issue.
      final a = prev.attendee;
      _name.text = a.fullName;
      _phone.text = a.phone.replaceFirst('+233', '');
      _org.text = a.org;
      _cat = a.category;
    }
    setState(() => _step = 1);
  }

  void _issue() {
    setState(() => _tried = true);
    final phone = normaliseGhPhone(_phone.text);
    if (_name.text.trim().isEmpty || phone == null || _org.text.trim().isEmpty) return;
    if (!device.online) {
      // Issuing needs the server for dedupe and SMS. Don't fake it.
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desk offline'),
          content: const Text(
            'Passes can only be issued online. Use the paper log and add this person when the connection is back.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    final (pass, existing) = server.issueWalkin(
      idType: _idType,
      idNumber: _id.text,
      fullName: _name.text,
      phone: phone,
      org: _org.text,
      category: _cat,
      by: device.staff!,
    );
    setState(() {
      _issued = pass;
      _wasExisting = existing;
      _step = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StatusStrip(),
      body: SafeArea(
        top: false,
        child: _step == 2
            ? _PassIssued(pass: _issued!, existing: _wasExisting, onNext: _reset)
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _Steps(_step),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).pushNamed('/gate'),
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Open scanner'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Expanded(child: SingleChildScrollView(child: _step == 0 ? _idStep() : _detailsStep())),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 200,
                              child: OutlinedButton(
                                onPressed: _step == 0 ? _reset : () => setState(() => _step = 0),
                                child: Text(_step == 0 ? 'Cancel' : '← Back'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 260,
                              child: _step == 0
                                  ? FilledButton(
                                      onPressed: _idValid && _sighted ? _continue : null,
                                      child: const Text('Continue →'),
                                    )
                                  : FilledButton(onPressed: _issue, child: const Text('Issue day pass')),
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

  Widget _idStep() {
    final txt = _id.text.trim();
    final today = _today, earlier = _earlier;
    final (hint, color) = txt.isEmpty
        ? ('Format: ${_idType.hint}', C.ink2)
        : !_idValid
        ? ('Not a valid ${_idType.label} format · expected ${_idType.hint}', C.bad)
        : today != null
        ? ('Valid format · already has a pass today. Continue shows it', C.warnInk)
        : earlier != null
        ? ('Valid format · had a day pass on ${ddMon(earlier.validFrom)}. Details will be pre-filled', C.okSurface)
        : ('Valid ${_idType.label} format · not used for a pass today', C.okSurface);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Government ID', style: T.h1),
        const SizedBox(height: 22),
        const Label('ID type'),
        const SizedBox(height: 8),
        Segmented<IdType>(
          options: IdType.values,
          value: _idType,
          onChanged: (t) => setState(() => _idType = t),
          label: (t) => t.label,
        ),
        const SizedBox(height: 22),
        const Label('ID number'),
        const SizedBox(height: 8),
        TextField(
          controller: _id,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: T.body.copyWith(fontSize: 20, letterSpacing: 1.5),
          decoration: InputDecoration(hintText: _idType == IdType.ghanaCard ? 'GHA-000000000-0' : null),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(hint, style: T.body.copyWith(color: color, fontSize: 14)),
        ),
        const SizedBox(height: 22),
        Material(
          color: C.okTint.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(R.control),
          child: CheckboxListTile(
            value: _sighted,
            onChanged: (v) => setState(() => _sighted = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: C.brand,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.control)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            title: Text('I have seen the ID and the photo matches the person in front of me', style: T.body),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We keep only the ID type, the last 4 characters and a one-way hash. No image, no full number.',
          style: T.body.copyWith(color: C.ink2, fontSize: 14),
        ),
      ],
    );
  }

  Widget _detailsStep() {
    String? req(TextEditingController c, String msg) => _tried && c.text.trim().isEmpty ? msg : null;
    final phoneErr = _tried && normaliseGhPhone(_phone.text) == null ? 'Enter a Ghana mobile number, e.g. 20 555 0142' : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Attendee details', style: T.h1),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Label('Full name (as on ID)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    style: T.body,
                    decoration: InputDecoration(errorText: req(_name, 'Required')),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Label('Phone'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    style: T.body,
                    decoration: InputDecoration(
                      errorText: phoneErr,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 18, right: 10),
                        child: Text('+233', style: T.body.copyWith(color: C.ink2)),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Label('Organisation'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _org,
                    textCapitalization: TextCapitalization.words,
                    style: T.body,
                    decoration: InputDecoration(errorText: req(_org, 'Required')),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Label('Category'),
                  const SizedBox(height: 8),
                  Segmented<Category>(
                    options: const [Category.delegate, Category.media, Category.exhibitor, Category.guest],
                    value: _cat,
                    onChanged: (c) => setState(() => _cat = c),
                    label: (c) => c.label,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            style: T.body.copyWith(color: C.ink2, fontSize: 14),
            children: const [
              TextSpan(text: 'Pass is valid '),
              TextSpan(
                text: 'today only',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: ' (until 23:59) at Main A and Main B. ID is stored as a hash and last 4 characters.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps(this.step);
  final int step;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, s) in ['1 · ID', '2 · Details', '3 · Pass'].indexed)
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: i == step ? C.brand : C.segTrack, borderRadius: BorderRadius.circular(R.chip)),
            child: Text(
              i < step ? '$s ✓' : s,
              style: T.body.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: i == step ? C.brandInk : C.ink2),
            ),
          ),
        ),
    ],
  );
}

class _PassIssued extends StatelessWidget {
  const _PassIssued({required this.pass, required this.existing, required this.onNext});
  final Pass pass;
  final bool existing;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final a = pass.attendee;
    Widget line(IconData icon, InlineSpan text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: C.ink2),
          const SizedBox(width: 10),
          Expanded(child: Text.rich(text, style: T.body)),
        ],
      ),
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.card), boxShadow: cardShadow),
                  child: Semantics(
                    label: 'Day pass QR code for ${a.fullName}',
                    child: QrImageView(
                      data: pass.token,
                      size: 320,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: C.ink),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: C.ink),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 48),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Pill('Day pass', bg: C.surface, fg: C.info, outline: C.info),
                      if (existing) ...[const SizedBox(width: 8), const Pill('Existing pass', bg: C.warnTint, fg: C.warnInk)],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(a.fullName, style: T.h1),
                  const SizedBox(height: 4),
                  Text('${a.org} · ${a.category.label}', style: T.body.copyWith(color: C.ink2, fontSize: 19)),
                  const SizedBox(height: 18),
                  Panel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        line(
                          Icons.schedule_rounded,
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Valid '),
                              TextSpan(
                                text: 'today, ${ddMon(pass.validFrom)}, until 23:59',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        line(
                          Icons.sms_outlined,
                          TextSpan(
                            children: [
                              TextSpan(text: 'SMS sent to ${maskPhone(a.phone)} · '),
                              const TextSpan(
                                text: 'sandbox',
                                style: TextStyle(color: C.okSurface, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        line(
                          Icons.badge_outlined,
                          TextSpan(text: '${a.idType?.label} ••••${a.idLast4} · issued by ${pass.issuedBy?.name ?? 'desk'}'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ask the guest to take a photo of this code or use the SMS link.',
                    style: T.body.copyWith(color: C.ink2, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(content: Text('No slip printer connected to this device.'))),
                          child: const Text('Print slip'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(onPressed: onNext, child: const Text('Next walk-in')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
