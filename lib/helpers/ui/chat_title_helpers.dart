import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';

/// Observe the records that determine a conversation's displayed title.
Stream<String> watchChatTitle(Chat chat) {
  if (chat.id == null) return const Stream<String>.empty();

  final builder = Database.chats.query(Chat_.guid.equals(chat.guid));
  builder.linkMany(Chat_.handles).link(Handle_.contactRelation);
  return builder.watch(triggerImmediately: true).map((_) {
    // Read independently of the linked query: missing contacts must not
    // exclude an unknown sender, and retained controllers may hold old handles.
    final refreshedChat = Database.chats.get(chat.id!);
    return refreshedChat?.getTitle() ?? chat.getTitle();
  }).distinct();
}
