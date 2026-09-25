import 'package:bluebubbles/database/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepares a failed attachment message with a fresh retry identity', () {
    final originalTimestamp = DateTime(2026, 9, 24, 16, 53);
    final retryTimestamp = DateTime(2026, 9, 24, 16, 57);
    final firstAttachment = Attachment(id: 8, guid: 'temp-original');
    final secondAttachment = Attachment(id: 9, guid: 'temp-second');
    final message = Message(
      id: 42,
      guid: 'error-Send timeout; try again-original',
      error: 400,
      dateCreated: originalTimestamp,
      dateDelivered: originalTimestamp,
      dateRead: originalTimestamp,
      isDelievered: true,
      attachments: [firstAttachment, secondAttachment],
      hasAttachments: true,
      sendingServiceId: 'old-service',
    );

    message.prepareForRetry(
      tempGuid: 'temp-retry',
      timestamp: retryTimestamp,
    );

    expect(message.id, isNull);
    expect(message.guid, 'temp-retry');
    expect(message.error, 0);
    expect(message.dateCreated, retryTimestamp);
    expect(message.dateDelivered, isNull);
    expect(message.dateRead, isNull);
    expect(message.isDelivered, isFalse);
    expect(message.sendingServiceId, isNull);
    expect(firstAttachment.id, isNull);
    expect(firstAttachment.guid, 'temp-retry');
    expect(secondAttachment.id, isNull);
    expect(secondAttachment.guid, 'temp-retry-1');
  });
}
