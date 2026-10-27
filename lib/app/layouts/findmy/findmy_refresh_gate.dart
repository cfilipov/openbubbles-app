/// Serializes refreshes and backs off after failures while Find My is open.
/// A manual retry bypasses the delay, but never overlaps an active refresh.
class FindMyRefreshGate {
  FindMyRefreshGate({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  bool inFlight = false;
  int _failures = 0;
  DateTime? nextAttempt;

  bool begin({bool manual = false}) {
    if (inFlight) return false;
    if (!manual && nextAttempt != null && _now().isBefore(nextAttempt!)) {
      return false;
    }
    inFlight = true;
    return true;
  }

  void complete({required bool succeeded}) {
    inFlight = false;
    if (succeeded) {
      _failures = 0;
      nextAttempt = null;
      return;
    }
    // 30s, 1m, 2m, 4m, then at most one attempt every five minutes.
    const delays = [30, 60, 120, 240, 300];
    if (_failures < delays.length) _failures++;
    nextAttempt = _now().add(Duration(seconds: delays[_failures - 1]));
  }
}
