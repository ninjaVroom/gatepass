import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets.dart';

/// Screen 13: organiser dashboard. Polls every 5 s (no websockets at this scale).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Timer _poll = Timer.periodic(const Duration(seconds: 5), (_) => setState(() {}));

  @override
  void dispose() {
    _poll.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = server.stats();
    final pct = s.expected == 0 ? 0 : (s.checkedIn * 100 / s.expected).round();
    final recentRejects = server.checkins.reversed.where((c) => c.result == Result.reject).take(6).toList();
    return Scaffold(
      appBar: StatusStrip(title: 'Gateway · ${DemoServer.eventName} · Day ${server.eventDay} · ${ddMon(accraNow())}'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Kpi('Checked in', thousands(s.checkedIn), 'of ${thousands(s.expected)} expected · $pct%', C.ink),
                _Kpi('Walk-in day passes', thousands(s.walkins), 'issued today', C.info),
                _Kpi('Rejected scans', thousands(s.rejects), '${s.sentToDesk} sent to desk', C.bad),
                _Kpi(
                  'Offline conflicts',
                  thousands(s.conflicts),
                  s.conflicts == 0 ? 'none to review' : 'to review',
                  C.warn,
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Label('Arrivals per 15 min'),
                          const SizedBox(height: 16),
                          Expanded(child: _Bars(s)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Label('By gate'),
                          const SizedBox(height: 8),
                          Table(
                            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
                            border: const TableBorder(horizontalInside: BorderSide(color: C.line)),
                            children: [
                              _row(['Gate', 'In', 'Rejects'], head: true),
                              for (final e in s.byGate.entries) _row([e.key.name, thousands(e.value.$1), thousands(e.value.$2)]),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Label('Latest rejects'),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView(
                              children: [
                                for (final c in recentRejects)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 56,
                                          child: Text(hhmm(c.at), style: T.body.copyWith(color: C.ink2, fontSize: 15)),
                                        ),
                                        Expanded(
                                          child: Text(
                                            c.pass?.attendee.fullName ?? 'Unknown code',
                                            style: T.body.copyWith(fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${c.gate.name} · ${_reason(c.reason)}',
                                          style: T.body.copyWith(color: C.ink2, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: server.exportCsv()));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('CSV of ${thousands(server.checkins.length)} scans copied to the clipboard.'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Export CSV'),
                          ),
                        ],
                      ),
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

  static String _reason(Reason r) => switch (r) {
    Reason.notRegistered => 'not registered',
    Reason.revoked => 'cancelled',
    Reason.notValidToday => 'not valid today',
    Reason.wrongGate => 'wrong gate',
    Reason.denied => 'denied',
    _ => r.name,
  };

  TableRow _row(List<String> cells, {bool head = false}) => TableRow(
    children: [
      for (final (i, c) in cells.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: head
              ? Align(alignment: i == 0 ? Alignment.centerLeft : Alignment.centerRight, child: Label(c))
              : Text(c, textAlign: i == 0 ? TextAlign.left : TextAlign.right, style: T.body),
        ),
    ],
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.sub, this.color, {this.last = false});
  final String label, value, sub;
  final Color color;
  final bool last;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: EdgeInsets.only(right: last ? 0 : 20),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Label(label),
            const SizedBox(height: 4),
            Text(
              value,
              style: T.h1.copyWith(fontSize: 40, fontWeight: FontWeight.w800, color: color),
            ),
            Text(sub, style: T.body.copyWith(color: C.ink2, fontSize: 15)),
          ],
        ),
      ),
    ),
  );
}

class _Bars extends StatelessWidget {
  const _Bars(this.s);
  final Stats s;
  @override
  Widget build(BuildContext context) {
    final peak = s.arrivals.fold(1, (a, b) => b > a ? b : a);
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, n) in s.arrivals.indexed)
                Expanded(
                  child: Tooltip(
                    message: '${hhmm(s.firstBucket.add(Duration(minutes: 15 * i)))} · $n arrivals',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FractionallySizedBox(
                        heightFactor: (n / peak).clamp(0.01, 1.0),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: C.brand.withValues(alpha: .85),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (i, _) in s.arrivals.indexed)
              Expanded(
                child: Text(
                  i % 4 == 0 ? hhmm(s.firstBucket.add(Duration(minutes: 15 * i))) : '',
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: T.body.copyWith(color: C.ink2, fontSize: 13),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
