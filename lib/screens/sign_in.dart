import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets.dart';

/// Screen 1: event code → gate → 4-digit PIN → attendee pack download.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> with SingleTickerProviderStateMixin {
  final _code = TextEditingController(text: DemoServer.eventCode);
  Gate _gate = gates.first;
  String _pin = '';
  String? _error;
  late final _download = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void dispose() {
    _download.dispose();
    _code.dispose();
    super.dispose();
  }

  void _digit(String n) {
    if (_pin.length >= 4 || _download.isAnimating) return;
    setState(() {
      _pin += n;
      _error = null;
    });
    if (_pin.length == 4) _submit();
  }

  Future<void> _submit() async {
    try {
      final staff = server.signIn(_code.text, _pin);
      device.signIn(staff, _gate);
      await _download.forward(from: 0);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(switch (staff.role) {
        Role.gate => '/gate',
        Role.desk => '/desk',
        Role.organiser => '/dashboard',
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _form()),
                  const SizedBox(width: 48),
                  SizedBox(width: 340, child: _pinPad()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'GATEWAY',
        style: T.label.copyWith(color: C.brand, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      ),
      const SizedBox(height: 10),
      Text('Sign in to the gate', style: T.h1),
      const SizedBox(height: 4),
      Text('${DemoServer.eventName} · Accra', style: T.body.copyWith(color: C.ink2)),
      const SizedBox(height: 28),
      const Label('Event code'),
      const SizedBox(height: 8),
      TextField(
        controller: _code,
        textCapitalization: TextCapitalization.characters,
        maxLength: 6,
        style: T.body.copyWith(fontSize: 20),
        decoration: const InputDecoration(counterText: ''),
      ),
      const SizedBox(height: 20),
      const Label('Gate'),
      const SizedBox(height: 8),
      Segmented<Gate>(options: gates, value: _gate, onChanged: (g) => setState(() => _gate = g), label: (g) => g.name),
      const SizedBox(height: 20),
      AnimatedBuilder(
        animation: _download,
        builder: (_, _) => _download.value == 0
            ? Text(
                'Demo PINs: 1234 gate · 2580 accreditation desk · 9999 organiser',
                style: T.body.copyWith(color: C.ink2, fontSize: 14),
              )
            : Panel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Downloading attendee pack', style: T.body.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                        const Spacer(),
                        Text(thousands((device.pack.length * _download.value).round()), style: T.body.copyWith(fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(R.chip),
                      child: LinearProgressIndicator(
                        value: _download.value,
                        minHeight: 8,
                        color: C.brand,
                        backgroundColor: C.line,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    ],
  );

  Widget _pinPad() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Label('Staff PIN'),
      const SizedBox(height: 14),
      Semantics(
        label: '${_pin.length} of 4 digits entered',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 18,
                height: 18,
                decoration: BoxDecoration(shape: BoxShape.circle, color: i < _pin.length ? C.brand : C.line),
              ),
          ],
        ),
      ),
      SizedBox(
        height: 28,
        child: Center(
          child: Text(_error ?? '', style: T.body.copyWith(color: C.bad, fontSize: 14)),
        ),
      ),
      Keypad(
        keyHeight: 72,
        onDigit: _digit,
        onBack: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
        left: 'Clear',
        onLeft: () => setState(() => _pin = ''),
      ),
    ],
  );
}
