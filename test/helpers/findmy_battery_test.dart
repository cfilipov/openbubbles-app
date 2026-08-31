import 'package:bluebubbles/app/layouts/findmy/findmy_battery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('findMyItemBatteryStatus', () {
    test('does not warn for full or medium battery reports', () {
      expect(findMyItemBatteryStatus(null), isNull);
      expect(findMyItemBatteryStatus(0x10), isNull);
      expect(findMyItemBatteryStatus(0x50), isNull);
    });

    test('decodes low battery report flags', () {
      expect(findMyItemBatteryStatus(0x90), 'Low Battery');
      expect(findMyItemBatteryStatus(0xD0), 'Very Low Battery');
    });
  });
}
