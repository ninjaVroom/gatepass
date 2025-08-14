import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets.dart';
import 'gate.dart';

/// Screen 8 / Flow B: keypad left with fixed +233, masked matches right.
class PhoneLookupScreen extends StatefulWidget {
  const PhoneLookupScreen({super.key});
  @override
  State<PhoneLookupScreen> createState() => _PhoneLookupScreenState();
}

class _PhoneLookupScreenState extends State<PhoneLookupScreen> {
  String _digits = '';
  Pass? _picked;

  String? get _e164 => normaliseGhPhone(_digits);
  List<Pass> get _matches => _e164 == null ? const [] : server.lookupPhone(_e164!);

  void _digit(String n) {
    // Accept 0XX… (10 digits) or the bare 9.
    if (_digits.length >= (_digits.startsWith('0') ? 10 : 9)) return;
    setState(() {
      _digits += n;
      _picked = null;
    });
  }

  String get _display {
    final d = _digits.startsWith('0') ? _digits.substring(1) : _digits;
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 5) b.write(' ');
      b.write(d[i]);
    }
    return b.toString();
  }

  Future<void> _confirm(Pass p) async {
    final o = device.scan(p.token); // same rules as a QR scan
    final nav = Navigator.of(context);
    await showResult(context, o);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final picked = matches.length == 1 ? matches.first : _picked;
    return Scaffold(
      appBar: const StatusStrip(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Label('Registered phone number'),
                  const SizedBox(height: 8),
                  Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: C.surface,
                      borderRadius: BorderRadius.circular(R.control),
                      border: Border.all(color: C.ink, width: 2),
                    ),
                    child: Row(
                      children: [
                        Text('+233', style: T.body.copyWith(color: C.ink2, fontSize: 18)),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            label: 'Phone number',
                            child: Text(
                              _display.isEmpty ? '' : _display,
                              style: T.h1.copyWith(fontSize: 30, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) => Keypad(
                        keyHeight: ((c.maxHeight - 48) / 4).clamp(56, 80),
                        onDigit: _digit,
                        onBack: () => setState(() {
                          _digits = _digits.isEmpty ? '' : _digits.substring(0, _digits.length - 1);
                          _picked = null;
                        }),
                        left: 'Back',
                        onLeft: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Label(
                      _e164 == null
                          ? 'Enter the number they registered with'
                          : matches.isEmpty
                          ? 'No registration for this number'
                          : '${matches.length} registration${matches.length == 1 ? '' : 's'} on this number',
                    ),
                    const SizedBox(height: 12),
                    if (_e164 != null && matches.isEmpty)
                      Text(
                        'Please send them to the Accreditation desk, lobby, left of the main doors.',
                        style: T.body.copyWith(color: C.ink2),
                      ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final p in matches) _MatchCard(p, selected: p == picked, onTap: () => setState(() => _picked = p)),
                        ],
                      ),
                    ),
                    if (picked != null) ...[
                      FilledButton(onPressed: () => _confirm(picked), child: Text('Check in ${picked.attendee.shortName}')),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to scanner')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard(this.p, {required this.selected, required this.onTap});
  final Pass p;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = p.attendee;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? C.okTint : C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.control),
          side: BorderSide(color: selected ? C.brand : C.line, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(R.control),
          onTap: onTap,
          child: Semantics(
            selected: selected,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Avatar(a.initials),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.shortName, style: T.body.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          '${a.org} · ${maskPhone(a.phone)}',
                          style: T.body.copyWith(color: C.ink2, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  categoryChip(a.category),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
