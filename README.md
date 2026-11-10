# Gatepass

Samuel Vroom

A Flutter check-in kiosk for event staff. It validates passes, looks up attendees and issues walk-in passes from a tablet interface.

## Case study

A scan can fail for several different reasons. Gatepass checks whether the pass exists, whether it was revoked, whether it is valid that day and whether the attendee can enter that gate. A previous successful scan is shown as a separate warning, with the earlier gate attached.

The interface separates gate staff, accreditation staff and the organiser dashboard. Gate staff scan and look up attendees. Accreditation staff create walk-in passes. The dashboard reads the same demo server, so new check-ins and conflicts appear in its totals.

An offline device queues scans and sends them when its connection returns. The simulation can show a pass accepted at another gate while the first device was offline. Tests cover that conflict, the date tolerance, pass rules, phone formatting and duplicate walk-in issuance.

The server is an in-process simulation with 2,431 fictional attendees. The queue is a demo of reconnection behaviour, not a durable production sync service. Camera scanning is supported by the app dependency; the Demo scan control lets reviewers inspect each result without a printed pass.

## Run locally

Install Flutter with Dart compatible with `pubspec.yaml`.

```sh
flutter pub get
flutter run
flutter test
```

Use a tablet or emulator in landscape. Event code: `TS23AC`. Demo PINs: `1234` for the gate, `2580` for accreditation, `9999` for the organiser dashboard. The gate menu can simulate a lost connection.

## Source

`lib/data.dart` contains the pass rules, demo server and device queue. `lib/screens/` contains the gate, phone lookup, walk-in and dashboard screens. `test/widget_test.dart` checks the existing rules and reconnection flow.

## Prototype

Figma prototype link pending.
