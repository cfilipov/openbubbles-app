import 'package:bluebubbles/services/rustpush/retryable_attachment_upload.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retries one transient attachment upload timeout', () async {
    var attempts = 0;
    var waits = 0;

    final result = await retryAttachmentUpload<String>(
      () async {
        attempts++;
        if (attempts == 1) {
          throw AnyhowException('Send timeout; try again');
        }
        return 'uploaded';
      },
      delay: (_) async => waits++,
    );

    expect(result, 'uploaded');
    expect(attempts, 2);
    expect(waits, 1);
  });

  test('does not retry unrelated upload failures', () async {
    var attempts = 0;

    await expectLater(
      retryAttachmentUpload<void>(
        () async {
          attempts++;
          throw AnyhowException('permission denied');
        },
        delay: (_) async => fail('should not wait'),
      ),
      throwsA(isA<AnyhowException>()),
    );

    expect(attempts, 1);
  });

  test('stops after the configured retry', () async {
    var attempts = 0;

    await expectLater(
      retryAttachmentUpload<void>(
        () async {
          attempts++;
          throw AnyhowException('Send timeout; try again');
        },
        delay: (_) async {},
      ),
      throwsA(isA<AnyhowException>()),
    );

    expect(attempts, 2);
  });
}
