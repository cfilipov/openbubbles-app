import 'package:bluebubbles/app/layouts/findmy/findmy_refresh_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late FindMyRefreshGate gate;

  setUp(() {
    now = DateTime.utc(2026, 10, 27);
    gate = FindMyRefreshGate(now: () => now);
  });

  test('serializes timer and manual refreshes', () {
    expect(gate.begin(), isTrue);
    expect(gate.begin(), isFalse);
    expect(gate.begin(manual: true), isFalse);
    gate.complete(succeeded: true);
    expect(gate.begin(), isTrue);
  });

  test('backs off from completion and caps repeated failures at five minutes', () {
    for (final seconds in [30, 60, 120, 240, 300, 300, 300]) {
      expect(gate.begin(), isTrue);
      now = now.add(const Duration(seconds: 7));
      gate.complete(succeeded: false);
      expect(gate.nextAttempt, now.add(Duration(seconds: seconds)));
      expect(gate.inFlight, isFalse);
      now = now.add(Duration(seconds: seconds - 1));
      expect(gate.begin(), isFalse);
      now = now.add(const Duration(seconds: 1));
    }
  });

  test('successful refresh resets the failure delay', () {
    expect(gate.begin(), isTrue);
    gate.complete(succeeded: false);
    expect(gate.begin(manual: true), isTrue);
    gate.complete(succeeded: true);
    expect(gate.nextAttempt, isNull);
    expect(gate.begin(), isTrue);
    gate.complete(succeeded: false);
    expect(gate.nextAttempt, now.add(const Duration(seconds: 30)));
  });

  test('manual retry bypasses backoff without erasing failure history', () {
    expect(gate.begin(), isTrue);
    gate.complete(succeeded: false);
    expect(gate.begin(), isFalse);
    expect(gate.begin(manual: true), isTrue);
    gate.complete(succeeded: false);
    expect(gate.nextAttempt, now.add(const Duration(minutes: 1)));
  });
}
