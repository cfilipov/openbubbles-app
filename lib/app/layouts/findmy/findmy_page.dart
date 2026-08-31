import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_battery.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_location_clipper.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_pin_clipper.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/rustpush/rustpush_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:get/get.dart' hide Response;
import 'package:latlong2/latlong.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';
import 'package:bluebubbles/src/rust/api/api.dart' as api;
import 'package:url_launcher/url_launcher.dart';

class FindMyPage extends StatefulWidget {
  FindMyPage({super.key, this.defaultFriend});

  String? defaultFriend;

  @override
  State<StatefulWidget> createState() => _FindMyPageState();
}

class _FindMyPageState extends OptimizedState<FindMyPage> with SingleTickerProviderStateMixin {
  final ScrollController devicesScrollController = ScrollController();
  final ScrollController itemsScrollController = ScrollController();
  final ScrollController friendsScrollController = ScrollController();
  late final TabController tabController = TabController(vsync: this, length: 3);
  final PanelController panelController = PanelController();
  final RxInt index = 0.obs;
  final PopupController popupController = PopupController();
  final MapController mapController = MapController();
  final completer = Completer<void>();

  StreamSubscription? locationSub;
  List<FindMyDevice> devices = [];
  List<FindMyFriend> friends = [];
  Map<String, Marker> markers = {};
  Position? location;
  bool? fetching = true;
  bool refreshing = false;
  bool? fetching2 = true;
  bool refreshing2 = false;
  bool locationRefreshInFlight = false;
  bool canRefresh = false;
  bool isInClique = true;

  Map<(double, double), Address> cachedAddresses = {};

  List<api.DartBeacon> cachedBeacons = [];
  DateTime? beaconCacheDate;

  Timer? myTimer;

  api.FindMyFriendsClientDefaultAnisetteProvider? fmfClient;
  api.FindMyPhoneClientDefaultAnisetteProvider? fmipClient;

  bool hasDeviceLocation(FindMyDevice item) =>
      item.location?.latitude != null && item.location?.longitude != null;

  bool hasFriendLocation(FindMyFriend item) =>
      item.latitude != null &&
      item.longitude != null &&
      item.latitude != 0 &&
      item.longitude != 0;

  String deviceKey(FindMyDevice item) =>
      item.id ??
      item.deviceDiscoveryId ??
      item.baUuid ??
      item.role?["sharingId"]?.toString() ??
      "${item.isConsideredAccessory}:${item.name ?? item.deviceDisplayName ?? item.modelDisplayName ?? item.rawDeviceModel ?? 'unknown'}";

  String friendKey(FindMyFriend item) =>
      item.id ??
      item.handle?.uniqueAddressAndService ??
      item.title ??
      "unknown-friend";

  List<T> preserveOrder<T>(
    List<T> previous,
    List<T> updated,
    String Function(T item) keyOf,
  ) {
    final updatedByKey = <String, T>{};
    for (final item in updated) {
      updatedByKey[keyOf(item)] = item;
    }

    final ordered = <T>[];
    for (final item in previous) {
      final replacement = updatedByKey.remove(keyOf(item));
      if (replacement != null) ordered.add(replacement);
    }
    ordered.addAll(updatedByKey.values);
    return ordered;
  }

  String deviceLocationSubtitle(FindMyDevice item) {
    if (ss.settings.redactedMode.value) return "Location";
    final address = item.address?.label ?? item.address?.mapItemFullAddress;
    if (address != null && address.isNotEmpty) return address;
    if (!hasDeviceLocation(item)) return "No location found";
    final timestamp = item.location?.timeStamp;
    if (timestamp != null && timestamp > 0) {
      return "Last updated ${buildDate(DateTime.fromMillisecondsSinceEpoch(timestamp))}";
    }
    return "Location found";
  }

  Widget itemLocationSubtitle(BuildContext context, FindMyDevice item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(deviceLocationSubtitle(item)),
        if (item.batteryStatus != null)
          Text(
            item.batteryStatus!,
            style: context.theme.textTheme.bodySmall?.copyWith(
              color: context.theme.colorScheme.error,
            ),
          ),
      ],
    );
  }

  Widget? itemTrailing(BuildContext context, FindMyDevice item) {
    if (item.batteryStatus == null && !hasDeviceLocation(item)) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.batteryStatus != null)
          Icon(
            Icons.battery_alert,
            color: context.theme.colorScheme.error,
            semanticLabel: item.batteryStatus,
          ),
        if (hasDeviceLocation(item))
          ButtonTheme(
            minWidth: 1,
            child: TextButton(
              style: TextButton.styleFrom(
                shape: const CircleBorder(),
                backgroundColor: context.theme.colorScheme.primaryContainer,
              ),
              onPressed: () async {
                await MapsLauncher.launchCoordinates(item.location!.latitude!, item.location!.longitude!);
              },
              child: const Icon(
                Icons.directions,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    tabController.addListener(_syncSelectedTab);
    if (widget.defaultFriend != null) {
      index.value = 2; // select friends tab
      tabController.index = 2;
    }
    getLocations();

    myTimer = Timer.periodic(const Duration(seconds: 5), (timer) => getLocations());

    socket.socket.on("new-findmy-location", (data) {
      try {
        final friend = FindMyFriend.fromJson(data);
        Logger.info("Received new location for ${friend.handle?.address}");
        if ((friend.latitude ?? 0) == 0 && (friend.longitude ?? 0) == 0) return;
        final existingFriendIndex = friends.indexWhere((e) => e.handle?.uniqueAddressAndService == friend.handle?.uniqueAddressAndService);
        final existingFriend = existingFriendIndex == -1 ? null : friends[existingFriendIndex];
        if (existingFriend == null || existingFriend.status == null || friend.locatingInProgress || LocationStatus.values.indexOf(existingFriend.status!) <= LocationStatus.values.indexOf(friend.status ?? LocationStatus.legacy)) {
          Logger.info("Updating map for ${friend.handle?.address}");
          if (existingFriendIndex == -1) {
            friends.add(friend);
          } else {
            friends[existingFriendIndex] = friend;
          }

          buildFriendMarker(friend);
          setState(() {});
        }
      } catch (_) {}
    });

    // // Allow users to refresh after 30sec
    // Future.delayed(const Duration(seconds: 30), () {
    //   if (mounted) {
    //     setState(() {
    //       canRefresh = true;
    //     });
    //   }
    // });
  }

  void _syncSelectedTab() {
    if (index.value != tabController.index) {
      index.value = tabController.index;
    }
  }

  /// Fetches the FindMy data from the server.
  /// The toggles for refresh friends & devices are separate due to an inconsistency in the server API.
  /// As of v1.9.7 (server), the refresh devices endpoint doesn't return the devices data,
  /// however, the refresh friends endpoint does. The way this was coded assumes that the server
  /// will return the data for both endpoints. A server update will fix this, but for now,
  /// we will "patch" it by only "refreshing" devices when the user manually refreshes the data.
  void getLocations({bool refreshFriends = true, bool refreshDevices = true}) {
    if (locationRefreshInFlight) return;
    locationRefreshInFlight = true;
    unawaited(() async {
      try {
        await _getLocations(
          refreshFriends: refreshFriends,
          refreshDevices: refreshDevices,
        );
      } catch (error, trace) {
        Logger.error("Failed to refresh FindMy data", error: error, trace: trace);
      } finally {
        locationRefreshInFlight = false;
      }
    }());
  }

  Future<void> _getLocations({bool refreshFriends = true, bool refreshDevices = true}) async {
    if (!(Platform.isLinux && !kIsWeb)) {
      LocationPermission granted = await Geolocator.checkPermission();
      if (granted == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }
      if (granted == LocationPermission.whileInUse || granted == LocationPermission.always) {
        Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 30))).then((loc) {
          if (!mounted) return;
          if (ss.settings.lastLocation.value == null) {
            mapController.move(LatLng(loc.latitude, loc.longitude), 10);
          }
          ss.settings.lastLocation.value = "${loc.latitude},${loc.longitude}";
          ss.saveSettings();
          location = loc;
          buildLocationMarker(location!);
          if (!kIsDesktop && locationSub == null) {
            locationSub = Geolocator.getPositionStream().listen((event) {
              ss.settings.lastLocation.value = "${event.latitude},${event.longitude}";
              ss.saveSettings();
              setState(() {
                buildLocationMarker(event);
              });
    });
  }

          if (!refreshFriends) {
            mapController.move(LatLng(location!.latitude, location!.longitude), 10);
          }
        });
      }
    }

    var isNew = fmfClient == null;
    fmfClient ??= await api.makeFindMyFriends(
      path: pushService.statePath,
      config: pushService.state!.osConfig,
      aps: pushService.state!.conn,
      anisette: pushService.state!.anisette,
      provider: pushService.state!.icloudServices!.tokenProvider,
    );

    try {
      if (refreshFriends && !isNew) {
        await api.refreshFollowing(config: pushService.state!.osConfig, client: fmfClient!);
      }

      var following = await api.getFollowing(client: fmfClient!);
    
      final updatedFriends = following
          .map((e) => 
            FindMyFriend(
              latitude: e.lastLocation?.latitude,
              longitude: e.lastLocation?.longitude,
              longAddress: e.lastLocation?.address?.formattedAddressLines?.join("\n"), 
              shortAddress: e.lastLocation?.address != null ? "${e.lastLocation?.address?.locality}, ${e.lastLocation?.address?.stateCode ?? e.lastLocation?.address?.countryCode}" : null,
              title: null, 
              subtitle: null, 
              handle: Handle.findOne(addressAndService: Tuple2(e.invitationAcceptedHandles.first, "iMessage")) ?? Handle(address: e.invitationAcceptedHandles.first), 
              lastUpdated: e.lastLocation?.timestamp != null ? DateTime.fromMillisecondsSinceEpoch(e.lastLocation!.timestamp) : null,
              status: null, 
              locatingInProgress: false,
              id: e.id,
            )
          )
          .toList()
          .cast<FindMyFriend>();

      friends = preserveOrder(friends, updatedFriends, friendKey);

      markers.removeWhere((key, value) => key.startsWith("friend-"));
      for (FindMyFriend e in friends.where(hasFriendLocation)) {
        buildFriendMarker(e);
      }
      setState(() {
        fetching2 = false;
        refreshing2 = false;
      });
      if (widget.defaultFriend != null) {
        var friend = friends.firstWhereOrNull((friend) => friend.id == widget.defaultFriend);
        widget.defaultFriend = null;
        if (friend != null) {
          if (context.isPhone) {
            await panelController.close();
          }
          await completer.future;

          await api.selectFriend(config: pushService.state!.osConfig, client: fmfClient!, friend: friend.id);


          if (friend.latitude != null) {

            final marker = markers["friend-${friendKey(friend)}"];
            if (marker == null) return;
            popupController.showPopupsOnlyFor([marker]);
            mapController.move(LatLng(friend.latitude!, friend.longitude!), 10);

          }
        }
      }
    } catch (e, s) {
      Logger.error("Failed to parse FindMy Friends location data!", error: e, trace: s);
      setState(() {
        fetching2 = null;
        refreshing2 = false;
      });
      return;
    }

    var isNewi = fmipClient == null;
    fmipClient ??= await api.makeFindMyPhone(
      config: pushService.state!.osConfig,
      path: pushService.statePath,
      aps: pushService.state!.conn,
      anisette: pushService.state!.anisette,
      provider: pushService.state!.icloudServices!.tokenProvider,
    );


    try {
      if (refreshDevices && !isNewi) {
        await api.refreshDevices(config: pushService.state!.osConfig, client: fmipClient!);
      }

      var following = await api.getDevices(client: fmipClient!);
    
      final updatedDevices = following
          .map((e) => 
            FindMyDevice(
              deviceModel: e.deviceModel, 
              lowPowerMode: e.lowPowerMode, 
              passcodeLength: e.passcodeLength, 
              itemGroup: null, 
              id: e.id, 
              batteryStatus: e.batteryStatus, 
              audioChannels: [], 
              lostModeCapable: e.lostModeCapable, 
              snd: null, 
              batteryLevel: e.batteryLevel, 
              locationEnabled: e.locationEnabled, 
              isConsideredAccessory: e.isConsideredAccessory ?? false, 
              address: null, 
              location: e.location != null ? Location(
                positionType: e.location!.positionType, 
                verticalAccuracy: e.location!.verticalAccuracy.round(), 
                longitude: e.location!.longitude, 
                floorLevel: e.location!.floorLevel, 
                isInaccurate: e.location!.isInaccurate, 
                isOld: e.location!.isOld, 
                horizontalAccuracy: e.location!.horizontalAccuracy, 
                latitude: e.location!.latitude, 
                timeStamp: e.location!.timestamp, 
                altitude: e.location!.altitude.round(), 
                locationFinished: e.location!.locationFinished
                ) : null, 
              modelDisplayName: e.modelDisplayName, 
              deviceColor: e.deviceColor, 
              activationLocked: e.activationLocked, 
              rm2State: e.rm2State, 
              locFoundEnabled: e.locFoundEnabled, 
              nwd: e.nwd, 
              deviceStatus: e.deviceStatus, 
              remoteWipe: null, 
              fmlyShare: e.fmlyShare, 
              thisDevice: e.thisDevice, 
              lostDevice: null, 
              lostModeEnabled: e.lostModeEnabled, 
              deviceDisplayName: e.deviceDisplayName, 
              safeLocations: null, 
              name: e.name, 
              canWipeAfterLock: e.canWipeAfterLock, 
              isMac: e.isMac, 
              rawDeviceModel: e.rawDeviceModel, 
              baUuid: e.baUuid, 
              trackingInfo: null,
              features: e.features, 
              deviceDiscoveryId: e.deviceDiscoveryId, 
              prsId: null, 
              scd: e.scd, 
              locationCapable: e.locationCapable, 
              remoteLock: null, 
              wipeInProgress: e.wipeInProgress, 
              darkWake: e.darkWake, 
              deviceWithYou: e.deviceWithYou, 
              maxMsgChar: e.maxMsgChar, 
              deviceClass: e.deviceClass, 
              crowdSourcedLocation: null, 
              role: null,
              lostModeMetadata: null
            )
          )
          .toList().cast<FindMyDevice>();
      

      if (beaconCacheDate == null || DateTime.now().difference(beaconCacheDate!).inMinutes > 3) {
        isInClique = await api.isInClique(keychain: pushService.state!.icloudServices!.keychain!);
        try {
          cachedBeacons = isInClique ? await api.getBeaconItems(items: pushService.state!.icloudServices!.fmfd!) : [];
        } catch (e, s) {
          // used for PCS key missing catching after we reset the clique.
          Logger.error("Failed to fetch beacon data", error: e, trace: s);
        }
        beaconCacheDate = DateTime.now();
        for (var cached in cachedBeacons) {
          if (cached.lastReport == null) continue;
          try {
            var placemark = await pushService.reverseGeocode(cached.lastReport!.lat, cached.lastReport!.long);
            if (placemark != null) {
              cachedAddresses[(cached.lastReport!.lat, cached.lastReport!.long)] = Address(
                subAdministrativeArea: placemark.subAdministrativeArea,
                label: placemark.thoroughfare ?? placemark.name,
                streetAddress: placemark.thoroughfare,
                country: placemark.country,
                countryCode: placemark.isoCountryCode,
                administrativeArea: placemark.administrativeArea,
                streetName: placemark.thoroughfare,
                formattedAddressLines: [
                  if (placemark.thoroughfare != null)
                  placemark.thoroughfare!,
                  if (placemark.locality != null)
                  placemark.locality!,
                  if (placemark.administrativeArea != null)
                  placemark.administrativeArea!,
                ],
                locality: placemark.locality,
                stateCode: placemark.administrativeArea?.substring(0, 2).toUpperCase(),
                mapItemFullAddress: null,
                fullThroroughfare: null,
                areaOfInterest: [],
              );
            }
          } catch (e, s) {
            Logger.warn("Geocoding failed", error: e, trace: s);
          }
        }
      }
      for (api.DartBeacon e in cachedBeacons) {
        var location = e.lastReport != null ? Location(
            positionType: null, 
            verticalAccuracy: e.lastReport!.confidence, 
            longitude: e.lastReport!.long, 
            floorLevel: null, 
            isInaccurate: null, 
            isOld: null, 
            horizontalAccuracy: e.lastReport!.horizontalAccuracy.toDouble(), 
            latitude: e.lastReport!.lat, 
            timeStamp: api.systemtimeToMillis(time: e.lastReport!.timestamp), 
            altitude: null, 
            locationFinished: true,
            ) : null;
        if (e.productId == -1) {
          var existingDevice = updatedDevices.firstWhereOrNull((d) => d.name == e.naming.name && !d.isConsideredAccessory);
          if (existingDevice == null || e.lastReport == null) continue;
          if (existingDevice.location?.timeStamp != null && api.systemtimeToMillis(time: e.lastReport!.timestamp) < existingDevice.location!.timeStamp!) continue; // report is older
          existingDevice.location = location;
          continue; // this is an iDevice
        }
        updatedDevices.add(FindMyDevice(
          deviceModel: e.model, 
          lowPowerMode: false, 
          passcodeLength: null, 
          itemGroup: null, 
          id: e.id, 
          batteryStatus: findMyItemBatteryStatus(e.lastReport?.status),
          audioChannels: [], 
          lostModeCapable: true, 
          snd: null, 
          batteryLevel: e.batteryLevel?.toDouble(), 
          locationEnabled: true, 
          isConsideredAccessory: true, 
          address: e.lastReport == null ? null : cachedAddresses[(e.lastReport!.lat, e.lastReport!.long)], 
          location: location, 
          modelDisplayName: null, 
          deviceColor: null, 
          activationLocked: false, 
          rm2State: null, 
          locFoundEnabled: false, 
          nwd: null, 
          deviceStatus: null, 
          remoteWipe: null, 
          fmlyShare: null, 
          thisDevice: false, 
          lostDevice: null, 
          lostModeEnabled: false, 
          deviceDisplayName: e.naming.name, 
          safeLocations: null, 
          name: e.naming.name, 
          canWipeAfterLock: false, 
          isMac: false, 
          rawDeviceModel: e.model,
          baUuid: null,
          trackingInfo: null,
          features: null,
          deviceDiscoveryId: null,
          prsId: null, 
          scd: null,
          locationCapable: null,
          remoteLock: null, 
          wipeInProgress: null,
          darkWake: null,
          deviceWithYou: false,
          maxMsgChar: null,
          deviceClass: null,
          crowdSourcedLocation: null, 
          role: {
            "emoji": e.naming.emoji,
            "sharingId": e.shared?.shareId,
            "sharingActive": e.shared?.acceptanceState,
            "sharingName": e.shared?.ownerHandle != null ? RustPushBBUtils.rustHandleToBB(e.shared!.ownerHandle).displayName : null,
          },
          lostModeMetadata: null
        ));
      }

      devices = preserveOrder(devices, updatedDevices, deviceKey);

      markers.removeWhere((key, value) => key.startsWith("device-"));
      for (FindMyDevice e in devices.where(hasDeviceLocation)) {
          final key = deviceKey(e);
          markers['device-$key'] = Marker(
            key: ValueKey('device-$key'),
            point: LatLng(e.location!.latitude!, e.location!.longitude!),
            width: 30,
            height: 35,
            child: ClipShadowPath(
              clipper: const FindMyPinClipper(),
              shadow: const BoxShadow(
                color: Colors.black,
                blurRadius: 2,
              ),
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: e.role?['emoji'] != null
                        ? Text(e.role!['emoji'],
                            style: context.theme.textTheme.bodyLarge!.copyWith(fontFamily: 'Apple Color Emoji'))
                        : Icon(
                            (e.isMac ?? false)
                                ? CupertinoIcons.desktopcomputer
                                : e.isConsideredAccessory
                                    ? CupertinoIcons.headphones
                                    : CupertinoIcons.device_phone_portrait,
                            color: Colors.black,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
            alignment: Alignment.topCenter,
          );
        }
      setState(() {
        fetching = false;
        refreshing = false;
      });
    } catch (e, s) {
      Logger.error("Failed to parse FindMy Devices location data!", error: e, trace: s);
      setState(() {
        fetching = null;
        refreshing = false;
      });
      return;
    }
    

    // // Call the FindMy Friends refresh anyways so that new data comes through the socket
    // if (!refreshFriends) {
    //   http.refreshFindMyFriends();
    // } else {
    //   setState(() {
    //     canRefresh = false;
    //   });
    //   // Allow users to refresh after 30sec
    //   Future.delayed(const Duration(seconds: 30), () {
    //     if (mounted) {
    //       setState(() {
    //         canRefresh = true;
    //       });
    //     }
    //   });
    // }
  }

  void buildFriendMarker(FindMyFriend friend) {
    final key = friendKey(friend);
    markers['friend-$key'] = Marker(
      key: ValueKey('friend-$key'),
      point: LatLng(friend.latitude!, friend.longitude!),
      width: 35,
      height: 35,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child:
            ContactAvatarWidget(editable: false, handle: friend.handle ?? Handle(address: friend.title ?? "Unknown")),
          ),
        ),
      ),
      alignment: Alignment.topCenter,
    );
  }

  void buildLocationMarker(Position pos) {
    markers['current'] = Marker(
      key: const ValueKey('current'),
      point: LatLng(pos.latitude, pos.longitude),
      width: 25,
      height: 55,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pos.heading.isFinite)
            Transform.rotate(
              angle: pos.heading,
              child: ClipPath(
                clipper: const FindMyLocationClipper(),
                child: Container(
                  width: 25,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.center,
                      end: Alignment.topCenter,
                      colors: [context.theme.colorScheme.primary, context.theme.colorScheme.primary.withAlpha(50)],
                    ),
                  ),
                ),
              ),
            ),
          Container(
            width: 25,
            height: 25,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      alignment: Alignment.topCenter,
    );
  }

  Future<void> deleteShared(FindMyDevice item) async {
    await api.deleteBeaconShare(items: pushService.state!.icloudServices!.fmfd!, share: item.role!['sharingId']!);
    setState(() {
      devices.remove(item);
    });
    beaconCacheDate = null;
  }

  Future<void> addShared(FindMyDevice item) async {
    await api.acceptBeaconShare(items: pushService.state!.icloudServices!.fmfd!, share: item.role!['sharingId']!);
    setState(() {
      devices.remove(item); // it'll go away anyways because it has no location
    });
    beaconCacheDate = null;
    getLocations();
  }

  @override
  void dispose() {
    locationSub?.cancel();
    devicesScrollController.dispose();
    itemsScrollController.dispose();
    friendsScrollController.dispose();
    mapController.dispose();
    popupController.dispose();
    tabController.removeListener(_syncSelectedTab);
    tabController.dispose();
    myTimer?.cancel();
    // TODO
    socket.socket.off("new-findmy-location");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceEntries =
        devices.where((item) => !item.isConsideredAccessory).toList();
    final itemEntries =
        devices.where((item) => item.isConsideredAccessory).toList();
    final devicesBodySlivers = [
      SliverList(
        delegate: SliverChildListDelegate([
          if (fetching == null || fetching == true || (fetching == false && deviceEntries.isEmpty))
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        fetching == null
                            ? "Something went wrong!"
                            : fetching == false
                                ? "You have no devices."
                                : "Getting FindMy data...",
                        style: context.theme.textTheme.labelLarge,
                      ),
                    ),
                    if (fetching == true) buildProgressIndicator(context, size: 15),
                  ],
                ),
              ),
            ),
          if (deviceEntries.isNotEmpty)
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Devices"),
          if (deviceEntries.isNotEmpty)
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    findChildIndexCallback: (key) =>
                        findChildIndexByKey(deviceEntries, key, deviceKey),
                    itemBuilder: (context, i) {
                      final item = deviceEntries[i];
                      return ListTile(
                        key: ValueKey(deviceKey(item)),
                        mouseCursor: MouseCursor.defer,
                        title: Text(ss.settings.redactedMode.value ? "Device" : (item.name ?? "Unknown Device")),
                        subtitle: Text(deviceLocationSubtitle(item)),
                        onTap: hasDeviceLocation(item)
                            ? () async {
                                if (context.isPhone) {
                                  await panelController.close();
                                }
                                await completer.future;
                                final marker = markers["device-${deviceKey(item)}"];
                                if (marker == null) return;
                                popupController.showPopupsOnlyFor([marker]);
                                mapController.move(LatLng(item.location!.latitude!, item.location!.longitude!), 10);
                              }
                            : null,
                        trailing: hasDeviceLocation(item) ? ButtonTheme(
                          minWidth: 1,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              shape: const CircleBorder(),
                              backgroundColor: context.theme.colorScheme.primaryContainer,
                            ),
                            onPressed: () async {
                              await MapsLauncher.launchCoordinates(item.location!.latitude!, item.location!.longitude!);
                            },
                            child: const Icon(
                                Icons.directions,
                                size: 20
                            ),
                          ),
                        ) : null,
                        onLongPress: () async {
                          const encoder = JsonEncoder.withIndent("     ");
                          final str = encoder.convert(item.toJson());
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                "Raw FindMy Data",
                                style: context.theme.textTheme.titleLarge,
                              ),
                              backgroundColor: context.theme.colorScheme.properSurface,
                              content: SizedBox(
                                width: ns.width(context) * 3 / 5,
                                height: context.height * 1 / 4,
                                child: Container(
                                  padding: const EdgeInsets.all(10.0),
                                  decoration: BoxDecoration(
                                      color: context.theme.colorScheme.background,
                                      borderRadius: const BorderRadius.all(Radius.circular(10))),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      str,
                                      style: context.theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  child: Text("Close",
                                      style: context.theme.textTheme.bodyLarge!
                                          .copyWith(color: context.theme.colorScheme.primary)),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    itemCount: deviceEntries.length,
                  ),
                ),
              ],
            ),
        ]),
      ),
    ];

    final itemsBodySlivers = [
      SliverList(
        delegate: SliverChildListDelegate([
          if (fetching == null ||
              fetching == true ||
              (fetching == false && itemEntries.isEmpty && isInClique))
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        fetching == null
                            ? "Something went wrong!"
                            : fetching == false
                                ? "You have no items."
                                : "Getting FindMy data...",
                        style: context.theme.textTheme.labelLarge,
                      ),
                    ),
                    if (fetching == true) buildProgressIndicator(context, size: 15),
                  ],
                ),
              ),
            ),
          if (itemEntries.isNotEmpty || !isInClique)
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Items"),
          if (!isInClique)
          Obx(() => SettingsSection(
            backgroundColor: tileColor,
            children: [
              SettingsTile(
                title: "Show Airtags",
                onTap: () async {
                  if (pushService.state?.icloudServices?.keychain == null) {
                    showSnackbar("Relog required!", "Relog required to use Backup! Relog in Settings -> Reconfigure");
                    return;
                  }
                  if (!await pushService.joinClique()) return;
                  beaconCacheDate = null;
                  getLocations();
                },
                trailing: const NextButton(),
              ),
            ]
        )),
          if (itemEntries.isNotEmpty)
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    findChildIndexCallback: (key) =>
                        findChildIndexByKey(itemEntries, key, deviceKey),
                    itemBuilder: (context, i) {
                      final item = itemEntries[i];
                      var tile = ListTile(
                        key: ValueKey(deviceKey(item)),
                        title: Text(ss.settings.redactedMode.value ? "Item" : (item.name ?? "Unknown Item")),
                        subtitle: item.role?["sharingActive"] == 0 ? Column(
                          children: [
                            Text("${item.role?["sharingName"]} wants to share this item with you."),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.theme.colorScheme.outline.withAlpha(64),
                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 13),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    elevation: 0.0,
                                    minimumSize: Size.zero,
                                  ),
                                  onPressed: () async {
                                    pushService.wrapPromise(deleteShared(item), "Removing...");
                                  },
                                  child: Text("Don't Add", style: context.theme.textTheme.titleMedium),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.theme.colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 13),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    elevation: 0.0,
                                    minimumSize: Size.zero,
                                  ),
                                  onPressed: () async {
                                    pushService.wrapPromise(addShared(item), "Adding...");
                                  },
                                  child: Text("Add", style: context.theme.textTheme.titleMedium?.apply(color: context.theme.colorScheme.onPrimary)),
                                ),
                              ],
                            )
                          ],
                        )
                          : itemLocationSubtitle(context, item),
                        trailing: itemTrailing(context, item),
                        onTap: hasDeviceLocation(item)
                            ? () async {
                                if (context.isPhone) {
                                  await panelController.close();
                                }
                                await completer.future;
                                final marker = markers["device-${deviceKey(item)}"];
                                if (marker == null) return;
                                popupController.showPopupsOnlyFor([marker]);
                                mapController.move(LatLng(item.location!.latitude!, item.location!.longitude!), 10);
                              }
                            : null,
                        onLongPress: () async {
                          const encoder = JsonEncoder.withIndent("     ");
                          final str = encoder.convert(item.toJson());
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                "Raw FindMy Data",
                                style: context.theme.textTheme.titleLarge,
                              ),
                              backgroundColor: context.theme.colorScheme.properSurface,
                              content: SizedBox(
                                width: ns.width(context) * 3 / 5,
                                height: context.height * 1 / 4,
                                child: Container(
                                  padding: const EdgeInsets.all(10.0),
                                  decoration: BoxDecoration(
                                      color: context.theme.colorScheme.background,
                                      borderRadius: const BorderRadius.all(Radius.circular(10))),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      str,
                                      style: context.theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  child: Text("Close",
                                      style: context.theme.textTheme.bodyLarge!
                                          .copyWith(color: context.theme.colorScheme.primary)),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                      if (item.role?['sharingId'] != null) {
                        return wrapDelete(tile, (context) => deleteShared(item));
                      }
                      return tile;
                    },
                    itemCount: itemEntries.length,
                  ),
                ),
              ],
            ),
        ]),
      ),
    ];

    final friendsBodySlivers = [
      SliverList(
        delegate: SliverChildListDelegate([
          if (fetching2 == null || fetching2 == true || (fetching2 == false && friends.isEmpty))
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        fetching2 == null
                            ? "Something went wrong!"
                            : fetching2 == false
                                ? "You have no friends."
                                : "Getting FindMy data...",
                        style: context.theme.textTheme.labelLarge,
                      ),
                    ),
                    if (fetching2 == true) buildProgressIndicator(context, size: 15),
                  ],
                ),
              ),
            ),
          if (friends.isNotEmpty)
            SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Friends"),
          if (friends.isNotEmpty)
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    findChildIndexCallback: (key) =>
                        findChildIndexByKey(friends, key, friendKey),
                    itemBuilder: (context, i) {
                      final item = friends[i];
                      return ListTile(
                        key: ValueKey(friendKey(item)),
                        leading: ContactAvatarWidget(handle: item.handle),
                        title: Text(item.handle?.displayName ?? item.title ?? "Unknown Friend"),
                        subtitle: Text(ss.settings.redactedMode.value ? "Location" : ("${item.shortAddress ?? item.longAddress ?? "No location found"}${item.lastUpdated == null || item.status == LocationStatus.live ? "" : "\nLast updated ${buildDate(item.lastUpdated)}"}")),
                        trailing: hasFriendLocation(item) ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.status == LocationStatus.live)
                              const Icon(CupertinoIcons.largecircle_fill_circle),
                            if (item.locatingInProgress)
                              buildProgressIndicator(context),
                            ButtonTheme(
                              minWidth: 1,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  shape: const CircleBorder(),
                                  backgroundColor: context.theme.colorScheme.primaryContainer,
                                ),
                                onPressed: () async {
                                  await MapsLauncher.launchCoordinates(item.latitude!, item.longitude!);
                                },
                                child: const Icon(
                                    Icons.directions,
                                    size: 20
                                ),
                              ),
                            ),
                          ],
                        ) : null,
                        onTap: () async {
                          if (!hasFriendLocation(item)) {
                            await api.selectFriend(
                              config: pushService.state!.osConfig,
                              client: fmfClient!,
                              friend: item.id,
                            );
                            return;
                          }
                          if (context.isPhone) {
                            await panelController.close();
                          }
                          await completer.future;
                          final marker = markers["friend-${friendKey(item)}"];
                          if (marker == null) return;
                          popupController.showPopupsOnlyFor([marker]);
                          mapController.move(LatLng(item.latitude!, item.longitude!), 10);
                        },
                        onLongPress: () async {
                          const encoder = JsonEncoder.withIndent("     ");
                          final str = encoder.convert(item.toJson());
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                "Raw FindMy Data",
                                style: context.theme.textTheme.titleLarge,
                              ),
                              backgroundColor: context.theme.colorScheme.properSurface,
                              content: SizedBox(
                                width: ns.width(context) * 3 / 5,
                                height: context.height / 2,
                                child: Container(
                                  padding: const EdgeInsets.all(10.0),
                                  decoration: BoxDecoration(
                                      color: context.theme.colorScheme.background,
                                      borderRadius: const BorderRadius.all(Radius.circular(10))),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      str,
                                      style: context.theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  child: Text("Close",
                                      style: context.theme.textTheme.bodyLarge!
                                          .copyWith(color: context.theme.colorScheme.primary)),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    itemCount: friends.length,
                  ),
                ),
              ],
            ),
        ]),
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: ss.settings.immersiveMode.value
              ? Colors.transparent
              : context.theme.colorScheme.background, // navigation bar color
          systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
          statusBarColor: Colors.transparent, // status bar color
          statusBarIconBrightness: Brightness.dark,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (context.isPhone) {
              return buildNormal(context, devicesBodySlivers, itemsBodySlivers, friendsBodySlivers);
            }
            return buildTabletLayout(context, devicesBodySlivers, itemsBodySlivers, friendsBodySlivers);
          },
        ));
  }

  Widget buildTabletLayout(
    BuildContext context,
    List<SliverList> devicesBodySlivers,
    List<SliverList> itemsBodySlivers,
    List<SliverList> friendsBodySlivers,
  ) {
    return Obx(
      () => Scaffold(
        backgroundColor: context.theme.colorScheme.background.themeOpacity(context),
        body: Stack(
          children: [
            Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: 300, maxWidth: max(300, min(500, ns.width(context) / 3))),
                  child: Container(
                    width: 500,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      buildMap(),
                      if (!samsung && canRefresh)
                        Positioned(
                          top: 10 + (kIsDesktop ? appWindow.titleBarHeight : MediaQuery.of(context).padding.top),
                          right: 20,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.properSurface.withOpacity(0.9),
                            ),
                            child: Container(
                              width: 48,
                              child: refreshing || refreshing2
                                  ? buildProgressIndicator(context)
                                  : IconButton(
                                      iconSize: 22,
                                      icon: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh,
                                          color: context.theme.colorScheme.onBackground, size: 22),
                                      onPressed: () {
                                        setState(() {
                                          refreshing = true;
                                          refreshing2 = true;
                                        });
                                        getLocations();
                                      },
                                    ),
                            ),
                          ),
                        ),
                      if (kIsDesktop)
                        SizedBox(
                          height: appWindow.titleBarHeight,
                          child: AbsorbPointer(
                            child: Row(children: [
                              Expanded(child: Container()),
                              ClipRect(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaY: 2, sigmaX: 2),
                                  child: Container(
                                      height: appWindow.titleBarHeight,
                                      width: appWindow.titleBarButtonSize.width * 3,
                                      color: context.theme.colorScheme.properSurface.withOpacity(0.5)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 300, maxWidth: max(300, min(500, ns.width(context) / 3))),
              child: Column(
                children: [
                  if (!samsung)
                    Container(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            child: buildBackButton(context),
                          ),
                          Expanded(child: Text("Find My", style: context.theme.textTheme.titleLarge)),
                        ],
                      ),
                    ),
                  if (!samsung) buildDesktopTabBar(),
                  Expanded(
                    child: Container(
                      width: 500,
                      child: TabBarView(
                        controller: tabController,
                        children: [
                          ScrollbarWrapper(
                            controller: devicesScrollController,
                            child: CustomScrollView(
                              key: const PageStorageKey("find-my-devices"),
                              controller: devicesScrollController,
                              slivers: [
                                if (samsung) buildSamsungAppBar(context, "Find My Devices"),
                                if (ss.settings.skin.value != Skins.Samsung) ...devicesBodySlivers,
                                if (ss.settings.skin.value == Skins.Samsung)
                                  SliverToBoxAdapter(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight: context.height -
                                              50 -
                                              context.mediaQueryPadding.top -
                                              context.mediaQueryViewPadding.top),
                                      child: CustomScrollView(
                                        physics: const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        slivers: devicesBodySlivers,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ScrollbarWrapper(
                            controller: itemsScrollController,
                            child: CustomScrollView(
                              key: const PageStorageKey("find-my-items"),
                              controller: itemsScrollController,
                              slivers: [
                                if (samsung) buildSamsungAppBar(context, "Find My Items"),
                                if (!samsung) ...itemsBodySlivers,
                                if (samsung)
                                  SliverToBoxAdapter(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight: context.height -
                                              50 -
                                              context.mediaQueryPadding.top -
                                              context.mediaQueryViewPadding.top),
                                      child: CustomScrollView(
                                        physics: const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        slivers: itemsBodySlivers,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ScrollbarWrapper(
                            controller: friendsScrollController,
                            child: CustomScrollView(
                              key: const PageStorageKey("find-my-friends"),
                              controller: friendsScrollController,
                              slivers: [
                                if (samsung) buildSamsungAppBar(context, "Find My Friends"),
                                if (!samsung) ...friendsBodySlivers,
                                if (samsung)
                                  SliverToBoxAdapter(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight: context.height -
                                              50 -
                                              context.mediaQueryPadding.top -
                                              context.mediaQueryViewPadding.top),
                                      child: CustomScrollView(
                                        physics: const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        slivers: friendsBodySlivers,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (samsung) buildDesktopTabBar()
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDesktopTabBar() {
    return TabBar(
      controller: tabController,
      dividerColor: context.theme.dividerColor.withOpacity(0.2),
      tabs: [
        Container(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iOS ? CupertinoIcons.device_desktop : Icons.devices),
              const Text("Devices"),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iOS ? CupertinoIcons.tag : Icons.label_outline),
              const Text("Items"),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iOS ? CupertinoIcons.person_2 : Icons.person),
              const Text("Friends"),
            ],
          ),
        ),
      ],
    );
  }

  Widget wrapDelete(Widget child, Function(BuildContext) onPressed) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.30,
        children: [
          SlidableAction(
            label: 'Remove',
            backgroundColor: Colors.red,
            icon: ss.settings.skin.value == Skins.iOS ? CupertinoIcons.trash : Icons.delete_outlined,
            onPressed: (_) async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: context.theme.colorScheme.properSurface,
                    title: Text(
                      "Deleting...",
                      style: context.theme.textTheme.titleLarge,
                    ),
                    content: Container(
                      height: 70,
                      child: Center(child: buildProgressIndicator(context)),
                    ),
                  );
                }
              );
              await onPressed(context);
              Get.back();
            },
          ),
        ],
      ),
      child: child,
    );
  }

  Widget buildNormal(
    BuildContext context,
    List<SliverList> devicesBodySlivers,
    List<SliverList> itemsBodySlivers,
    List<SliverList> friendsBodySlivers,
  ) {
    return Obx(
      () => Scaffold(
        backgroundColor: material ? tileColor : headerColor,
        body: Stack(
          children: [
            SlidingUpPanel(
              controller: panelController,
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25.0),
                topRight: Radius.circular(25.0),
              ),
              minHeight: 50,
              maxHeight: MediaQuery.of(context).size.height * 0.75,
              disableDraggableOnScrolling: true,
              backdropEnabled: true,
              parallaxEnabled: true,
              header: ForceDraggableWidget(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 40),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              panelBuilder: () => TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: tabController,
                children: <Widget>[
                  NotificationListener<ScrollEndNotification>(
                    onNotification: (_) {
                      if (ss.settings.skin.value != Skins.Samsung || kIsWeb || kIsDesktop) return false;
                      final scrollDistance = context.height / 3 - 57;

                      if (devicesScrollController.offset > 0 &&
                          devicesScrollController.offset < scrollDistance) {
                        final double snapOffset =
                            devicesScrollController.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                        Future.microtask(() => devicesScrollController.animateTo(snapOffset,
                            duration: const Duration(milliseconds: 200), curve: Curves.linear));
                      }
                      return false;
                    },
                    child: ScrollbarWrapper(
                      controller: devicesScrollController,
                      child: Obx(
                        () => CustomScrollView(
                          key: const PageStorageKey("find-my-devices"),
                          controller: devicesScrollController,
                          physics: (kIsDesktop || kIsWeb)
                              ? const NeverScrollableScrollPhysics()
                              : ThemeSwitcher.getScrollPhysics(),
                          slivers: <Widget>[
                            if (samsung) buildSamsungAppBar(context, "Find My Devices"),
                            if (ss.settings.skin.value != Skins.Samsung) ...devicesBodySlivers,
                            if (ss.settings.skin.value == Skins.Samsung)
                              SliverToBoxAdapter(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minHeight: context.height -
                                          50 -
                                          context.mediaQueryPadding.top -
                                          context.mediaQueryViewPadding.top),
                                  child: CustomScrollView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    slivers: devicesBodySlivers,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  NotificationListener<ScrollEndNotification>(
                    onNotification: (_) {
                      if (ss.settings.skin.value != Skins.Samsung || kIsWeb || kIsDesktop) return false;
                      final scrollDistance = context.height / 3 - 57;

                      if (itemsScrollController.offset > 0 &&
                          itemsScrollController.offset < scrollDistance) {
                        final double snapOffset =
                            itemsScrollController.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                        Future.microtask(() => itemsScrollController.animateTo(snapOffset,
                            duration: const Duration(milliseconds: 200), curve: Curves.linear));
                      }
                      return false;
                    },
                    child: ScrollbarWrapper(
                      controller: itemsScrollController,
                      child: Obx(
                        () => CustomScrollView(
                          key: const PageStorageKey("find-my-items"),
                          controller: itemsScrollController,
                          physics: (kIsDesktop || kIsWeb)
                              ? const NeverScrollableScrollPhysics()
                              : ThemeSwitcher.getScrollPhysics(),
                          slivers: <Widget>[
                            if (samsung) buildSamsungAppBar(context, "Find My Items"),
                            if (ss.settings.skin.value != Skins.Samsung) ...itemsBodySlivers,
                            if (ss.settings.skin.value == Skins.Samsung)
                              SliverToBoxAdapter(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minHeight: context.height -
                                          50 -
                                          context.mediaQueryPadding.top -
                                          context.mediaQueryViewPadding.top),
                                  child: CustomScrollView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    slivers: itemsBodySlivers,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  NotificationListener<ScrollEndNotification>(
                    onNotification: (_) {
                      if (ss.settings.skin.value != Skins.Samsung || kIsWeb || kIsDesktop) return false;
                      final scrollDistance = context.height / 3 - 57;

                      if (friendsScrollController.offset > 0 &&
                          friendsScrollController.offset < scrollDistance) {
                        final double snapOffset =
                            friendsScrollController.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                        Future.microtask(() => friendsScrollController.animateTo(snapOffset,
                            duration: const Duration(milliseconds: 200), curve: Curves.linear));
                      }
                      return false;
                    },
                    child: ScrollbarWrapper(
                      controller: friendsScrollController,
                      child: Obx(
                        () => CustomScrollView(
                          key: const PageStorageKey("find-my-friends"),
                          controller: friendsScrollController,
                          physics: (kIsDesktop || kIsWeb)
                              ? const NeverScrollableScrollPhysics()
                              : ThemeSwitcher.getScrollPhysics(),
                          slivers: <Widget>[
                            if (samsung) buildSamsungAppBar(context, "Find My Friends"),
                            if (ss.settings.skin.value != Skins.Samsung) ...friendsBodySlivers,
                            if (ss.settings.skin.value == Skins.Samsung)
                              SliverToBoxAdapter(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minHeight: context.height -
                                          50 -
                                          context.mediaQueryPadding.top -
                                          context.mediaQueryViewPadding.top),
                                  child: CustomScrollView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    slivers: friendsBodySlivers,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: buildMap(),
            ),
            if (!samsung)
              Positioned(
                  top: 10 + (kIsDesktop ? appWindow.titleBarHeight : MediaQuery.of(context).padding.top),
                  left: 20,
                  child: Container(
                    width: 48,
                    height: 48,
                    child: buildBackButton(context, padding: const EdgeInsets.only(right: 2)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.properSurface.withOpacity(0.9),
                    ),
                  )),
            if (!samsung && canRefresh)
              Positioned(
                top: 10 + (kIsDesktop ? appWindow.titleBarHeight : MediaQuery.of(context).padding.top),
                right: 20,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.properSurface.withOpacity(0.9),
                  ),
                  child: Container(
                    width: 48,
                    child: refreshing || refreshing2
                        ? buildProgressIndicator(context)
                        : IconButton(
                            iconSize: 22,
                            icon: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh,
                                color: context.theme.colorScheme.onBackground, size: 22),
                            onPressed: () {
                              setState(() {
                                refreshing = true;
                                refreshing2 = true;
                              });
                              getLocations(refreshDevices: true);
                            },
                          ),
                  ),
                ),
              ),
            if (kIsDesktop)
              SizedBox(
                height: appWindow.titleBarHeight,
                child: AbsorbPointer(
                  child: Row(children: [
                    Expanded(child: Container()),
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaY: 2, sigmaX: 2),
                        child: Container(
                            height: appWindow.titleBarHeight,
                            width: appWindow.titleBarButtonSize.width * 3,
                            color: context.theme.colorScheme.properSurface.withOpacity(0.5)),
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index.value,
          backgroundColor: headerColor,
          destinations: [
            NavigationDestination(
              icon: Icon(iOS ? CupertinoIcons.device_desktop : Icons.devices),
              label: "DEVICES",
            ),
            NavigationDestination(
              icon: Icon(iOS ? CupertinoIcons.tag : Icons.label_outline),
              label: "ITEMS",
            ),
            NavigationDestination(
              icon: Icon(iOS ? CupertinoIcons.person_2 : Icons.person),
              label: "FRIENDS",
            ),
          ],
          onDestinationSelected: (page) {
            final selectedCurrentTab = index.value == page;
            index.value = page;
            tabController.animateTo(page);

            // Switching tabs should not change the panel's expansion state.
            // Tapping the selected tab still toggles the panel.
            if (!selectedCurrentTab) return;
            if (panelController.isPanelOpen) {
              panelController.close();
            } else {
              panelController.open();
            }
          },
        ),
      ),
    );
  }

  Widget buildSamsungAppBar(BuildContext context, String title) {
    final actions = [
      if (canRefresh)
        Container(
          width: 48,
          height: 48,
          child: Container(
            width: 48,
            margin: const EdgeInsets.only(right: 8),
            child: refreshing || refreshing2
                ? buildProgressIndicator(context)
                : IconButton(
                    iconSize: 22,
                    icon: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh,
                        color: context.theme.colorScheme.onBackground, size: 22),
                    onPressed: () {
                      setState(() {
                        refreshing = true;
                        refreshing2 = true;
                      });
                      getLocations(refreshDevices: true);
                    },
                  ),
          ),
        ),
    ];

    return SliverAppBar(
      backgroundColor: headerColor,
      pinned: true,
      stretch: true,
      expandedHeight: context.height / 3,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          var expandRatio = (constraints.maxHeight - 50) / (context.height / 3 - 50);

          if (expandRatio > 1.0) expandRatio = 1.0;
          if (expandRatio < 0.0) expandRatio = 0.0;
          final animation = AlwaysStoppedAnimation<double>(expandRatio);

          return Stack(
            fit: StackFit.expand,
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
                )),
                child: Center(
                    child: Text(title,
                        style: context.theme.textTheme.displaySmall!
                            .copyWith(color: context.theme.colorScheme.onBackground),
                        textAlign: TextAlign.center)),
              ),
              FadeTransition(
                opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
                )),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.only(left: 40),
                    height: 50,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: context.theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    height: 50,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: buildBackButton(context),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  height: 50,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildMap() {
    var lastLocation = ss.settings.lastLocation.value?.split(",");
    var savedLocation = lastLocation != null ? LatLng(double.parse(lastLocation[0]), double.parse(lastLocation[1])) : const LatLng(0, 0);
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialZoom: location == null ? 14.0 : 15.0,
        minZoom: 1.0,
        maxZoom: 18.0,
        initialCenter: location == null ? savedLocation : LatLng(location!.latitude, location!.longitude),
        onTap: (_, __) => popupController.hideAllPopups(),
        // Hide popup when the map is tapped.
        keepAlive: true,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.bluebubbles.app',
        ),
        PopupMarkerLayer(
          options: PopupMarkerLayerOptions(
            onPopupEvent: (ev, m) async {
              if (m.isEmpty || fmfClient == null) return;
              final key = (m.first.key as ValueKey?)?.value?.toString();
              if (key == null || !key.startsWith("friend-")) return;

              final friendKeyValue = key.replaceFirst("friend-", "");
              final friend = friends.firstWhereOrNull((item) => friendKey(item) == friendKeyValue);
              if (friend == null) return;
              await api.selectFriend(
                config: pushService.state!.osConfig,
                client: fmfClient!,
                friend: friend.id,
              );
            },
            popupController: popupController,
            markers: markers.values.toList(),
            popupDisplayOptions: PopupDisplayOptions(
              builder: (context, marker) {
                final ValueKey? key = marker.key as ValueKey?;
                final keyValue = key?.value?.toString();
                if (keyValue == null || keyValue == "current") return const SizedBox();
                if (keyValue.startsWith("device-")) {
                  final prefix = keyValue.replaceFirst("device-", "");
                  final item = devices.firstWhereOrNull((item) => deviceKey(item) == prefix);
                  if (item == null) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: context.theme.colorScheme.properSurface.withOpacity(0.8),
                      ),
                      padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ss.settings.redactedMode.value ? (item.isConsideredAccessory ? "Item" : "Device") : (item.name ?? (item.isConsideredAccessory ? "Unknown Item" : "Unknown Device")), style: context.theme.textTheme.labelLarge),
                              Text(ss.settings.redactedMode.value ? "Location" : (item.location?.latitude != null ? "${item.location?.latitude}, ${item.location?.longitude}" : ""),
                                  style: context.theme.textTheme.bodySmall),
                              if (item.batteryStatus != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.battery_alert, size: 14, color: context.theme.colorScheme.error),
                                    const SizedBox(width: 4),
                                    Text(item.batteryStatus!, style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.error)),
                                  ],
                                ),
                            ],
                          ),
                          if (item.location?.latitude != null && item.location?.longitude != null)
                          ButtonTheme(
                            minWidth: 1,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                shape: const CircleBorder(),
                                backgroundColor: context.theme.colorScheme.primaryContainer,
                              ),
                              onPressed: () async {
                                await MapsLauncher.launchCoordinates(item.location!.latitude!, item.location!.longitude!);
                              },
                              child: const Icon(
                                  Icons.directions,
                                  size: 20
                              ),
                            ),
                          )
                        ],
                      )
                    ),
                  );
                } else if (keyValue.startsWith("friend-")) {
                  final prefix = keyValue.replaceFirst("friend-", "");
                  final item = friends.firstWhereOrNull((item) => friendKey(item) == prefix);
                  if (item == null) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: context.theme.colorScheme.properSurface.withOpacity(0.8),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.handle?.displayName ?? item.title ?? "Unknown Friend",
                              style: context.theme.textTheme.labelLarge),
                          Text(ss.settings.redactedMode.value ? "Location" : (item.longAddress ?? "No location found"), style: context.theme.textTheme.bodySmall),
                          if (item.lastUpdated != null && item.status != LocationStatus.live)
                            Text("Last updated ${buildDate(item.lastUpdated)}", style: context.theme.textTheme.bodySmall),
                          if (item.status != null)
                            Text("${item.status!.name.capitalize!} Location", style: context.theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      ],
    );
  }
}
