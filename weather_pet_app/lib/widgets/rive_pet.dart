import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import '../models/weather.dart';

class RivePet extends StatefulWidget {
  final PetState state;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  const RivePet({
    super.key,
    required this.state,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
  });

  @override
  State<RivePet> createState() => _RivePetState();
}

class _RivePetState extends State<RivePet> {
  RiveAnimationController? _controller;
  Artboard? _artboard;
  String _currentState = 'idle';

  @override
  void initState() {
    super.initState();
    _loadAnimation();
  }

  void _loadAnimation() {
    try {
      final file = RiveFile.asset('assets/rive/cat2.riv');
      _artboard = file.mainArtboard;
      _controller = SimpleAnimation('idle', autoplay: true);
      _artboard!.addController(_controller!);
    } catch (e) {
      // 如果 Rive 加载失败，回退到 Lottie
    }
  }

  @override
  void didUpdateWidget(RivePet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (_artboard == null || _controller == null) return;

    String newState = _mapStateToAnimation(widget.state);
    if (newState != _currentState) {
      _currentState = newState;
      _controller!.dispose();
      _controller = SimpleAnimation(newState, autoplay: true);
      _artboard!.addController(_controller!);
    }
  }

  String _mapStateToAnimation(PetState state) {
    // Rive 动画名称映射
    // 如果 cat2.riv 有对应的状态动画就用，没有就用 idle
    const stateMap = {
      PetState.idle: 'idle',
      PetState.walking: 'walk',
      PetState.sleeping: 'sleep',
      PetState.eating: 'eat',
      PetState.waving: 'wave',
      PetState.jumping: 'jump',
      PetState.spinning: 'spin',
      PetState.rainUmbrella: 'idle',
      PetState.stormScared: 'idle',
      PetState.snowCatch: 'idle',
      PetState.snowFight: 'idle',
      PetState.coldShiver: 'idle',
      PetState.hotMelt: 'idle',
      PetState.windLean: 'idle',
      PetState.fogWander: 'walk',
      PetState.playDead: 'idle',
      PetState.phoneScroll: 'idle',
      PetState.festival: 'wave',
      PetState.lowBattery: 'idle',
      PetState.overcastIdle: 'idle',
    };
    return stateMap[state] ?? 'idle';
  }

  @override
  Widget build(BuildContext context) {
    if (_artboard == null) {
      // Rive 加载失败时的回退
      return const SizedBox(
        width: 200,
        height: 200,
        child: Center(
          child: Icon(Icons.pets, size: 100, color: Colors.amber),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onDoubleTap: widget.onDoubleTap,
      child: SizedBox(
        width: 200,
        height: 200,
        child: RiveAnimation.artboard(
          _artboard!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
