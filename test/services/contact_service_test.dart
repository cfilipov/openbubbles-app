import 'dart:typed_data';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/ui/contact_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ContactsServiceWithAccess extends ContactsService {
  @override
  Future<bool> canAccessContacts() async => true;
}

void main() {
  test('a new sender uses the same preferred duplicate as a bulk refresh',
      () async {
    final service = _ContactsServiceWithAccess();
    await service.hasContactAccess;
    final shadow = Contact(
      id: 'shadow',
      displayName: 'Example Person',
      phones: const ['2025550100'],
    );
    final addressBook = Contact(
      id: 'address-book',
      displayName: 'Example Person',
      phones: const ['(202) 555-0100'],
      avatar: Uint8List.fromList([1, 2, 3]),
    );
    service.contacts = [shadow, addressBook];
    final newSender = Handle(address: '+12025550100');

    expect(service.matchHandleToContact(newSender), same(addressBook));
    expect(
        service.matchContactToHandles(addressBook, [newSender]), [newSender]);
    service.contacts = [addressBook, shadow];
    expect(service.matchHandleToContact(newSender), same(addressBook));
  });

  test('a new sender with a trunk-zero contact matches before a refresh',
      () async {
    final service = _ContactsServiceWithAccess();
    await service.hasContactAccess;
    final contact = Contact(
      id: 'address-book',
      displayName: 'Example Person',
      phones: const ['020 7946 0958'],
    );
    service.contacts = [contact];
    final newSender = Handle(address: '+442079460958');

    expect(service.matchHandleToContact(newSender), same(contact));
    expect(service.matchContactToHandles(contact, [newSender]), [newSender]);
  });
}
