import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

// the "server" runs in-process with seeded demo data so the app is fully
// demo-able without a backend. Swap DemoServer for an HTTP client against the
// Laravel API in research/04-architecture.md; Device's online/offline logic stays.

enum Category { delegate, media, exhibitor, vip, guest }

extension CategoryLabel on Category {
  String get label => switch (this) {
    Category.delegate => 'Delegate',
    Category.media => 'Media',
    Category.exhibitor => 'Exhibitor',
    Category.vip => 'VIP',
    Category.guest => 'Guest',
  };
}

enum PassKind { full, day }

enum Result { ok, warn, reject }

enum Reason { ok, reentry, alreadyIn, notRegistered, revoked, notValidToday, wrongGate, denied }

enum Role { gate, desk, organiser }

enum IdType {
  ghanaCard('Ghana Card', r'^GHA-\d{9}-\d$', 'GHA-#########-#'),
  passport('Passport', r'^[A-Z][A-Z0-9]{6,8}$', 'Letter + 6–8 letters or digits'),
  ecowas('ECOWAS ID', r'^[A-Z0-9]{8,15}$', '8–15 letters or digits'),
  licence("Driver's licence", r'^[A-Z0-9-]{6,15}$', '6–15 letters, digits or dashes');

  const IdType(this.label, this.pattern, this.hint);
  final String label, pattern, hint;
  bool valid(String raw) => RegExp(pattern).hasMatch(raw.trim().toUpperCase());
}

class Gate {
  const Gate(this.id, this.name, this.zone);
  final String id, name, zone;
}

const gates = [
  Gate('a', 'Main A', 'main'),
  Gate('b', 'Main B', 'main'),
  Gate('vip', 'VIP', 'vip'),
  Gate('media', 'Media', 'media'),
];
Gate gateForZone(String zone) => gates.firstWhere((g) => g.zone == zone, orElse: () => gates.first);

class Staff {
  const Staff(this.id, this.name, this.role);
  final String id, name;
  final Role role;
}

class Attendee {
  Attendee({
    required this.fullName,
    required this.org,
    required this.phone,
    required this.category,
    this.walkin = false,
    this.idType,
    this.idLast4,
    this.idHash,
  });
  final String fullName, org, phone;
  final Category category;
  final bool walkin;
  final IdType? idType;
  final String? idLast4, idHash;

  String get initials => fullName.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();

  /// First name + last initial, for anything visible to the queue.
  String get shortName {
    final p = fullName.split(' ');
    return p.length < 2 ? fullName : '${p.first} ${p.last[0]}.';
  }
}

class Pass {
  Pass({
    required this.token,
    required this.attendee,
    required this.kind,
    required this.zones,
    required this.validFrom,
    required this.validTo,
    this.revoked = false,
    this.issuedBy,
  });
  final String token;
  final Attendee attendee;
  final PassKind kind;
  final List<String> zones;
  final DateTime validFrom, validTo;
  final bool revoked;
  final Staff? issuedBy;
}

class Checkin {
  Checkin({
    required this.rawToken,
    required this.pass,
    required this.gate,
    required this.staffId,
    required this.result,
    required this.reason,
    required this.at,
    this.offline = false,
  });
  final String rawToken;
  final Pass? pass;
  final Gate gate;
  final String staffId;
  final Result result;
  final Reason reason;
  final DateTime at;
  final bool offline;
}

class Outcome {
  const Outcome(this.result, this.reason, this.pass, [this.previous]);
  final Result result;
  final Reason reason;
  final Pass? pass;
  final Checkin? previous;
}

// ---------- pure helpers (covered by test/rules_test.dart) ----------

/// Africa/Accra is UTC+0 with no DST, so UTC is local event time.
DateTime accraNow() => DateTime.now().toUtc();
DateTime dayStart(DateTime t) => DateTime.utc(t.year, t.month, t.day);
bool sameDay(DateTime a, DateTime b) => dayStart(a) == dayStart(b);

/// The check-in rules from 02-product-spec.md, in order. Shared by server and offline device.
Outcome evaluate({
  required Pass? pass,
  required Gate gate,
  required DateTime now,
  required Checkin? priorOk,
  Duration tolerance = Duration.zero,
}) {
  if (pass == null) return const Outcome(Result.reject, Reason.notRegistered, null);
  if (pass.revoked) return Outcome(Result.reject, Reason.revoked, pass);
  if (now.isBefore(pass.validFrom.subtract(tolerance)) || now.isAfter(pass.validTo.add(tolerance))) {
    return Outcome(Result.reject, Reason.notValidToday, pass);
  }
  if (!pass.zones.contains(gate.zone)) return Outcome(Result.reject, Reason.wrongGate, pass);
  if (priorOk != null) return Outcome(Result.warn, Reason.alreadyIn, pass, priorOk);
  return Outcome(Result.ok, Reason.ok, pass);
}

/// Accepts 0XX…, 233XX…, +233XX… or the bare 9 digits. Returns E.164 or null.
String? normaliseGhPhone(String input) {
  var d = input.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('233')) d = d.substring(3);
  if (d.startsWith('0')) d = d.substring(1);
  return d.length == 9 ? '+233$d' : null;
}

/// +233244635555 → 024•••5555
String maskPhone(String e164) {
  final local = e164.replaceFirst('+233', '');
  return '0${local.substring(0, 2)}•••${local.substring(local.length - 4)}';
}

String normaliseId(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
String idLast4(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final src = digits.length >= 4 ? digits : normaliseId(raw);
  return src.substring(max(0, src.length - 4));
}

// demo salt in code; the real one lives in server .env, never on the device.
const _eventSalt = 'gatepass-demo-salt';
String idHash(IdType type, String raw) => sha256.convert(utf8.encode('$_eventSalt|${type.name}|${normaliseId(raw)}')).toString();

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String ddMon(DateTime t) => '${t.day} ${_months[t.month - 1]}';
String thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

const _b62 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
String newToken(Random r) => 'GP1.${List.generate(22, (_) => _b62[r.nextInt(62)]).join()}';

// ---------- demo server ----------

class Stats {
  Stats({
    required this.checkedIn,
    required this.expected,
    required this.walkins,
    required this.rejects,
    required this.sentToDesk,
    required this.conflicts,
    required this.arrivals,
    required this.firstBucket,
    required this.byGate,
  });
  final int checkedIn, expected, walkins, rejects, sentToDesk, conflicts;
  final List<int> arrivals; // per 15 min
  final DateTime firstBucket;
  final Map<Gate, (int, int)> byGate; // in, rejects
}

class DemoServer {
  DemoServer() {
    _seed();
  }

  static const eventCode = 'TS23AC';
  static const eventName = 'Trade Summit 2023';
  static const staff = {
    '1234': Staff('s1', 'Kojo', Role.gate),
    '2580': Staff('s2', 'Esi (desk 2)', Role.desk),
    '9999': Staff('s3', 'Organiser', Role.organiser),
  };

  late final DateTime eventStart = dayStart(accraNow()).subtract(const Duration(days: 1));
  late final DateTime eventEnd = eventStart.add(const Duration(days: 4)).subtract(const Duration(seconds: 1));
  int get eventDay => dayStart(accraNow()).difference(eventStart).inDays + 1;

  final passes = <String, Pass>{};
  final checkins = <Checkin>[];
  int conflicts = 0;
  int _failedPins = 0;
  DateTime? _lockedUntil;
  final _rng = Random.secure();

  /// Demo tokens a presenter can "scan" without a printed QR.
  final demoTokens = <String, String>{};

  // ----- auth -----
  /// Returns staff, or throws a message the UI can show.
  Staff signIn(String code, String pin) {
    final now = DateTime.now();
    if (_lockedUntil != null && now.isBefore(_lockedUntil!)) {
      throw 'Too many tries. Wait ${_lockedUntil!.difference(now).inSeconds + 1} s.';
    }
    if (code.trim().toUpperCase() != eventCode) throw 'Event code not recognised.';
    final s = staff[pin];
    if (s == null) {
      if (++_failedPins >= 5) {
        _failedPins = 0;
        _lockedUntil = now.add(const Duration(seconds: 60));
        throw 'Too many tries. Wait 60 s.';
      }
      throw 'PIN not recognised.';
    }
    _failedPins = 0;
    return s;
  }

  // ----- check-in (one "transaction") -----
  Outcome checkin(String token, Gate gate, String staffId, {DateTime? at, bool offline = false}) {
    final now = at ?? accraNow();
    final pass = passes[token];
    final o = evaluate(pass: pass, gate: gate, now: now, priorOk: pass == null ? null : priorOk(pass, now));
    checkins.add(
      Checkin(
        rawToken: token,
        pass: pass,
        gate: gate,
        staffId: staffId,
        result: o.result,
        reason: o.reason,
        at: now,
        offline: offline,
      ),
    );
    return o;
  }

  /// Staff decision on an ALREADY IN warning.
  void override(Pass pass, Gate gate, String staffId, {required bool allow, DateTime? at, bool offline = false}) {
    checkins.add(
      Checkin(
        rawToken: pass.token,
        pass: pass,
        gate: gate,
        staffId: staffId,
        result: allow ? Result.ok : Result.reject,
        reason: allow ? Reason.reentry : Reason.denied,
        at: at ?? accraNow(),
        offline: offline,
      ),
    );
  }

  Checkin? priorOk(Pass pass, DateTime now) {
    for (final c in checkins.reversed) {
      if (c.pass == pass && c.result == Result.ok && sameDay(c.at, now)) return c;
    }
    return null;
  }

  List<Pass> lookupPhone(String e164) => passes.values
      .where((p) => p.attendee.phone == e164 && !p.revoked && (p.kind == PassKind.full || sameDay(p.validFrom, accraNow())))
      .toList();

  // ----- walk-ins -----
  Pass? walkinToday(IdType type, String idNumber) {
    final h = idHash(type, idNumber);
    final today = dayStart(accraNow());
    return passes.values
        .where((p) => p.attendee.idHash == h && p.kind == PassKind.day && p.validFrom == today && !p.revoked)
        .firstOrNull;
  }

  Pass? walkinEarlier(IdType type, String idNumber) {
    final h = idHash(type, idNumber);
    final today = dayStart(accraNow());
    return passes.values.where((p) => p.attendee.idHash == h && p.kind == PassKind.day && p.validFrom.isBefore(today)).lastOrNull;
  }

  /// One active walk-in pass per ID per day: returns (pass, existing).
  (Pass, bool) issueWalkin({
    required IdType idType,
    required String idNumber,
    required String fullName,
    required String phone,
    required String org,
    required Category category,
    required Staff by,
  }) {
    final existing = walkinToday(idType, idNumber);
    if (existing != null) return (existing, true);
    final today = dayStart(accraNow());
    final pass = Pass(
      token: newToken(_rng),
      attendee: Attendee(
        fullName: fullName.trim(),
        org: org.trim(),
        phone: phone,
        category: category,
        walkin: true,
        idType: idType,
        idLast4: idLast4(idNumber),
        idHash: idHash(idType, idNumber),
      ),
      kind: PassKind.day,
      zones: const ['main'],
      validFrom: today,
      validTo: today.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      issuedBy: by,
    );
    passes[pass.token] = pass;
    return (pass, false);
  }

  // ----- dashboard -----
  Stats stats() {
    final now = accraNow();
    final today = checkins.where((c) => sameDay(c.at, now)).toList();
    final inPasses = today.where((c) => c.result == Result.ok).map((c) => c.pass).toSet();
    final rejects = today.where((c) => c.result == Result.reject).toList();
    final first = today.isEmpty ? dayStart(now) : today.map((c) => c.at).reduce((a, b) => a.isBefore(b) ? a : b);
    final firstBucket = DateTime.utc(first.year, first.month, first.day, first.hour, first.minute ~/ 15 * 15);
    final buckets = List.filled(max(1, now.difference(firstBucket).inMinutes ~/ 15 + 1), 0);
    final seen = <Pass?>{};
    for (final c in today.where((c) => c.result == Result.ok)) {
      if (seen.add(c.pass)) buckets[c.at.difference(firstBucket).inMinutes ~/ 15] += 1;
    }
    return Stats(
      checkedIn: inPasses.length,
      expected: passes.values.where((p) => !p.revoked && !now.isBefore(p.validFrom) && !now.isAfter(p.validTo)).length,
      walkins: passes.values.where((p) => p.kind == PassKind.day && sameDay(p.validFrom, now)).length,
      rejects: rejects.length,
      sentToDesk: rejects.where((c) => c.reason == Reason.notRegistered || c.reason == Reason.notValidToday).length,
      conflicts: conflicts,
      arrivals: buckets,
      firstBucket: firstBucket,
      byGate: {
        for (final g in gates)
          g: (today.where((c) => c.gate == g && c.result == Result.ok).length, rejects.where((c) => c.gate == g).length),
      },
    );
  }

  String exportCsv() {
    final b = StringBuffer('scanned_at,gate,result,reason,name,organisation,category,offline\n');
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    for (final c in checkins) {
      final a = c.pass?.attendee;
      b.writeln(
        [
          c.at.toIso8601String(),
          c.gate.name,
          c.result.name,
          c.reason.name,
          q(a?.fullName ?? ''),
          q(a?.org ?? ''),
          a?.category.name ?? '',
          c.offline,
        ].join(','),
      );
    }
    return b.toString();
  }

  // ----- seed: 2,431 fake attendees + a morning of scans -----
  void _seed() {
    final r = Random(7);
    final first = [
      'Ama',
      'Kwame',
      'Kofi',
      'Abena',
      'Yaw',
      'Efua',
      'Kwesi',
      'Akosua',
      'Kojo',
      'Adwoa',
      'Ngozi',
      'Chidi',
      'Aminata',
      'Moussa',
      'Fatou',
      'Jean',
      'Sena',
      'Esi',
      'Yaa',
      'Tunde',
      'Zainab',
      'Ibrahim',
      'Awa',
      'Olu',
      'Mariam',
    ];
    final last = [
      'Mensah',
      'Asante',
      'Boateng',
      'Owusu',
      'Addo',
      'Ofori',
      'Eze',
      'Diallo',
      'Ouédraogo',
      'Kumah',
      'Adjei',
      'Okafor',
      'Traoré',
      'Sow',
      'Bello',
      'Appiah',
      'Darko',
      'Nkrumah',
      'Agyeman',
      'Sarpong',
    ];
    final orgs = [
      'Ministry of Trade & Industry',
      'Ghana Export Promotion Authority',
      'Stanbic Ghana',
      'Ecobank Transnational',
      'Bank of Ghana',
      'Afreximbank',
      'Dangote Group',
      'MTN Ghana',
      'Cocobod',
      'African Union Commission',
      'Joy News',
      'Citi FM',
      'ECOWAS Commission',
      'GIPC',
      'Access Bank Nigeria',
    ];
    final from = eventStart, to = eventEnd;

    Pass add(String name, String org, String phone, Category cat, {List<String>? zones, bool revoked = false, String? token}) {
      final p = Pass(
        token: token ?? newToken(r),
        attendee: Attendee(fullName: name, org: org, phone: phone, category: cat),
        kind: PassKind.full,
        zones:
            zones ??
            switch (cat) {
              Category.vip => ['main', 'vip'],
              Category.media => ['main', 'media'],
              _ => ['main'],
            },
        validFrom: from,
        validTo: to,
        revoked: revoked,
      );
      passes[p.token] = p;
      return p;
    }

    // Named demo cases (match the mockups).
    final ama = add('Ama Mensah', 'Ministry of Trade & Industry', '+233241112233', Category.delegate);
    final kwame = add('Kwame Asante', 'Ghana Export Promotion Authority', '+233201234567', Category.delegate);
    add('Abena Osei', 'Stanbic Ghana', '+233244635555', Category.delegate);
    add('Yaw Osei', 'Stanbic Ghana', '+233244635555', Category.delegate);
    final vip = add('Hon. Adwoa Darko', 'Ministry of Finance', '+233277000111', Category.vip);
    final revoked = add('Tunde Bello', 'Access Bank Nigeria', '+233559998877', Category.delegate, revoked: true);
    final pressOnly = add('Efua Addo', 'Joy News', '+233265554433', Category.media, zones: ['media']);
    final yesterday = eventStart;
    final kofi = Pass(
      token: newToken(r),
      attendee: Attendee(
        fullName: 'Kofi Boateng',
        org: 'Boateng Agro Exports',
        phone: '+233205550142',
        category: Category.guest,
        walkin: true,
        idType: IdType.ghanaCard,
        idLast4: idLast4('GHA-714209386-2'),
        idHash: idHash(IdType.ghanaCard, 'GHA-714209386-2'),
      ),
      kind: PassKind.day,
      zones: const ['main'],
      validFrom: yesterday,
      validTo: yesterday.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
    );
    passes[kofi.token] = kofi;

    demoTokens.addAll({
      'Ama Mensah · registered': ama.token,
      'Kwame Asante · already in': kwame.token,
      'Hon. Adwoa Darko · VIP': vip.token,
      'Unknown code': 'GP1.notARealCode000000000',
      'Kofi Boateng · yesterday\'s day pass': kofi.token,
      'Tunde Bello · cancelled pass': revoked.token,
      'Efua Addo · media entrance only': pressOnly.token,
    });

    while (passes.length < 2431) {
      final cat = switch (r.nextInt(100)) {
        < 70 => Category.delegate,
        < 80 => Category.media,
        < 92 => Category.exhibitor,
        < 96 => Category.vip,
        _ => Category.guest,
      };
      add(
        '${first[r.nextInt(first.length)]} ${last[r.nextInt(last.length)]}',
        orgs[r.nextInt(orgs.length)],
        '+2332${[0, 4, 5, 6, 7][r.nextInt(5)]}${(1000000 + r.nextInt(8999999))}',
        cat,
      );
    }

    // A morning of arrivals across gates, peaking ~90 min in.
    final now = accraNow();
    final start = now.subtract(const Duration(hours: 4)).isBefore(dayStart(now))
        ? dayStart(now)
        : now.subtract(const Duration(hours: 4));
    final span = now.difference(start).inSeconds;
    final pool =
        passes.values
            .where((p) => p.kind == PassKind.full && !p.revoked && p.zones.contains('main') && p != ama && p != kwame && p != vip)
            .toList()
          ..shuffle(r);
    DateTime at() {
      final x = (r.nextDouble() + r.nextDouble() + r.nextDouble()) / 3 * 0.8; // skew early
      return start.add(Duration(seconds: (x * span).round()));
    }

    final rows = <Checkin>[];
    for (final p in pool.take(1283)) {
      final g = p.attendee.category == Category.vip && r.nextBool() ? gates[2] : gates[r.nextInt(2)];
      rows.add(Checkin(rawToken: p.token, pass: p, gate: g, staffId: 'seed', result: Result.ok, reason: Reason.ok, at: at()));
    }
    for (var i = 0; i < 58; i++) {
      rows.add(
        Checkin(
          rawToken: 'GP1.unknown$i',
          pass: null,
          gate: gates[r.nextInt(4)],
          staffId: 'seed',
          result: Result.reject,
          reason: Reason.notRegistered,
          at: at(),
        ),
      );
    }
    final kwameAt = now.subtract(const Duration(minutes: 47));
    rows.add(
      Checkin(
        rawToken: kwame.token,
        pass: kwame,
        gate: gates[1],
        staffId: 'seed',
        result: Result.ok,
        reason: Reason.ok,
        at: kwameAt.isBefore(start) ? start : kwameAt,
      ),
    );
    rows.sort((a, b) => a.at.compareTo(b.at));
    checkins.addAll(rows);
  }
}

// ---------- device state ----------

class Device extends ChangeNotifier {
  Device(this.server);
  final DemoServer server;

  Staff? staff;
  Gate gate = gates.first;
  bool online = true;
  bool muted = false;
  Map<String, Pass> pack = {};
  DateTime? lastSync;
  int _syncedCheckedIn = 0;
  final localCheckins = <Checkin>[];
  final queue = <Checkin>[];
  Timer? _sync;

  Role get role => staff?.role ?? Role.gate;
  String get place => switch (role) {
    Role.desk => 'Accreditation desk',
    Role.organiser => '',
    Role.gate => 'Gate ${gate.name}',
  };

  void signIn(Staff s, Gate g) {
    staff = s;
    gate = g;
    syncPack();
    _sync?.cancel();
    _sync = Timer.periodic(const Duration(seconds: 60), (_) => syncPack());
    notifyListeners();
  }

  void signOut() {
    _sync?.cancel();
    staff = null;
    localCheckins.clear();
    queue.clear();
    notifyListeners();
  }

  void syncPack() {
    if (!online) return;
    pack = Map.of(server.passes);
    _syncedCheckedIn = server.stats().checkedIn;
    lastSync = accraNow();
    notifyListeners();
  }

  /// Demo control: simulates the venue Wi-Fi dropping.
  void setOnline(bool v) {
    // Going offline: freeze the last count seen online, not the one from the last 60 s sync.
    if (!v && online) _syncedCheckedIn = server.stats().checkedIn;
    online = v;
    if (v) {
      _flush();
      syncPack();
    }
    notifyListeners();
  }

  Outcome scan(String token) {
    final now = accraNow();
    late Outcome o;
    if (online) {
      o = server.checkin(token, gate, staff!.id);
      localCheckins.add(server.checkins.last);
    } else {
      final pass = pack[token];
      Checkin? prior;
      if (pass != null) {
        prior = localCheckins.reversed
            .where((c) => c.pass?.token == token && c.result == Result.ok && sameDay(c.at, now))
            .firstOrNull;
      }
      o = evaluate(pass: pass, gate: gate, now: now, priorOk: prior, tolerance: const Duration(minutes: 10));
      final c = Checkin(
        rawToken: token,
        pass: pass,
        gate: gate,
        staffId: staff!.id,
        result: o.result,
        reason: o.reason,
        at: now,
        offline: true,
      );
      localCheckins.add(c);
      queue.add(c);
    }
    notifyListeners();
    return o;
  }

  void resolveWarn(Pass pass, {required bool allow}) {
    final now = accraNow();
    if (online) {
      server.override(pass, gate, staff!.id, allow: allow);
      localCheckins.add(server.checkins.last);
    } else {
      final c = Checkin(
        rawToken: pass.token,
        pass: pass,
        gate: gate,
        staffId: staff!.id,
        result: allow ? Result.ok : Result.reject,
        reason: allow ? Reason.reentry : Reason.denied,
        at: now,
        offline: true,
      );
      localCheckins.add(c);
      queue.add(c);
    }
    notifyListeners();
  }

  /// In order; the server re-evaluates. An offline OK the server sees as a
  /// duplicate from another gate becomes a dashboard conflict, not a block.
  void _flush() {
    for (final c in queue) {
      if (c.reason == Reason.reentry || c.reason == Reason.denied) {
        server.override(c.pass!, c.gate, c.staffId, allow: c.reason == Reason.reentry, at: c.at, offline: true);
        continue;
      }
      final o = server.checkin(c.rawToken, c.gate, c.staffId, at: c.at, offline: true);
      if (c.result == Result.ok && o.reason == Reason.alreadyIn && o.previous?.gate != c.gate) server.conflicts++;
    }
    queue.clear();
  }

  List<Checkin> get recent => localCheckins.reversed.take(5).toList();
  int get checkedIn => online ? server.stats().checkedIn : _syncedCheckedIn + queue.where((c) => c.result == Result.ok).length;
  int get expected =>
      pack.values.where((p) => !p.revoked && !accraNow().isBefore(p.validFrom) && !accraNow().isAfter(p.validTo)).length;
}
