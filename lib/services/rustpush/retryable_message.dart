import 'package:bluebubbles/src/rust/api/api.dart' as api;
import 'package:bluebubbles/src/rust/lib.dart' as rust;

typedef ImageArrayCreator = Future<rust.NsArrayLpImageMetadata> Function({
  required api.LPImageMetadata img,
});

typedef IconArrayCreator = Future<rust.NsArrayLpIconMetadata> Function({
  required api.LPIconMetadata img,
});

/// Replaces the move-only Rust values in a rich-link preview before resending.
///
/// flutter_rust_bridge transfers ownership of the NSArray wrappers when a
/// message is sent. The Dart objects therefore remain present but disposed
/// after the first attempt, so a retry must create new wrappers around the
/// still-available plain metadata.
Future<bool> refreshLinkPreviewForRetry(
  api.MessageInst message, {
  ImageArrayCreator createImageArray = api.createImageArray,
  IconArrayCreator createIconArray = api.createIconArray,
}) async {
  final messageBody = message.message;
  if (messageBody is! api.Message_Message) return false;

  final normalMessage = messageBody.field0;
  final link = normalMessage.linkMeta;
  if (link == null) return false;

  final data = link.data;
  final hadImages = data.images != null;
  final hadIcons = data.icons != null;
  if (!hadImages && !hadIcons) return false;

  final images = hadImages && data.imageMetadata != null
      ? await createImageArray(img: data.imageMetadata!)
      : null;
  final icons = hadIcons && data.iconMetadata != null
      ? await createIconArray(img: data.iconMetadata!)
      : null;

  normalMessage.linkMeta = api.LinkMeta(
    attachments: link.attachments,
    data: api.LPLinkMetadata(
      imageMetadata: data.imageMetadata,
      version: data.version,
      iconMetadata: data.iconMetadata,
      originalUrl: data.originalUrl,
      url: data.url,
      title: data.title,
      summary: data.summary,
      image: data.image,
      icon: data.icon,
      images: images,
      icons: icons,
      isIncomplete: data.isIncomplete,
      usesActivityPub: data.usesActivityPub,
      isEncodedForLocalUse: data.isEncodedForLocalUse,
      collaborationType: data.collaborationType,
      specialization2: data.specialization2,
    ),
  );
  return true;
}
