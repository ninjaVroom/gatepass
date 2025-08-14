import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'main.dart';
import 'theme.dart';

/// Uppercase field/section label (14/600, +0.4 tracking).
class Label extends StatelessWidget {
  const Label(this.text, {super.key, this.color = C.ink2});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: T.label.copyWith(color: color, fontSize: 13));
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.card), boxShadow: cardShadow),
    child: child,
  );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.bg, required this.fg, this.outline});
  final String text;
  final Color bg, fg;
  final Color? outline;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(R.chip),
      border: outline == null ? null : Border.all(color: outline!, width: 2),
    ),
    child: Text(
      text.toUpperCase(),
      style: T.label.copyWith(color: fg, fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

/// Category chip colours from 03-design.md. `onDark` inverts for full-bleed result screens.
Widget categoryChip(Category c, {bool onDark = false}) {
  final (bg, fg) = switch (c) {
    Category.delegate => (C.brand, C.brandInk),
    Category.media => (C.info, C.brandInk),
    Category.exhibitor => (C.ink2, C.brandInk),
    Category.vip => (C.accent, C.ink),
    Category.guest => (C.ink2, C.brandInk),
  };
  return onDark && c != Category.vip ? Pill(c.label, bg: C.surface, fg: C.ink) : Pill(c.label, bg: bg, fg: fg);
}

class Avatar extends StatelessWidget {
  const Avatar(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 18,
    backgroundColor: C.avatar,
    child: Text(
      text,
      style: T.label.copyWith(color: C.brand, fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}

/// Result dot in lists. Paired with a text label for screen readers (never colour-only).
Widget resultDot(Result r) => Semantics(
  label: r.name,
  child: Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: switch (r) {
        Result.ok => C.ok,
        Result.warn => C.warn,
        Result.reject => C.bad,
      },
    ),
  ),
);

/// 48pt top strip: event · place · online pill · clock · staff menu.
class StatusStrip extends StatefulWidget implements PreferredSizeWidget {
  const StatusStrip({super.key, this.title});
  final String? title;
  @override
  Size get preferredSize => const Size.fromHeight(48);
  @override
  State<StatusStrip> createState() => _StatusStripState();
}

class _StatusStripState extends State<StatusStrip> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 10), (_) => setState(() {}));
  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = device;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) => Container(
        height: 48,
        color: C.brand,
        padding: const EdgeInsets.only(left: 20, right: 4),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Text(
                widget.title ?? DemoServer.eventName,
                style: T.body.copyWith(color: C.brandInk, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(width: 16),
              Text(d.place, style: T.body.copyWith(color: C.brandInk, fontSize: 15)),
              const Spacer(),
              Tooltip(
                message: 'Demo: long-press to simulate Wi-Fi loss',
                child: GestureDetector(
                  onLongPress: () => d.setOnline(!d.online),
                  child: d.online
                      ? Pill('Online', bg: C.okTint, fg: C.okSurface)
                      : Pill('Offline', bg: C.warnTint, fg: C.warnInk),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                hhmm(accraNow()),
                style: T.body.copyWith(color: C.brandInk, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              PopupMenuButton<String>(
                tooltip: 'Staff menu',
                icon: const Icon(Icons.more_vert, color: C.brandInk),
                onSelected: (v) {
                  switch (v) {
                    case 'mute':
                      d.muted = !d.muted;
                    case 'offline':
                      d.setOnline(!d.online);
                    case 'out':
                      d.signOut();
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'mute', child: Text(d.muted ? 'Unmute sounds' : 'Mute sounds')),
                  PopupMenuItem(value: 'offline', child: Text(d.online ? 'Simulate offline (demo)' : 'Go back online (demo)')),
                  const PopupMenuItem(value: 'out', child: Text('Sign out')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3×4 keypad. Keys are digits plus [left] and backspace.
class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.onDigit,
    required this.onBack,
    required this.left,
    required this.onLeft,
    this.keyHeight = 80,
  });
  final ValueChanged<String> onDigit;
  final VoidCallback onBack, onLeft;
  final String left;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onTap, {String? semantic, bool small = false}) => Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: C.surface,
        borderRadius: BorderRadius.circular(R.control),
        elevation: 0,
        shadowColor: C.shadow,
        child: InkWell(
          borderRadius: BorderRadius.circular(R.control),
          focusColor: C.accent.withValues(alpha: .35),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Semantics(
            button: true,
            label: semantic ?? label,
            child: SizedBox(
              height: keyHeight,
              child: Center(
                child: label == '⌫'
                    ? const Icon(Icons.backspace_outlined, color: C.ink, size: 26)
                    : Text(label, style: small ? T.button.copyWith(fontSize: 17) : T.key),
              ),
            ),
          ),
        ),
      ),
    );

    Widget row(List<Widget> keys) => Row(children: [for (final k in keys) Expanded(child: k)]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          row([for (final n in r) key(n, () => onDigit(n))]),
        row([key(left, onLeft, small: true), key('0', () => onDigit('0')), key('⌫', onBack, semantic: 'Delete')]),
      ],
    );
  }
}

/// Segmented control (grey track, white selected segment).
class Segmented<V> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, required this.label});
  final List<V> options;
  final V value;
  final ValueChanged<V> onChanged;
  final String Function(V) label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: C.segTrack, borderRadius: BorderRadius.circular(R.control)),
    child: Row(
      children: [
        for (final o in options)
          Expanded(
            child: Semantics(
              selected: o == value,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(R.control - 2),
                focusColor: C.accent.withValues(alpha: .35),
                onTap: () => onChanged(o),
                child: AnimatedContainer(
                  duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 150),
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o == value ? C.surface : null,
                    borderRadius: BorderRadius.circular(R.control - 2),
                    boxShadow: o == value ? cardShadow : null,
                  ),
                  child: Text(
                    label(o),
                    style: T.body.copyWith(
                      fontSize: 16,
                      fontWeight: o == value ? FontWeight.w700 : FontWeight.w500,
                      color: o == value ? C.ink : C.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
