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
  String _currentState = 'idle';

  String _mapStateToAnimation(PetState state) {
    const stateMap = {
      PetState.idle: 'idle',
      PetState.walking: 'walk',
      PetState.sleeping: 'sleep',
      PetState.eating: 'eat',
      PetState.waving: 'wave',
      PetState.jumping: 'jump',
      PetState.spinning: 'spin',
      PetState.fogWander: 'walk',
      PetState.festival: 'wave',
    };
    return stateMap[state] ?? 'idle';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onDoubleTap: widget.onDoubleTap,
      child: SizedBox(
        width: 200,
        height: 200,
        child: RiveAnimation.asset(
          'assets/rive/cat2.riv',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
