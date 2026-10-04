import 'dart:typed_data';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/types/helpers/contact_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contactMatchesAddress', () {
    test('matches formatted local numbers to an international sender', () {
      final contact = Contact(
        id: 'address-book',
        displayName: 'Example Person',
        phones: const ['(202) 555-0100'],
      );
      expect(contactMatchesAddress(contact, '+12025550100'), isTrue);
      expect(contactMatchesAddress(contact, '+12025550101'), isFalse);
    });

    test('uses the same leading-zero normalization for first and later messages', () {
      final contact = Contact(
        id: 'address-book',
        displayName: 'Example Person',
        phones: const ['020 7946 0958'],
      );
      expect(contactMatchesAddress(contact, '+442079460958'), isTrue);
    });

    test('matches email addresses without treating email digits as phone numbers', () {
      final contact = Contact(
        id: 'address-book',
        displayName: 'Example Person',
        emails: const [' Person@Example.com '],
        phones: const ['2025550100'],
      );
      expect(contactMatchesAddress(contact, 'person@example.com'), isTrue);
      expect(contactMatchesAddress(contact, '2025550100@other.example'), isFalse);
    });

    test('does not match empty addresses or short phone suffixes', () {
      final contact = Contact(
        id: 'address-book',
        displayName: 'Example Person',
        phones: const ['', '0100'],
      );
      expect(contactMatchesAddress(contact, ''), isFalse);
      expect(contactMatchesAddress(contact, '+12025550100'), isFalse);
    });
  });

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
