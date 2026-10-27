import 'dart:convert';

import 'package:bluebubbles/database/global/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final includeAll in [false, true]) {
    test('settings encode a missing map position (includeAll=$includeAll)', () {
      final settings = Settings();
      final decoded = jsonDecode(jsonEncode(settings.toMap(includeAll: includeAll)));
      expect(decoded['lastLocation'], isNull);
    });

    test('settings round-trip a saved map position (includeAll=$includeAll)', () {
      final settings = Settings();
      settings.lastLocation.value = '1.25,-2.5';
      final decoded = jsonDecode(jsonEncode(settings.toMap(includeAll: includeAll))) as Map<String, dynamic>;
      expect(decoded['lastLocation'], '1.25,-2.5');
      expect(Settings.fromMap(decoded).lastLocation.value, '1.25,-2.5');
    });
  }
}
