import 'package:flutter_test/flutter_test.dart';
import 'package:gatepass/data.dart';

void main() {
  final now = DateTime.utc(2023, 6, 19, 9);
  Pass pass({List<String> zones = const ['main'], bool revoked = false, int dayOffset = 0, PassKind kind = PassKind.day}) {
    final d = DateTime.utc(2023, 6, 19 + dayOffset);
    return Pass(
      token: 't',
      attendee: Attendee(fullName: 'Kofi Boateng', org: 'X', phone: '+233205550142', category: Category.guest),
      kind: kind,
      zones: zones,
      validFrom: d,
      validTo: d.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      revoked: revoked,
    );
  }

  final mainA = gates.first;

  test('check-in rules, in spec order', () {
    expect(evaluate(pass: null, gate: mainA, now: now, priorOk: null).reason, Reason.notRegistered);
    expect(evaluate(pass: pass(revoked: true), gate: mainA, now: now, priorOk: null).reason, Reason.revoked);
    expect(evaluate(pass: pass(dayOffset: -1), gate: mainA, now: now, priorOk: null).reason, Reason.notValidToday);
    expect(
      evaluate(
        pass: pass(zones: ['media']),
        gate: mainA,
        now: now,
        priorOk: null,
      ).reason,
      Reason.wrongGate,
    );
    final p = pass();
    final prior = Checkin(rawToken: 't', pass: p, gate: gates[1], staffId: 's', result: Result.ok, reason: Reason.ok, at: now);
    final warn = evaluate(pass: p, gate: mainA, now: now, priorOk: prior);
    expect((warn.result, warn.previous?.gate.name), (Result.warn, 'Main B'));
    expect(evaluate(pass: p, gate: mainA, now: now, priorOk: null).result, Result.ok);
  });

  test('offline clock tolerance is ±10 min', () {
    final justAfterMidnight = DateTime.utc(2023, 6, 20, 0, 5);
    expect(evaluate(pass: pass(), gate: mainA, now: justAfterMidnight, priorOk: null).reason, Reason.notValidToday);
    expect(
      evaluate(pass: pass(), gate: mainA, now: justAfterMidnight, priorOk: null, tolerance: const Duration(minutes: 10)).result,
      Result.ok,
    );
  });

  test('phone normalising and masking', () {
    for (final s in ['0244635555', '244635555', '+233 24 463 5555', '233244635555']) {
      expect(normaliseGhPhone(s), '+233244635555');
    }
    expect(normaliseGhPhone('02446355'), isNull);
    expect(maskPhone('+233244635555'), '024•••5555');
  });

  test('ID formats, hash and last 4', () {
    expect(IdType.ghanaCard.valid('GHA-714209386-2'), isTrue);
    expect(IdType.ghanaCard.valid('GHA-71420938-2'), isFalse);
    expect(idLast4('GHA-714209386-2'), '3862');
    expect(idHash(IdType.ghanaCard, 'gha-714209386-2'), idHash(IdType.ghanaCard, 'GHA 714209386 2'));
  });

  test('one walk-in pass per ID per day; flush flags cross-gate conflicts', () {
    final server = DemoServer();
    final staff = DemoServer.staff['2580']!;
    Pass issue() => server
        .issueWalkin(
          idType: IdType.passport,
          idNumber: 'G1234567',
          fullName: 'A B',
          phone: '+233205550142',
          org: 'O',
          category: Category.guest,
          by: staff,
        )
        .$1;
    expect(identical(issue(), issue()), isTrue);

    final d = Device(server)..signIn(DemoServer.staff['1234']!, gates.first);
    final t = server.demoTokens['Ama Mensah · registered']!;
    d.setOnline(false);
    expect(d.scan(t).result, Result.ok);
    server.checkin(t, gates[1], 'other'); // another gate let her in meanwhile
    d.setOnline(true);
    expect(server.conflicts, 1);
    expect(d.queue, isEmpty);
    d.signOut();
  });
}
