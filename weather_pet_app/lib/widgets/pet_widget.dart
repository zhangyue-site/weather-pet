import 'dart:math';
import 'package:flutter/material.dart';
import '../models/weather.dart';

class PetWidget extends StatefulWidget {
  final PetState state;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  const PetWidget({
    super.key,
    required this.state,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
  });

  @override
  State<PetWidget> createState() => _PetWidgetState();
}

class _PetWidgetState extends State<PetWidget>
    with TickerProviderStateMixin {
  late AnimationController _main;
  late AnimationController _breath;
  late AnimationController _blink;
  late AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _main = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _scheduleBlink();
  }

  void _scheduleBlink() {
    Future.delayed(Duration(seconds: 2 + Random().nextInt(4)), () {
      if (mounted) {
        _blink.forward().then((_) {
          _blink.reverse().then((_) => _scheduleBlink());
        });
      }
    });
  }

  @override
  void dispose() {
    _main.dispose();
    _breath.dispose();
    _blink.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _bounce.forward(from: 0);
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress,
      onDoubleTap: widget.onDoubleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_main, _breath, _blink, _bounce]),
        builder: (context, _) {
          return CustomPaint(
            size: const Size(180, 260),
            painter: _PetPainter(
              state: widget.state,
              t: _main.value,
              breath: _breath.value,
              blink: _blink.value,
              bounce: _bounce.value,
            ),
          );
        },
      ),
    );
  }
}

class _PetPainter extends CustomPainter {
  final PetState state;
  final double t;
  final double breath;
  final double blink;
  final double bounce;

  _PetPainter({
    required this.state,
    required this.t,
    required this.breath,
    required this.blink,
    required this.bounce,
  });

  static const _bodyTop = Color(0xFFFFE066);
  static const _bodyBottom = Color(0xFFFFB347);
  static const _bodyHighlight = Color(0xFFFFF2CC);
  static const _cheek = Color(0xFFFF9999);
  static const _armColor = Color(0xFFE8A020);
  static const _footColor = Color(0xFFD4940A);
  static const _eyeColor = Color(0xFF2D2D2D);
  static const _noseColor = Color(0xFFFF8888);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseY = size.height / 2 - 10;

    canvas.save();

    // 状态位移
    _applyStateTransform(canvas, cx, baseY);

    // 呼吸
    final breathOff = breath * 2.5;
    canvas.translate(0, breathOff);

    // 弹跳
    if (bounce > 0) {
      canvas.translate(0, -bounce * 20 * (1 - bounce));
    }

    _drawShadow(canvas, cx, baseY + 100);
    _drawFeet(canvas, cx, baseY + 85);
    _drawBody(canvas, cx, baseY);
    _drawArms(canvas, cx, baseY + 10);
    _drawHead(canvas, cx, baseY - 55);
    _drawFace(canvas, cx, baseY - 55);

    if (state == PetState.rainUmbrella) {
      _drawUmbrella(canvas, cx, baseY - 90);
    }
    if (state == PetState.snowCatch) {
      _drawSnowflakes(canvas, cx, baseY - 70);
    }
    if (state == PetState.phoneScroll) {
      _drawPhone(canvas, cx, baseY + 20);
    }

    canvas.restore();
  }

  void _applyStateTransform(Canvas c, double cx, double baseY) {
    final angle = t * pi * 2;
    switch (state) {
      case PetState.walking:
        c.translate(sin(angle * 2) * 3, 0);
        break;
      case PetState.sleeping:
        c.translate(0, sin(angle * 0.3) * 1.5);
        break;
      case PetState.jumping:
        c.translate(0, -(sin(angle * 2)).abs() * 40);
        break;
      case PetState.waving:
        break;
      case PetState.spinning:
        c.translate(cx, baseY);
        c.rotate(angle * 1.5);
        c.translate(-cx, -baseY);
        break;
      case PetState.stormScared:
        c.translate(sin(angle * 8) * 4, 0);
        break;
      case PetState.coldShiver:
        c.translate(sin(angle * 10) * 2, sin(angle * 7) * 1);
        break;
      case PetState.hotMelt:
        c.translate(0, min(angle * 0.3, 12.0));
        c.scale(1, 1 + min(angle * 0.01, 0.08));
        break;
      case PetState.windLean:
        c.translate(-6, 0);
        c.rotate(-0.08);
        break;
      case PetState.fogWander:
        c.translate(sin(angle * 0.4) * 5, cos(angle * 0.25) * 2);
        break;
      case PetState.playDead:
        c.translate(0, 8);
        c.scale(1, 0.75);
        break;
      default:
        c.translate(0, sin(angle * 0.5) * 1.5);
    }
  }

  void _drawShadow(Canvas c, double cx, double y) {
    c.drawOval(
      Rect.fromCenter(center: Offset(cx, y), width: 70, height: 14),
      Paint()..color = Colors.black.withOpacity(0.12),
    );
  }

  void _drawBody(Canvas c, double cx, double cy) {
    // 身体主体
    final bodyRect = Rect.fromCenter(center: Offset(cx, cy + 18), width: 72, height: 88);
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_bodyTop, _bodyBottom],
      ).createShader(bodyRect);
    c.drawOval(bodyRect, bodyPaint);

    // 身体高光
    c.drawOval(
      Rect.fromCenter(center: Offset(cx - 8, cy - 5), width: 28, height: 35),
      Paint()..color = _bodyHighlight.withOpacity(0.45),
    );

    // 肚皮
    c.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 25), width: 36, height: 30),
      Paint()..color = _bodyHighlight.withOpacity(0.3),
    );
  }

  void _drawHead(Canvas c, double cx, double cy) {
    // 头部
    final headRect = Rect.fromCenter(center: Offset(cx, cy - 8), width: 80, height: 76);
    final headPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_bodyHighlight, _bodyTop],
      ).createShader(headRect);
    c.drawOval(headRect, headPaint);

    // 头部光晕
    c.drawOval(
      Rect.fromCenter(center: Offset(cx - 15, cy - 22), width: 25, height: 20),
      Paint()..color = Colors.white.withOpacity(0.35),
    );

    // 左耳
    c.drawOval(
      Rect.fromCenter(center: Offset(cx - 28, cy - 40), width: 18, height: 22),
      Paint()..color = _bodyTop,
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(cx - 28, cy - 40), width: 10, height: 14),
      Paint()..color = _cheek.withOpacity(0.3),
    );

    // 右耳
    c.drawOval(
      Rect.fromCenter(center: Offset(cx + 28, cy - 40), width: 18, height: 22),
      Paint()..color = _bodyTop,
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(cx + 28, cy - 40), width: 10, height: 14),
      Paint()..color = _cheek.withOpacity(0.3),
    );
  }

  void _drawFace(Canvas c, double cx, double cy) {
    // 眼睛
    if (state == PetState.sleeping) {
      _drawSleepingEyes(c, cx, cy);
    } else if (state == PetState.stormScared) {
      _drawScaredEyes(c, cx, cy);
    } else if (state == PetState.coldShiver) {
      _drawShiverEyes(c, cx, cy);
    } else {
      _drawNormalEyes(c, cx, cy);
    }

    // 腮红
    c.drawOval(
      Rect.fromCenter(center: Offset(cx - 26, cy - 2), width: 16, height: 10),
      Paint()..color = _cheek.withOpacity(0.35 + breath * 0.1),
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(cx + 26, cy - 2), width: 16, height: 10),
      Paint()..color = _cheek.withOpacity(0.35 + breath * 0.1),
    );

    // 鼻子
    c.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 2), width: 6, height: 4),
      Paint()..color = _noseColor.withOpacity(0.7),
    );

    // 嘴巴
    _drawMouth(c, cx, cy + 10);
  }

  void _drawNormalEyes(Canvas c, double cx, double cy) {
    final eyeScale = 1.0 - blink * 0.9;
    // 左眼
    c.drawOval(
      Rect.fromCenter(center: Offset(cx - 14, cy - 6), width: 8, height: 10 * eyeScale),
      Paint()..color = _eyeColor,
    );
    // 右眼
    c.drawOval(
      Rect.fromCenter(center: Offset(cx + 14, cy - 6), width: 8, height: 10 * eyeScale),
      Paint()..color = _eyeColor,
    );
    if (eyeScale > 0.5) {
      // 眼睛高光
      c.drawCircle(Offset(cx - 12, cy - 9), 2.5, Paint()..color = Colors.white);
      c.drawCircle(Offset(cx + 16, cy - 9), 2.5, Paint()..color = Colors.white);
      // 小高光
      c.drawCircle(Offset(cx - 15, cy - 4), 1.2, Paint()..color = Colors.white.withOpacity(0.6));
      c.drawCircle(Offset(cx + 13, cy - 4), 1.2, Paint()..color = Colors.white.withOpacity(0.6));
    }
  }

  void _drawSleepingEyes(Canvas c, double cx, double cy) {
    final eyePaint = Paint()
      ..color = _eyeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    c.drawArc(
      Rect.fromCenter(center: Offset(cx - 14, cy - 6), width: 12, height: 8),
      0.2, pi - 0.4, false, eyePaint,
    );
    c.drawArc(
      Rect.fromCenter(center: Offset(cx + 14, cy - 6), width: 12, height: 8),
      0.2, pi - 0.4, false, eyePaint,
    );
    // ZZZ
    final tp = TextPainter(
      text: TextSpan(
        text: 'z',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12 + breath * 4,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx + 30, cy - 30 - breath * 15));
  }

  void _drawScaredEyes(Canvas c, double cx, double cy) {
    c.drawCircle(Offset(cx - 14, cy - 6), 7, Paint()..color = Colors.white);
    c.drawCircle(Offset(cx + 14, cy - 6), 7, Paint()..color = Colors.white);
    c.drawCircle(Offset(cx - 14, cy - 6), 4.5, Paint()..color = _eyeColor);
    c.drawCircle(Offset(cx + 14, cy - 6), 4.5, Paint()..color = _eyeColor);
    c.drawCircle(Offset(cx - 12, cy - 8), 2, Paint()..color = Colors.white);
    c.drawCircle(Offset(cx + 16, cy - 8), 2, Paint()..color = Colors.white);
  }

  void _drawShiverEyes(Canvas c, double cx, double cy) {
    final xPaint = Paint()
      ..color = _eyeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final dx in [-14.0, 14.0]) {
      c.drawLine(Offset(cx + dx - 3, cy - 9), Offset(cx + dx + 3, cy - 3), xPaint);
      c.drawLine(Offset(cx + dx - 3, cy - 3), Offset(cx + dx + 3, cy - 9), xPaint);
    }
  }

  void _drawMouth(Canvas c, double cx, double cy) {
    final mouthPaint = Paint()
      ..color = _eyeColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    switch (state) {
      case PetState.eating:
        c.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: 10, height: 8),
          Paint()..color = const Color(0xFFFF6B6B),
        );
        break;
      case PetState.stormScared:
        c.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: 8, height: 10),
          Paint()..color = _eyeColor,
        );
        break;
      case PetState.sleeping:
        c.drawArc(
          Rect.fromCenter(center: Offset(cx, cy - 2), width: 8, height: 5),
          0, pi, false, mouthPaint,
        );
        break;
      case PetState.waving:
      case PetState.jumping:
      case PetState.spinning:
      case PetState.festival:
        // 开心大嘴
        c.drawArc(
          Rect.fromCenter(center: Offset(cx, cy - 3), width: 18, height: 14),
          0.1, pi - 0.2, false, mouthPaint,
        );
        break;
      default:
        c.drawArc(
          Rect.fromCenter(center: Offset(cx, cy - 3), width: 14, height: 9),
          0.15, pi - 0.3, false, mouthPaint,
        );
    }
  }

  void _drawArms(Canvas c, double cx, double cy) {
    final armPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_armColor, _footColor],
      ).createShader(Rect.fromLTWH(0, 0, 20, 40));

    double leftAngle = 0.25;
    double rightAngle = -0.25;
    final a = t * pi * 2;

    switch (state) {
      case PetState.waving:
        rightAngle = -0.8 - sin(a * 3) * 0.5;
        break;
      case PetState.rainUmbrella:
        leftAngle = -1.3;
        break;
      case PetState.snowFight:
        rightAngle = -0.5 - sin(a * 4) * 0.4;
        break;
      case PetState.spinning:
        leftAngle = a * 2;
        rightAngle = -a * 2;
        break;
      case PetState.eating:
        leftAngle = -0.5;
        rightAngle = 0.5;
        break;
      default:
        leftAngle = 0.25 + sin(a * 0.5) * 0.04;
        rightAngle = -0.25 - sin(a * 0.5) * 0.04;
    }

    // 左臂
    c.save();
    c.translate(cx - 36, cy);
    c.rotate(leftAngle);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-7, 0, 14, 36), const Radius.circular(7)),
      armPaint,
    );
    c.restore();

    // 右臂
    c.save();
    c.translate(cx + 36, cy);
    c.rotate(rightAngle);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-7, 0, 14, 36), const Radius.circular(7)),
      armPaint,
    );
    c.restore();
  }

  void _drawFeet(Canvas c, double cx, double cy) {
    final footPaint = Paint()
      ..shader = const LinearGradient(
        colors: [_armColor, _footColor],
      ).createShader(Rect.fromLTWH(0, 0, 24, 12));

    final walkOff = state == PetState.walking ? sin(t * pi * 4) * 4.0 : 0.0;

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 18, cy + walkOff), width: 24, height: 12),
        const Radius.circular(6),
      ),
      footPaint,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 18, cy - walkOff), width: 24, height: 12),
        const Radius.circular(6),
      ),
      footPaint,
    );
  }

  void _drawUmbrella(Canvas c, double cx, double cy) {
    // 伞面
    final umbrellaPath = Path()
      ..moveTo(cx - 55, cy)
      ..quadraticBezierTo(cx, cy - 45, cx + 55, cy)
      ..close();
    c.drawPath(umbrellaPath, Paint()..color = const Color(0xFF5B9BD5));
    c.drawPath(
      umbrellaPath,
      Paint()
        ..color = const Color(0xFF3A7BD5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // 伞柄
    c.drawLine(Offset(cx, cy - 30), Offset(cx, cy + 50),
        Paint()..color = const Color(0xFF8B6914)..strokeWidth = 3);
    // 伞钩
    c.drawArc(
      Rect.fromCenter(center: Offset(cx + 7, cy + 50), width: 14, height: 14),
      -pi / 2, pi, false,
      Paint()..color = const Color(0xFF8B6914)..style = PaintingStyle.stroke..strokeWidth = 3,
    );
    // 雨滴
    final dropPaint = Paint()..color = const Color(0xFF6CB4EE).withOpacity(0.5);
    for (int i = 0; i < 5; i++) {
      final dx = cx - 40 + i * 20;
      final dy = cy + 5 + sin(t * pi * 2 + i) * 8;
      c.drawOval(Rect.fromCenter(center: Offset(dx, dy), width: 3, height: 6), dropPaint);
    }
  }

  void _drawSnowflakes(Canvas c, double cx, double cy) {
    final snowPaint = Paint()..color = Colors.white.withOpacity(0.8);
    for (int i = 0; i < 6; i++) {
      final angle = t * pi * 2 + i * pi / 3;
      final r = 30 + sin(angle * 0.5) * 10;
      final x = cx + cos(angle) * r;
      final y = cy + sin(angle) * r * 0.5 - 20;
      c.drawCircle(Offset(x, y), 3 + sin(angle) * 1, snowPaint);
    }
  }

  void _drawPhone(Canvas c, double cx, double cy) {
    final phonePaint = Paint()..color = const Color(0xFF333333);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 5, cy), width: 18, height: 28),
        const Radius.circular(3),
      ),
      phonePaint,
    );
    c.drawRect(
      Rect.fromCenter(center: Offset(cx + 5, cy - 2), width: 14, height: 20),
      Paint()..color = const Color(0xFF66BBFF),
    );
  }

  @override
  bool shouldRepaint(covariant _PetPainter old) => true;
}
