import 'package:bluebubbles/database/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum FindMyDeviceIconKind {
  desktop,
  laptop,
  phone,
  tablet,
  watch,
  headphones,
  speaker,
  television,
  generic,
}

List<String> findMyDeviceArtworkUrls({
  String? deviceClass,
  String? modelDisplayName,
  String? rawDeviceModel,
  String? deviceColor,
  String? deviceModel,
}) {
  final imageClasses = <String>[];
  for (final value in [deviceClass, modelDisplayName]) {
    final imageClass = _nonEmpty(value);
    if (imageClass != null && !imageClasses.contains(imageClass)) {
      imageClasses.add(imageClass);
    }
  }
  final rawModel = _nonEmpty(rawDeviceModel);
  final serverModel = _nonEmpty(deviceModel);
  if (imageClasses.isEmpty || (rawModel == null && serverModel == null)) {
    return const [];
  }

  final variants = <String>[];
  final color = _nonEmpty(deviceColor);
  if (rawModel != null) {
    if (color != null) variants.add('$rawModel-$color');
    variants.add(rawModel);
  }

  if (serverModel != null && !variants.contains(serverModel)) {
    variants.add(serverModel);
  }

  return [
    for (final imageClass in imageClasses)
      for (final variant in variants)
        Uri(
          scheme: 'https',
          host: 'statici.icloud.com',
          pathSegments: [
            'fmipmobile',
            'deviceImages-9.0',
            imageClass,
            variant,
            'online-sourcelist__3x.png',
          ],
        ).toString(),
  ];
}

FindMyDeviceIconKind findMyDeviceIconKind({
  String? deviceClass,
  String? modelDisplayName,
  String? rawDeviceModel,
  String? deviceModel,
  bool? isMac,
}) {
  final description = [
    deviceClass,
    modelDisplayName,
    rawDeviceModel,
    deviceModel,
  ].whereType<String>().join(' ').toLowerCase();

  if (description.contains('macbook') || description.contains('laptop')) {
    return FindMyDeviceIconKind.laptop;
  }
  if (description.contains('imac') ||
      description.contains('mac mini') ||
      description.contains('macmini') ||
      description.contains('mac pro') ||
      description.contains('macpro') ||
      isMac == true) {
    return FindMyDeviceIconKind.desktop;
  }
  if (description.contains('iphone') || description.contains('ipod')) {
    return FindMyDeviceIconKind.phone;
  }
  if (description.contains('ipad') || description.contains('tablet')) {
    return FindMyDeviceIconKind.tablet;
  }
  if (description.contains('watch')) {
    return FindMyDeviceIconKind.watch;
  }
  if (description.contains('airpod') || description.contains('headphone')) {
    return FindMyDeviceIconKind.headphones;
  }
  if (description.contains('homepod') ||
      description.contains('audioaccessory') ||
      description.contains('speaker')) {
    return FindMyDeviceIconKind.speaker;
  }
  if (description.contains('appletv') || description.contains('television')) {
    return FindMyDeviceIconKind.television;
  }
  return FindMyDeviceIconKind.generic;
}

class FindMyEntityIcon extends StatelessWidget {
  const FindMyEntityIcon({
    super.key,
    required this.item,
    this.size = 46,
  });

  final FindMyDevice item;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (item.isConsideredAccessory) {
      return _FindMyItemIcon(
        emoji: item.role?['emoji']?.toString(),
        size: size,
      );
    }

    final iconKind = findMyDeviceIconKind(
      deviceClass: item.deviceClass,
      modelDisplayName: item.modelDisplayName,
      rawDeviceModel: item.rawDeviceModel,
      deviceModel: item.deviceModel,
      isMac: item.isMac == true,
    );
    final fallback = _FindMyDeviceFallbackIcon(kind: iconKind, size: size);
    final urls = findMyDeviceArtworkUrls(
      deviceClass: item.deviceClass,
      modelDisplayName: item.modelDisplayName,
      rawDeviceModel: item.rawDeviceModel,
      deviceColor: item.deviceColor?.toString(),
      deviceModel: item.deviceModel,
    );

    return SizedBox.square(
      dimension: size,
      child: urls.isEmpty
          ? fallback
          : _RetryingNetworkImage(
              urls: urls,
              fallback: fallback,
            ),
    );
  }
}

class _RetryingNetworkImage extends StatefulWidget {
  const _RetryingNetworkImage({
    required this.urls,
    required this.fallback,
  });

  final List<String> urls;
  final Widget fallback;

  @override
  State<_RetryingNetworkImage> createState() => _RetryingNetworkImageState();
}

class _RetryingNetworkImageState extends State<_RetryingNetworkImage> {
  int urlIndex = 0;
  bool advancing = false;

  @override
  void didUpdateWidget(covariant _RetryingNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.urls, widget.urls)) {
      urlIndex = 0;
      advancing = false;
    }
  }

  void tryNextUrl() {
    if (advancing) return;
    advancing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        urlIndex++;
        advancing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (urlIndex >= widget.urls.length) return widget.fallback;

    return Image.network(
      widget.urls[urlIndex],
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return widget.fallback;
      },
      errorBuilder: (context, error, stackTrace) {
        tryNextUrl();
        return widget.fallback;
      },
    );
  }
}

class _FindMyDeviceFallbackIcon extends StatelessWidget {
  const _FindMyDeviceFallbackIcon({
    required this.kind,
    required this.size,
  });

  final FindMyDeviceIconKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      FindMyDeviceIconKind.desktop => CupertinoIcons.desktopcomputer,
      FindMyDeviceIconKind.laptop => CupertinoIcons.device_laptop,
      FindMyDeviceIconKind.phone => CupertinoIcons.device_phone_portrait,
      FindMyDeviceIconKind.tablet => Icons.tablet_mac_outlined,
      FindMyDeviceIconKind.watch => Icons.watch_outlined,
      FindMyDeviceIconKind.headphones => CupertinoIcons.headphones,
      FindMyDeviceIconKind.speaker => CupertinoIcons.speaker,
      FindMyDeviceIconKind.television => CupertinoIcons.tv,
      FindMyDeviceIconKind.generic => Icons.devices_other_outlined,
    };

    return Icon(
      icon,
      size: size * 0.7,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

class _FindMyItemIcon extends StatelessWidget {
  const _FindMyItemIcon({
    required this.emoji,
    required this.size,
  });

  final String? emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final displayEmoji = _nonEmpty(emoji);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Center(
          child: displayEmoji == null
              ? Icon(
                  CupertinoIcons.tag,
                  size: size * 0.52,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : Text(
                  displayEmoji,
                  style: TextStyle(
                    fontFamily: 'Apple Color Emoji',
                    fontSize: size * 0.48,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }
}

String? _nonEmpty(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
