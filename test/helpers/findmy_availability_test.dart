import 'package:bluebubbles/app/layouts/findmy/findmy_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('direct connections retain Maps before the item service is ready', () {
    expect(canOpenFindMy(directConnection: true, serverSupportsFindMy: false), isTrue);
    expect(canOpenFindMy(directConnection: true, serverSupportsFindMy: true), isTrue);
  });

  test('server connections still require advertised Find My support', () {
    expect(canOpenFindMy(directConnection: false, serverSupportsFindMy: false), isFalse);
    expect(canOpenFindMy(directConnection: false, serverSupportsFindMy: true), isTrue);
  });
}
