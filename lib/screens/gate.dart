import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets.dart';

/// Screens 2 and 12: viewfinder left (60%), status panel right (40%), offline banner.
class GateScreen extends StatefulWidget {
  const GateScreen({super.key});
  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  bool _busy = false;
  String? _lastToken;
  DateTime _lastAt = DateTime(0);

  Future<void> _handle(String token) async {
    // The camera never stops; ignore frames while a result is up or the same code is still in view.
    if (_busy || (token == _lastToken && DateTime.now().difference(_lastAt) < const Duration(seconds: 3))) return;
    _busy = true;
    _lastToken = token;
    final o = device.scan(token.trim());
    await showResult(context, o);
    _lastAt = DateTime.now();
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StatusStrip(),
      body: ListenableBuilder(
        listenable: device,
        builder: (context, _) => Column(
          children: [
            if (!device.online) _OfflineBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 6, child: Viewfinder(onCode: _handle)),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _SidePanel(onDemoScan: _handle)),
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

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: C.warnTint,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        const Icon(Icons.wifi_off_rounded, color: C.warnInk, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Offline. Checking against attendee pack synced ${device.lastSync == null ? '—' : hhmm(device.lastSync!)} · '
            '${device.queue.length} ${device.queue.length == 1 ? 'scan' : 'scans'} queued, will send when back online',
            style: T.body.copyWith(color: C.warnInk, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      ],
    ),
  );
}

class Viewfinder extends StatefulWidget {
  const Viewfinder({super.key, required this.onCode});
  final ValueChanged<String> onCode;
  @override
  State<Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<Viewfinder> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode], facing: CameraFacing.front);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(R.card),
      child: ColoredBox(
        color: C.camera,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final v = capture.barcodes.firstOrNull?.rawValue;
                if (v != null && v.isNotEmpty) widget.onCode(v);
              },
              errorBuilder: (_, _) => const ColoredBox(color: C.camera),
            ),
            Center(
              child: CustomPaint(size: const Size.square(260), painter: _Brackets()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Text(
                'Hold your QR code inside the frame',
                textAlign: TextAlign.center,
                style: T.body.copyWith(color: C.brandInk, fontSize: 19, fontWeight: FontWeight.w500),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                tooltip: 'Switch camera',
                onPressed: _controller.switchCamera,
                icon: const Icon(Icons.cameraswitch_outlined, color: C.brandInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brackets extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = C.brandInk
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 42.0, r = 10.0;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (s.width, 0.0, -1.0, 1.0),
      (0.0, s.height, 1.0, -1.0),
      (s.width, s.height, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * l)
          ..lineTo(x, y + dy * r)
          ..quadraticBezierTo(x, y, x + dx * r, y)
          ..lineTo(x + dx * l, y),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.onDemoScan});
  final ValueChanged<String> onDemoScan;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final expected = d.expected;
    final ratio = expected == 0 ? 0.0 : (d.checkedIn / expected).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Label(d.online ? 'Checked in' : 'Checked in (incl. queued)'),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(thousands(d.checkedIn), style: T.h1.copyWith(fontSize: 42, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Text('/ ${thousands(expected)} expected', style: T.body.copyWith(color: C.ink2, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(R.chip),
                child: LinearProgressIndicator(value: ratio, minHeight: 8, color: C.brand, backgroundColor: C.line),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/phone'),
          icon: const Icon(Icons.phone_rounded),
          label: const Text('Use phone number'),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(d.online ? 'Recent' : 'Recent (queued scans marked)'),
                const SizedBox(height: 8),
                if (d.recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('No scans on this device yet.', style: T.body.copyWith(color: C.ink2)),
                  ),
                Expanded(
                  child: ListView(padding: EdgeInsets.zero, children: [for (final c in d.recent) _RecentRow(c)]),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.lastSync == null ? 'Not synced' : 'Synced ${hhmm(d.lastSync!)} · ${thousands(d.pack.length)} passes',
                        style: T.body.copyWith(color: C.ink2, fontSize: 14),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _demoSheet(context),
                      child: Text(
                        'Demo scan',
                        style: T.body.copyWith(color: C.info, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _demoSheet(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Simulate a scan', style: T.h2),
        children: [
          for (final e in server.demoTokens.entries)
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              onPressed: () => Navigator.pop(ctx, e.value),
              child: Text(e.key, style: T.body),
            ),
        ],
      ),
    ).then((t) {
      if (t != null) onDemoScan(t);
    });
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow(this.c);
  final Checkin c;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(hhmm(c.at), style: T.body.copyWith(color: C.ink2)),
        ),
        Avatar(c.pass?.attendee.initials ?? '?'),
        const SizedBox(width: 12),
        Expanded(
          child: Text(c.pass?.attendee.fullName ?? 'Unknown code', style: T.body, overflow: TextOverflow.ellipsis),
        ),
        if (c.offline && device.queue.contains(c))
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text('queued', style: T.body.copyWith(color: C.warnInk, fontSize: 13)),
          ),
        resultDot(c.result),
      ],
    ),
  );
}

// ---------------- Result screens (3–7) ----------------

Future<void> showResult(BuildContext context, Outcome o) {
  if (!device.muted) {
    o.result == Result.ok ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
  }
  final reduce = reduceMotion(context);
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 150),
      reverseTransitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => ResultScreen(o),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: .98, end: 1.0).animate(a), child: child),
      ),
    ),
  );
}

class ResultScreen extends StatefulWidget {
  const ResultScreen(this.o, {super.key});
  final Outcome o;
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    // Warn waits for staff; accept 2.5 s; reject 5 s.
    if (widget.o.result != Result.warn) {
      _auto = Timer(Duration(milliseconds: widget.o.result == Result.ok ? 2500 : 5000), _close);
    }
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  void _close() {
    _auto?.cancel();
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final a = o.pass?.attendee;
    final (bg, icon, word) = switch (o.reason) {
      Reason.ok || Reason.reentry => (C.okSurface, Icons.check_rounded, 'WELCOME'),
      Reason.alreadyIn => (C.warnSurface, Icons.priority_high_rounded, 'ALREADY CHECKED IN'),
      Reason.notRegistered => (C.badSurface, Icons.close_rounded, 'NOT REGISTERED'),
      Reason.revoked => (C.badSurface, Icons.close_rounded, 'PASS CANCELLED'),
      Reason.notValidToday => (C.badSurface, Icons.close_rounded, 'PASS NOT VALID TODAY'),
      Reason.wrongGate => (C.badSurface, Icons.close_rounded, 'WRONG ENTRANCE'),
      Reason.denied => (C.badSurface, Icons.close_rounded, 'ENTRY DENIED'),
    };
    final ink = T.body.copyWith(color: C.brandInk);

    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: o.result == Result.warn ? null : _close,
        child: SafeArea(
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(color: C.brandInk.withValues(alpha: .2), borderRadius: BorderRadius.circular(24)),
                      child: Icon(icon, color: C.brandInk, size: 64),
                    ),
                    const SizedBox(height: 28),
                    Text(word, textAlign: TextAlign.center, style: T.display),
                    if (a != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        a.fullName,
                        textAlign: TextAlign.center,
                        style: T.h1.copyWith(color: C.brandInk),
                      ),
                      const SizedBox(height: 6),
                      Text(a.org, textAlign: TextAlign.center, style: ink.copyWith(fontSize: 19)),
                    ],
                    if (o.result == Result.ok && a != null) ...[
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          categoryChip(a.category, onDark: true),
                          if (o.pass!.kind == PassKind.day)
                            Pill('Day pass · ${ddMon(o.pass!.validFrom)}', bg: C.surface, fg: C.info, outline: C.info),
                          if (o.reason == Reason.reentry) const Pill('Re-entry', bg: C.surface, fg: C.okSurface),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    ..._detail(o, ink),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _note(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(color: C.ink.withValues(alpha: .18), borderRadius: BorderRadius.circular(R.control)),
    child: child,
  );

  List<Widget> _detail(Outcome o, TextStyle ink) {
    final bold = ink.copyWith(fontWeight: FontWeight.w700);
    final desk = Text.rich(
      TextSpan(
        style: ink,
        children: [
          const TextSpan(text: 'Please go to the '),
          TextSpan(text: 'Accreditation desk', style: bold),
          const TextSpan(text: ', lobby, left of the main doors'),
        ],
      ),
    );
    final actions = SizedBox(
      width: 520,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: C.brandInk.withValues(alpha: .15),
                foregroundColor: C.brandInk,
                side: const BorderSide(color: C.brandInk, width: 2),
              ),
              onPressed: () {
                _close();
                Navigator.of(context).pushNamed('/phone');
              },
              child: const Text('Try phone number'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton(onPressed: _close, child: const Text('Done')),
          ),
        ],
      ),
    );

    switch (o.reason) {
      case Reason.notRegistered:
        return [
          Text("We couldn't find this code.", style: ink),
          const SizedBox(height: 16),
          _note(desk),
          const SizedBox(height: 24),
          actions,
        ];
      case Reason.revoked:
        return [Text('This pass has been cancelled.', style: ink), const SizedBox(height: 16), _note(desk)];
      case Reason.notValidToday:
        return [
          Text('Day pass for ${ddMon(o.pass!.validFrom)} · today is ${ddMon(accraNow())}', style: ink),
          const SizedBox(height: 16),
          _note(
            Text.rich(
              TextSpan(
                style: ink,
                children: [
                  const TextSpan(text: 'Re-issue in one tap at the '),
                  TextSpan(text: 'Accreditation desk', style: bold),
                ],
              ),
            ),
          ),
        ];
      case Reason.wrongGate:
        final g = gateForZone(o.pass!.zones.first);
        return [
          _note(
            Text.rich(
              TextSpan(
                style: ink,
                children: [
                  const TextSpan(text: 'Please use the '),
                  TextSpan(text: '${g.name} entrance', style: bold),
                ],
              ),
            ),
          ),
        ];
      case Reason.alreadyIn:
        final p = o.previous!;
        return [
          _note(Text('First scan ${hhmm(p.at)} at Gate ${p.gate.name}', style: ink.copyWith(fontSize: 18))),
          const SizedBox(height: 24),
          SizedBox(
            width: 520,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      device.resolveWarn(o.pass!, allow: true);
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (_, _, _) => ResultScreen(Outcome(Result.ok, Reason.reentry, o.pass)),
                          transitionDuration: Duration.zero,
                        ),
                      );
                    },
                    child: const Text('Allow re-entry'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: C.brandInk.withValues(alpha: .15),
                      foregroundColor: C.brandInk,
                      side: const BorderSide(color: C.brandInk, width: 2),
                    ),
                    onPressed: () {
                      device.resolveWarn(o.pass!, allow: false);
                      _close();
                    },
                    child: const Text('Deny'),
                  ),
                ),
              ],
            ),
          ),
        ];
      default:
        return const [];
    }
  }
}
