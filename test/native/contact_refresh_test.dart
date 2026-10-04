import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/ui/chat_title_helpers.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:bluebubbles/services/backend_ui_interop/event_dispatcher.dart';
import 'package:bluebubbles/services/ui/contact_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestContactsService extends ContactsService {
  List<Contact> nextContacts = [];

  @override
  Future<bool> canAccessContacts() async => true;

  @override
  Future<List<Contact>> fetchAllContacts() async => nextContacts;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory databaseDirectory;
  late _TestContactsService service;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    ss.prefs = await SharedPreferences.getInstance();
    ss.settings = Settings();
    final originalService = cs;
    addTearDown(() => cs = originalService);
    databaseDirectory =
        Directory.systemTemp.createTempSync('openbubbles-contact-regression-');
    addTearDown(() => databaseDirectory.deleteSync(recursive: true));
    Database.store =
        Store(getObjectBoxModel(), directory: databaseDirectory.path);
    addTearDown(Database.store.close);
    Database.chats = Database.store.box<Chat>();
    Database.contacts = Database.store.box<Contact>();
    Database.handles = Database.store.box<Handle>();
  });

  setUp(() {
    Database.chats.removeAll();
    Database.handles.removeAll();
    Database.contacts.removeAll();
    service = _TestContactsService();
    cs = service;
  });

  test(
      'a direct refresh updates the cache before the first message from a new contact',
      () async {
    final contact = Contact(
      id: 'new-address-book-contact',
      displayName: 'Example Person',
      phones: const ['(202) 555-0100'],
      avatar: Uint8List.fromList([1, 2, 3]),
    );
    service.nextContacts = [contact];
    final notification = eventDispatcher.stream
        .firstWhere((event) => event.item1 == 'update-contacts');

    final changedIds = await service.refreshContacts();
    expect(changedIds.first, contains(contact.dbId));
    expect((await notification).item2, changedIds);
    expect(service.contacts.single.displayName, contact.displayName);

    final sender = Handle(address: '+12025550100').save();
    expect(sender.contact?.id, contact.id);
    expect(Database.handles.get(sender.id!)?.contact?.avatar, contact.avatar);
  });

  test('an unchanged refresh does not notify every open conversation',
      () async {
    service.nextContacts = [
      Contact(
        id: 'address-book',
        displayName: 'Example Person',
        phones: const ['2025550100'],
      )
    ];
    await service.refreshContacts();
    await Future<void>.delayed(Duration.zero);

    final events = <Object>[];
    final subscription = eventDispatcher.stream.listen(events.add);
    addTearDown(subscription.cancel);
    final changedIds = await service.refreshContacts();
    await Future<void>.delayed(Duration.zero);

    expect(changedIds, [<int>[], <int>[]]);
    expect(events, isEmpty);
  });

  test(
      'the list title follows a saved association without a chat write or UI event',
      () async {
    await service.hasContactAccess;
    final sender = Handle(address: '+12025550100').save();
    final chat =
        Chat(guid: 'iMessage;-;contact-title-test', participants: [sender]);
    chat.handles.add(sender);
    chat.id = Database.chats.put(chat);
    final retainedChat = Database.chats.get(chat.id!)!;
    expect(retainedChat.getTitle(), sender.address);
    final titles = StreamQueue(watchChatTitle(retainedChat));
    addTearDown(titles.cancel);
    expect(
        await titles.next.timeout(const Duration(seconds: 5)), sender.address);

    final contact = Contact(
      id: 'address-book',
      displayName: 'Example Person',
      phones: [sender.address],
    );
    contact.dbId = Database.contacts.put(contact);
    final freshHandle = Database.handles.get(sender.id!)!;
    freshHandle.contactRelation.target = contact;
    Database.handles.put(freshHandle);
    expect(await titles.next.timeout(const Duration(seconds: 5)),
        'Example Person');

    contact.displayName = 'Updated Person';
    Database.contacts.put(contact);
    expect(await titles.next.timeout(const Duration(seconds: 5)),
        'Updated Person');

    // The controller really is stale; the observer must use persisted handles.
    expect(retainedChat.getTitle(), sender.address);
    final reopenedTitles = StreamQueue(watchChatTitle(retainedChat));
    addTearDown(reopenedTitles.cancel);
    expect(await reopenedTitles.next.timeout(const Duration(seconds: 5)),
        'Updated Person');

    freshHandle.contactRelation.target = null;
    Database.handles.put(freshHandle);
    expect(
        await titles.next.timeout(const Duration(seconds: 5)), sender.address);
  });

  test('a contact learned after an unknown thread updates its list title',
      () async {
    await service.hasContactAccess;
    final sender = Handle(address: '+12025550100').save();
    final chat =
        Chat(guid: 'iMessage;-;new-contact-test', participants: [sender]);
    chat.handles.add(sender);
    chat.id = Database.chats.put(chat);
    final titles = StreamQueue(watchChatTitle(chat));
    addTearDown(titles.cancel);
    expect(
        await titles.next.timeout(const Duration(seconds: 5)), sender.address);

    service.nextContacts = [
      Contact(
        id: 'address-book',
        displayName: 'Example Person',
        phones: const ['(202) 555-0100'],
      )
    ];
    final changedIds = await service.refreshContacts();
    expect(changedIds.last, contains(sender.id));
    expect(await titles.next.timeout(const Duration(seconds: 5)),
        'Example Person');
  });
}
