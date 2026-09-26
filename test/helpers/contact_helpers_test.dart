import 'dart:typed_data';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/types/helpers/contact_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('selectPreferredContact', () {
    test('prefers a contact with a photo over an app-created shadow contact',
        () {
      final shadow = Contact(
        id: 'shadow',
        displayName: 'Example Person',
        phones: const ['5550100'],
      );
      final addressBook = Contact(
        id: 'address-book',
        displayName: 'Example Person',
        phones: const ['(555) 0100'],
        emails: const ['person@example.com'],
        avatar: Uint8List.fromList([1, 2, 3]),
      );

      expect(selectPreferredContact([shadow, addressBook]), same(addressBook));
      expect(selectPreferredContact([addressBook, shadow]), same(addressBook));
      expect(
        selectPreferredContact([shadow, addressBook], current: shadow),
        same(addressBook),
      );
    });

    test('prefers the richer contact when neither record has a photo', () {
      final shadow = Contact(
        id: 'shadow',
        displayName: 'Example Person',
        phones: const ['5550100'],
      );
      final addressBook = Contact(
        id: 'address-book',
        displayName: 'Example Person',
        phones: const ['5550100', '5550101'],
        emails: const ['person@example.com'],
      );

      expect(selectPreferredContact([shadow, addressBook]), same(addressBook));
    });

    test('keeps the current contact when candidates have equal quality', () {
      final first = Contact(
        id: 'first',
        displayName: 'Example Person',
        phones: const ['5550100'],
      );
      final current = Contact(
        id: 'current',
        displayName: 'Example Person',
        phones: const ['5550100'],
      );

      expect(
        selectPreferredContact([first, current], current: current),
        same(current),
      );
    });

    test('uses the contact id as a deterministic final tie breaker', () {
      final later = Contact(
        id: 'z-contact',
        displayName: 'Example Person',
        phones: const ['5550100'],
      );
      final earlier = Contact(
        id: 'a-contact',
        displayName: 'Example Person',
        phones: const ['5550100'],
      );

      expect(selectPreferredContact([later, earlier]), same(earlier));
      expect(selectPreferredContact([earlier, later]), same(earlier));
    });
  });
}
