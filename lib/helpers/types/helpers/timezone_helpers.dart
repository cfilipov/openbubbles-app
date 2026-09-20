import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:universal_io/io.dart';

Future<void>? _localTimeZoneInitialization;

/// Initializes timezone data before any notification scheduling can use it.
Future<void> initializeLocalTimeZone() {
  return _localTimeZoneInitialization ??= _initializeLocalTimeZone();
}

Future<void> _initializeLocalTimeZone() async {
  tz.initializeTimeZones();
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

  try {
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (_) {
    // The timezone package defaults to UTC, which is still safe to schedule
    // with if the platform timezone cannot be resolved.
  }
}
