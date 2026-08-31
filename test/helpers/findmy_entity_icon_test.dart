import 'package:bluebubbles/app/layouts/findmy/findmy_entity_icon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('findMyDeviceArtworkUrls', () {
    test('builds color, model, and server-model fallbacks in order', () {
      expect(
        findMyDeviceArtworkUrls(
          deviceClass: 'iPhone',
          rawDeviceModel: 'iPhone8,2',
          deviceColor: 'e4e7e8-e4c1b9',
          deviceModel: 'iphone6splus-e4e7e8-e4c1b9',
        ),
        [
          'https://statici.icloud.com/fmipmobile/deviceImages-9.0/iPhone/iPhone8,2-e4e7e8-e4c1b9/online-sourcelist__3x.png',
          'https://statici.icloud.com/fmipmobile/deviceImages-9.0/iPhone/iPhone8,2/online-sourcelist__3x.png',
          'https://statici.icloud.com/fmipmobile/deviceImages-9.0/iPhone/iphone6splus-e4e7e8-e4c1b9/online-sourcelist__3x.png',
        ],
      );
    });

    test('uses the display name as a second class fallback', () {
      expect(
        findMyDeviceArtworkUrls(
          deviceClass: 'MacBookPro',
          modelDisplayName: 'MacBook Pro',
          rawDeviceModel: 'MacBookPro15,1',
        ),
        [
          'https://statici.icloud.com/fmipmobile/deviceImages-9.0/MacBookPro/MacBookPro15,1/online-sourcelist__3x.png',
          'https://statici.icloud.com/fmipmobile/deviceImages-9.0/MacBook%20Pro/MacBookPro15,1/online-sourcelist__3x.png',
        ],
      );
    });

    test('uses the server model if a raw model is unavailable', () {
      expect(
        findMyDeviceArtworkUrls(
          deviceClass: 'iPhone',
          deviceModel: 'iPhone17,1-1-1-0',
        ).single,
        'https://statici.icloud.com/fmipmobile/deviceImages-9.0/iPhone/iPhone17,1-1-1-0/online-sourcelist__3x.png',
      );
    });

    test('does not request artwork without a class or any model', () {
      expect(findMyDeviceArtworkUrls(deviceClass: 'iPhone'), isEmpty);
      expect(findMyDeviceArtworkUrls(rawDeviceModel: 'iPhone15,2'), isEmpty);
    });
  });

  group('findMyDeviceIconKind', () {
    test('classifies Apple device metadata', () {
      expect(
        findMyDeviceIconKind(rawDeviceModel: 'MacBookAir10,1'),
        FindMyDeviceIconKind.laptop,
      );
      expect(
        findMyDeviceIconKind(deviceClass: 'iPhone'),
        FindMyDeviceIconKind.phone,
      );
      expect(
        findMyDeviceIconKind(modelDisplayName: 'Apple Watch'),
        FindMyDeviceIconKind.watch,
      );
      expect(
        findMyDeviceIconKind(rawDeviceModel: 'AudioAccessory1,1'),
        FindMyDeviceIconKind.speaker,
      );
    });

    test('uses Mac and generic fallbacks', () {
      expect(
        findMyDeviceIconKind(isMac: true),
        FindMyDeviceIconKind.desktop,
      );
      expect(
        findMyDeviceIconKind(),
        FindMyDeviceIconKind.generic,
      );
    });
  });
}
