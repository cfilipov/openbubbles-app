import 'dart:typed_data';

import 'package:bluebubbles/services/rustpush/retryable_message.dart';
import 'package:bluebubbles/src/rust/api/api.dart' as api;
import 'package:bluebubbles/src/rust/lib.dart' as rust;
import 'package:flutter_test/flutter_test.dart';

class _FakeImageArray implements rust.NsArrayLpImageMetadata {
  _FakeImageArray({this.isDisposed = false});

  @override
  final bool isDisposed;

  @override
  void dispose() {}
}

class _FakeIconArray implements rust.NsArrayLpIconMetadata {
  _FakeIconArray({this.isDisposed = false});

  @override
  final bool isDisposed;

  @override
  void dispose() {}
}

api.MessageInst _messageWithLink(api.LinkMeta link) {
  return api.MessageInst(
    id: 'message-id',
    message: api.Message.message(
      api.NormalMessage(
        parts: const api.MessageParts(field0: []),
        service: const api.MessageType.iMessage(),
        linkMeta: link,
        voice: false,
      ),
    ),
    sentTimestamp: 0,
    sendDelivered: true,
    verificationFailed: false,
  );
}

void main() {
  test('rebuilds move-only rich-link arrays before retrying', () async {
    const imageMetadata = api.LPImageMetadata(
      size: '{0, 0}',
      url: api.NSURL(base: r'$null', relative: 'https://example.com/image.png'),
      version: 1,
    );
    const iconMetadata = api.LPIconMetadata(
      url: api.NSURL(
          base: r'$null', relative: 'https://example.com/favicon.ico'),
      version: 1,
    );
    final oldImages = _FakeImageArray(isDisposed: true);
    final oldIcons = _FakeIconArray(isDisposed: true);
    final newImages = _FakeImageArray();
    final newIcons = _FakeIconArray();
    final attachment = Uint8List.fromList([1, 2, 3]);
    final originalLink = api.LinkMeta(
      attachments: [attachment],
      data: api.LPLinkMetadata(
        imageMetadata: imageMetadata,
        version: 1,
        iconMetadata: iconMetadata,
        originalUrl:
            const api.NSURL(base: r'$null', relative: 'https://example.com'),
        url: const api.NSURL(
            base: r'$null', relative: 'https://example.com/article'),
        title: 'Example title',
        summary: 'Example summary',
        images: oldImages,
        icons: oldIcons,
        isIncomplete: false,
      ),
    );
    final message = _messageWithLink(originalLink);
    var imageCreations = 0;
    var iconCreations = 0;

    final changed = await refreshLinkPreviewForRetry(
      message,
      createImageArray: ({required img}) async {
        imageCreations++;
        expect(img, same(imageMetadata));
        return newImages;
      },
      createIconArray: ({required img}) async {
        iconCreations++;
        expect(img, same(iconMetadata));
        return newIcons;
      },
    );

    final normalMessage = (message.message as api.Message_Message).field0;
    final refreshedLink = normalMessage.linkMeta!;
    expect(changed, isTrue);
    expect(imageCreations, 1);
    expect(iconCreations, 1);
    expect(refreshedLink, isNot(same(originalLink)));
    expect(refreshedLink.data.images, same(newImages));
    expect(refreshedLink.data.icons, same(newIcons));
    expect(refreshedLink.data.title, 'Example title');
    expect(refreshedLink.data.summary, 'Example summary');
    expect(refreshedLink.data.isIncomplete, isFalse);
    expect(refreshedLink.attachments.single, same(attachment));
  });

  test('does nothing when the message has no move-only preview arrays',
      () async {
    const link = api.LinkMeta(
      attachments: [],
      data: api.LPLinkMetadata(
        version: 1,
        title: 'Text-only preview',
      ),
    );
    final message = _messageWithLink(link);

    final changed = await refreshLinkPreviewForRetry(
      message,
      createImageArray: ({required img}) =>
          throw StateError('unexpected image creation'),
      createIconArray: ({required img}) =>
          throw StateError('unexpected icon creation'),
    );

    expect(changed, isFalse);
    expect(
        (message.message as api.Message_Message).field0.linkMeta, same(link));
  });
}
