import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

const attachmentUploadRetryDelay = Duration(seconds: 2);
const maxAttachmentUploadRetries = 1;

bool isRetryableAttachmentUploadError(Object error) {
  return error is AnyhowException &&
      error.message.contains('Send timeout; try again');
}

Future<T> retryAttachmentUpload<T>(
  Future<T> Function() upload, {
  int maxRetries = maxAttachmentUploadRetries,
  Duration retryDelay = attachmentUploadRetryDelay,
  bool Function(Object error)? retryWhen,
  Future<void> Function(Duration duration)? delay,
  void Function(int retry, Object error)? onRetry,
}) async {
  final shouldRetry = retryWhen ?? isRetryableAttachmentUploadError;
  final wait = delay ?? Future<void>.delayed;
  var retries = 0;

  while (true) {
    try {
      return await upload();
    } catch (error) {
      if (retries >= maxRetries || !shouldRetry(error)) rethrow;
      retries++;
      onRetry?.call(retries, error);
      await wait(retryDelay);
    }
  }
}
