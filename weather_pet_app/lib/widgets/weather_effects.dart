import 'dart:math';
import 'package:flutter/material.dart';
import '../models/weather.dart';

class WeatherEffectsWidget extends StatelessWidget {
  final WeatherData weather;
  final double time;

  const WeatherEffectsWidget({
    super.key,
    required this.weather,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: WeatherEffectsPainter(
        weather: weather,
        time: time,
      ),
    );
  }
}

class WeatherEffectsPainter extends CustomPainter {
  final WeatherData weather;
  final double time;

  WeatherEffectsPainter({required this.weather, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    if (weather.isRaining || weather.isStormy) {
      _drawRain(canvas, size);
    }
    if (weather.isSnowing) {
      _drawSnow(canvas, size);
    }
    if (weather.isFoggy) {
      _drawFog(canvas, size);
    }
    _drawSkyGradient(canvas, size);
  }

  void _drawSkyGradient(Canvas canvas, Size size) {
    final hour = DateTime.now().hour;
    List<Color> colors;

    if (hour < 6 || hour >= 20) {
      colors = [const Color(0xFF0A0A2E), const Color(0xFF1A1A4E)];
    } else if (hour < 8) {
      colors = [const Color(0xFF4A6FA5), const Color(0xFFE8956D)];
    } else if (hour < 18) {
      colors = [const Color(0xFF87CEEB), const Color(0xFFB0E0E6)];
    } else {
      colors = [const Color(0xFF4A6FA5), const Color(0xFFFF8C69)];
    }

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.6),
      Paint()..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.6),
      ),
    );
  }

  void _drawRain(Canvas canvas, Size size) {
    final rainPaint = Paint()
      ..color = const Color(0xFF6CB4EE).withOpacity(0.6)
      ..strokeWidth = 1.5;

    final random = Random(42);
    for (int i = 0; i < 80; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 200 + random.nextDouble() * 150;
      final y = (baseY + time * speed) % size.height;

      canvas.drawLine(
        Offset(x, y),
        Offset(x - 2, y + 12),
        rainPaint,
      );
    }
  }

  void _drawSnow(Canvas canvas, Size size) {
    final snowPaint = Paint()..color = Colors.white.withOpacity(0.8);
    final random = Random(42);

    for (int i = 0; i < 40; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 30 + random.nextDouble() * 40;
      final drift = sin(time * 0.5 + i) * 20;
      final x = (baseX + drift) % size.width;
      final y = (baseY + time * speed) % size.height;
      final radius = 2 + random.nextDouble() * 3;

      canvas.drawCircle(Offset(x, y), radius, snowPaint);
    }
  }

  void _drawFog(Canvas canvas, Size size) {
    final fogPaint = Paint()
      ..color = const Color(0xFFCCCCCC).withOpacity(0.3);

    for (int i = 0; i < 5; i++) {
      final x = sin(time * 0.2 + i * 1.5) * size.width * 0.3 + size.width * 0.5;
      final y = size.height * (0.2 + i * 0.12);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 300, height: 40),
        fogPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeatherEffectsPainter oldDelegate) => true;
}
