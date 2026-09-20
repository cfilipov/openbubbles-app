import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
// it does actually export (Web only)
// ignore: undefined_hidden_name
import 'package:bluebubbles/database/models.dart' hide PlayerState;
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class AudioPlayer extends StatefulWidget {
  final PlatformFile file;
  final Attachment? attachment;
  final String? transcript;

  AudioPlayer({
    super.key,
    required this.file,
    required this.attachment,
    this.transcript,
    this.controller,
    this.playButtonFocusNode,
    this.nextFocusNode,
  });

  final ConversationViewController? controller;
  final FocusNode? playButtonFocusNode;
  final FocusNode? nextFocusNode;

  @override
  OptimizedState createState() =>
      kIsDesktop ? _DesktopAudioPlayerState() : _AudioPlayerState();
}

class _AudioPlayerState extends OptimizedState<AudioPlayer>
    with SingleTickerProviderStateMixin {
  Attachment? get attachment => widget.attachment;

  PlatformFile get file => widget.file;

  ConversationViewController? get cvController => widget.controller;

  PlayerController? controller;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<int>? _currentDurationSubscription;
  StreamSubscription<void>? _completionSubscription;
  int _currentDuration = 0;
  late final animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      animationBehavior: AnimationBehavior.preserve);

  @override
  void initState() {
    super.initState();
    updateObx(() {
      initBytes();
    });
  }

  @override
  void dispose() {
    final guid = attachment?.guid;
    if (guid != null &&
        identical(cvController?.audioPlayers[guid], controller)) {
      cvController?.audioPlayers.remove(guid);
    }
    _playerStateSubscription?.cancel();
    _currentDurationSubscription?.cancel();
    _completionSubscription?.cancel();
    controller?.dispose();
    controller = null;
    animController.dispose();
    super.dispose();
  }

  Future<void> initBytes() async {
    if (controller == null) {
      controller = PlayerController()
        ..addListener(() {
          if (!mounted) return;
          setState(() {});
        });
      _playerStateSubscription =
          controller!.onPlayerStateChanged.listen((event) {
        if (!mounted) return;
        if ((controller!.playerState == PlayerState.paused ||
                controller!.playerState == PlayerState.stopped) &&
            animController.value > 0) {
          animController.reverse();
        }
        setState(() {});
      });
      _currentDurationSubscription =
          controller!.onCurrentDurationChanged.listen((duration) {
        if (!mounted) return;
        final maxDuration = controller?.maxDuration ?? 0;
        _currentDuration = maxDuration > 0
            ? duration.clamp(0, maxDuration).toInt()
            : (duration < 0 ? 0 : duration);
        setState(() {});
      });
      _completionSubscription = controller!.onCompletion.listen((_) {
        if (!mounted) return;
        _currentDuration = controller?.maxDuration ?? 0;
        setState(() {});
      });
      await controller!.preparePlayer(path: file.path!);
      if (!mounted) {
        await _playerStateSubscription?.cancel();
        controller?.dispose();
        controller = null;
        return;
      }
      if (attachment != null) {
        cvController?.audioPlayers[attachment!.guid!] = controller!;
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final maxDuration = controller?.maxDuration ?? 0;
    final currentDuration = maxDuration > 0
        ? _currentDuration.clamp(0, maxDuration).toInt()
        : 0;

    return Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.arrowRight):
                          () => widget.nextFocusNode?.requestFocus(),
                      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                          widget.nextFocusNode?.requestFocus(),
                      const SingleActivator(LogicalKeyboardKey.enter):
                          () async {
                        if (controller == null) return;
                        if (controller!.playerState == PlayerState.playing) {
                          animController.reverse();
                          await controller!.pausePlayer();
                        } else {
                          animController.forward();
                          controller!
                              .setFinishMode(finishMode: FinishMode.pause);
                          await controller!.startPlayer();
                        }
                        if (!mounted) return;
                        setState(() {});
                      },
                      const SingleActivator(LogicalKeyboardKey.select):
                          () async {
                        if (controller == null) return;
                        if (controller!.playerState == PlayerState.playing) {
                          animController.reverse();
                          await controller!.pausePlayer();
                        } else {
                          animController.forward();
                          controller!
                              .setFinishMode(finishMode: FinishMode.pause);
                          await controller!.startPlayer();
                        }
                        if (!mounted) return;
                        setState(() {});
                      },
                      const SingleActivator(LogicalKeyboardKey.space):
                          () async {
                        if (controller == null) return;
                        if (controller!.playerState == PlayerState.playing) {
                          animController.reverse();
                          await controller!.pausePlayer();
                        } else {
                          animController.forward();
                          controller!
                              .setFinishMode(finishMode: FinishMode.pause);
                          await controller!.startPlayer();
                        }
                        if (!mounted) return;
                        setState(() {});
                      },
                    },
                    child: IconButton(
                      focusNode: widget.playButtonFocusNode,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.focused)
                                ? context.theme.colorScheme.outline
                                    .withOpacity(0.2)
                                : null),
                      ),
                      onPressed: () async {
                        if (controller == null) return;
                        if (controller!.playerState == PlayerState.playing) {
                          animController.reverse();
                          await controller!.pausePlayer();
                        } else {
                          animController.forward();
                          controller!
                              .setFinishMode(finishMode: FinishMode.pause);
                          await controller!.startPlayer();
                        }
                        if (!mounted) return;
                        setState(() {});
                      },
                      icon: AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: animController,
                      ),
                      color: context.theme.colorScheme.properOnSurface,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: context.theme.colorScheme.properOnSurface,
                        inactiveTrackColor: context.theme.colorScheme.properSurface.oppositeLightenOrDarken(20),
                        thumbColor: context.theme.colorScheme.properOnSurface,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: currentDuration.toDouble(),
                        min: 0,
                        max: maxDuration > 0 ? maxDuration.toDouble() : 1,
                        onChanged: controller != null && maxDuration > 0
                            ? (value) {
                                _currentDuration = value.round();
                                setState(() {});
                                unawaited(controller!.seekTo(_currentDuration));
                              }
                            : null,
                        semanticFormatterCallback: (value) => prettyDuration(
                            Duration(milliseconds: value.round())),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    flex: 2,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "${prettyDuration(Duration(milliseconds: currentDuration))} / ${prettyDuration(Duration(milliseconds: maxDuration > 0 ? maxDuration : 0))}",
                        maxLines: 1,
                        style: context.theme.textTheme.labelLarge!,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.transcript != null)
                Padding(
                  padding: const EdgeInsets.only(
                      top: 5, left: 10, right: 10, bottom: 5),
                  child: Text(
                    "${widget.transcript}",
                    style: context.theme.textTheme.bodySmall,
                  ),
                ),
            ]));
  }
}

class _DesktopAudioPlayerState extends OptimizedState<AudioPlayer>
    with SingleTickerProviderStateMixin {
  Attachment? get attachment => widget.attachment;

  PlatformFile get file => widget.file;

  ConversationViewController? get cvController => widget.controller;

  Player? controller;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _completedSubscription;
  Future<void>? _initialization;
  bool _isDisposed = false;
  late final animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      animationBehavior: AnimationBehavior.preserve);

  @override
  void initState() {
    super.initState();
    updateObx(() {
      _initialization = initBytes();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    final ownedController = controller;
    final guid = attachment?.guid;
    if (guid != null &&
        identical(cvController?.audioPlayersDesktop[guid], controller)) {
      cvController?.audioPlayersDesktop.remove(guid);
    }
    _positionSubscription?.cancel();
    _completedSubscription?.cancel();
    if (ownedController != null) {
      unawaited(_disposePlayer(ownedController));
    }
    controller = null;
    animController.dispose();
    super.dispose();
  }

  Future<void> initBytes() async {
    if (controller == null) {
      controller = Player();
      _positionSubscription = controller!.stream.position.listen((position) {
        if (!mounted) return;
        setState(() {});
      });
      _completedSubscription =
          controller!.stream.completed.listen((bool completed) async {
        if (completed) {
          await controller!.pause();
          await controller!.seek(Duration.zero);
          if (!mounted) return;
          animController.reverse();
        }
        if (!mounted) return;
        setState(() {});
      });
      await controller!.setPlaylistMode(PlaylistMode.none);
      if (_isDisposed) return;
      await controller!.open(Media(file.path!), play: false);
      if (!mounted || _isDisposed) return;
      if (attachment != null) {
        cvController?.audioPlayersDesktop[attachment!.guid!] = controller!;
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _disposePlayer(Player player) async {
    final initialization = _initialization;
    if (initialization != null) {
      try {
        await initialization;
      } catch (_) {
        // Disposal must still run when native initialization fails.
      }
    }
    await player.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    widget.nextFocusNode?.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                    widget.nextFocusNode?.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.enter): () async {
                  if (controller == null) return;
                  if (controller!.state.playing) {
                    animController.reverse();
                    await controller!.pause();
                  } else {
                    animController.forward();
                    await controller!.play();
                  }
                  if (!mounted) return;
                  setState(() {});
                },
                const SingleActivator(LogicalKeyboardKey.select): () async {
                  if (controller == null) return;
                  if (controller!.state.playing) {
                    animController.reverse();
                    await controller!.pause();
                  } else {
                    animController.forward();
                    await controller!.play();
                  }
                  if (!mounted) return;
                  setState(() {});
                },
                const SingleActivator(LogicalKeyboardKey.space): () async {
                  if (controller == null) return;
                  if (controller!.state.playing) {
                    animController.reverse();
                    await controller!.pause();
                  } else {
                    animController.forward();
                    await controller!.play();
                  }
                  if (!mounted) return;
                  setState(() {});
                },
              },
              child: IconButton(
                focusNode: widget.playButtonFocusNode,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.focused)
                          ? context.theme.colorScheme.outline.withOpacity(0.2)
                          : null),
                ),
                onPressed: () async {
                  if (controller == null) return;
                  if (controller!.state.playing) {
                    animController.reverse();
                    await controller!.pause();
                  } else {
                    animController.forward();
                    await controller!.play();
                  }
                  if (!mounted) return;
                  setState(() {});
                },
                icon: AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: animController,
                ),
                color: context.theme.colorScheme.properOnSurface,
                visualDensity: VisualDensity.compact,
              ),
            ),
            if (controller != null)
              SizedBox(
                height: 30,
                child: Slider(
                  value: controller!.state.position.inSeconds.toDouble(),
                  onChanged: (double value) {
                    controller!.seek(Duration(seconds: value.toInt()));
                  },
                  min: 0,
                  max: controller!.state.duration.inSeconds.toDouble(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 16),
              child: Text(
                  "${prettyDuration(controller?.state.position ?? Duration.zero)} / ${prettyDuration(controller?.state.duration ?? Duration.zero)}"),
            )
          ],
        ));
  }
}
