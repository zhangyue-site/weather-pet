import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/weather.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../widgets/weather_effects.dart';
import '../widgets/hud_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  WeatherData _weather = WeatherData();
  PetState _petState = PetState.idle;
  bool _isDemoMode = true;
  bool _isLoading = true;
  int _batteryPercent = 85;
  int _signalStrength = 4;
  double _animTime = 0;
  String _currentAnim = 'assets/animations/idle.json';

  late AnimationController _timeController;
  late AnimationController _bounceController;
  late AnimationController _shakeController;
  Timer? _weatherTimer;
  Timer? _stateTimer;

  final List<String> _demoWeathers = [
    'clear', 'cloudy', 'overcast', 'rain', 'heavy_rain',
    'thunderstorm', 'snow', 'heavy_snow', 'fog', 'windy',
  ];
  int _demoIndex = 0;

  @override
  void initState() {
    super.initState();
    _timeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _timeController.addListener(() {
      setState(() {
        _animTime += 0.016;
      });
    });

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);

    _initApp();
  }

  Future<void> _initApp() async {
    await _loadWeather();
    _startTimers();
    setState(() => _isLoading = false);
  }

  Future<void> _loadWeather() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final weather = await WeatherService.fetchWeather(
          position.longitude,
          position.latitude,
        );
        setState(() {
          _weather = weather;
          _isDemoMode = false;
        });
      } else {
        _startDemoMode();
      }
    } catch (e) {
      _startDemoMode();
    }
  }

  void _startDemoMode() {
    setState(() => _isDemoMode = true);
    _demoIndex = 0;
    _updateDemoWeather();
  }

  void _updateDemoWeather() {
    if (!_isDemoMode) return;
    final condition = _demoWeathers[_demoIndex % _demoWeathers.length];
    const temps = {
      'clear': 24.0, 'cloudy': 21.0, 'overcast': 18.0,
      'rain': 16.0, 'heavy_rain': 14.0, 'thunderstorm': 13.0,
      'snow': -2.0, 'heavy_snow': -5.0, 'fog': 10.0, 'windy': 19.0,
    };
    setState(() {
      _weather = WeatherData(
        condition: condition,
        temperature: temps[condition] ?? 22.0,
        humidity: 50.0,
        windSpeed: 5.0,
        cityName: '北京',
      );
    });
    _demoIndex++;
  }

  void _startTimers() {
    _weatherTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_isDemoMode) _updateDemoWeather();
    });
    _scheduleNextState();
  }

  void _scheduleNextState() {
    final delay = 5 + Random().nextInt(8);
    _stateTimer = Timer(Duration(seconds: delay), () {
      _updatePetState();
      _scheduleNextState();
    });
  }

  void _updatePetState() {
    final hour = DateTime.now().hour;
    final w = _weather;

    PetState newState;
    String animFile;

    if (w.isStormy) {
      newState = PetState.stormScared;
      animFile = 'assets/animations/idle.json';
    } else if (w.isRaining) {
      newState = PetState.rainUmbrella;
      animFile = 'assets/animations/idle.json';
    } else if (w.isSnowing) {
      newState = Random().nextBool() ? PetState.snowCatch : PetState.snowFight;
      animFile = 'assets/animations/wave.json';
    } else if (w.isFoggy) {
      newState = PetState.fogWander;
      animFile = 'assets/animations/idle.json';
    } else if (w.isWindy) {
      newState = PetState.windLean;
      animFile = 'assets/animations/idle.json';
    } else if (w.isHot) {
      newState = PetState.hotMelt;
      animFile = 'assets/animations/idle.json';
    } else if (w.isCold) {
      newState = PetState.coldShiver;
      animFile = 'assets/animations/idle.json';
    } else if (hour < 6) {
      newState = PetState.sleeping;
      animFile = 'assets/animations/sleep.json';
    } else if (hour < 8) {
      newState = PetState.idle;
      animFile = 'assets/animations/idle.json';
    } else if (hour < 12) {
      newState = PetState.walking;
      animFile = 'assets/animations/idle.json';
    } else if (hour < 14) {
      newState = PetState.eating;
      animFile = 'assets/animations/idle.json';
    } else if (hour < 18) {
      newState = PetState.walking;
      animFile = 'assets/animations/idle.json';
    } else if (hour < 20) {
      newState = PetState.phoneScroll;
      animFile = 'assets/animations/idle.json';
    } else {
      newState = PetState.sleeping;
      animFile = 'assets/animations/sleep.json';
    }

    setState(() {
      _petState = newState;
      _currentAnim = animFile;
    });
  }

  void _onPetTap() {
    setState(() {
      _petState = Random().nextBool() ? PetState.waving : PetState.jumping;
      _currentAnim = _petState == PetState.waving
          ? 'assets/animations/wave.json'
          : 'assets/animations/jump.json';
    });
    _bounceController.forward(from: 0);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _updatePetState();
    });
  }

  void _onPetLongPress() {
    setState(() {
      _petState = PetState.playDead;
      _currentAnim = 'assets/animations/idle.json';
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _updatePetState();
    });
  }

  void _onPetDoubleTap() {
    setState(() {
      _petState = PetState.spinning;
      _currentAnim = 'assets/animations/wave.json';
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _updatePetState();
    });
  }

  @override
  void dispose() {
    _timeController.dispose();
    _bounceController.dispose();
    _shakeController.dispose();
    _weatherTimer?.cancel();
    _stateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 天气背景特效
          WeatherEffectsWidget(
            weather: _weather,
            time: _animTime,
          ),

          // 城市背景
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildCityScape(),
          ),

          // 小人 (Lottie 动画)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: GestureDetector(
                onTap: _onPetTap,
                onLongPress: _onPetLongPress,
                onDoubleTap: _onPetDoubleTap,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_bounceController, _shakeController]),
                  builder: (context, child) {
                    double offsetY = 0;
                    double offsetX = 0;

                    // 弹跳效果
                    if (_bounceController.isAnimating) {
                      offsetY = -_bounceController.value * 30 * (1 - _bounceController.value);
                    }

                    // 状态特效
                    switch (_petState) {
                      case PetState.stormScared:
                        offsetX = sin(_animTime * 20) * 5;
                        break;
                      case PetState.coldShiver:
                        offsetX = sin(_animTime * 15) * 3;
                        break;
                      case PetState.windLean:
                        offsetX = -8;
                        break;
                      case PetState.jumping:
                        offsetY = -(sin(_animTime * 4)).abs() * 40;
                        break;
                      default:
                        offsetY = sin(_animTime * 1.5) * 2;
                    }

                    return Transform.translate(
                      offset: Offset(offsetX, offsetY),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: Lottie.asset(
                          _currentAnim,
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 道具叠加 (雨伞等)
          if (_petState == PetState.rainUmbrella)
            _buildUmbrellaOverlay(),

          // HUD
          HudWidget(
            weather: _weather,
            petState: _petState,
            batteryPercent: _batteryPercent,
            signalStrength: _signalStrength,
            isDemoMode: _isDemoMode,
            onDemoToggle: () {
              if (_isDemoMode) {
                _loadWeather();
              } else {
                _startDemoMode();
              }
            },
          ),

          // 加载指示器
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // 演示模式按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () {
                if (_isDemoMode) {
                  _loadWeather();
                } else {
                  _startDemoMode();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isDemoMode
                      ? const Color(0xFFFFD93D).withOpacity(0.8)
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  _isDemoMode ? '🎮 演示' : '📍 GPS',
                  style: TextStyle(
                    color: _isDemoMode ? Colors.black87 : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUmbrellaOverlay() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: CustomPaint(
          size: const Size(160, 100),
          painter: UmbrellaPainter(time: _animTime),
        ),
      ),
    );
  }

  Widget _buildCityScape() {
    return CustomPaint(
      size: Size(MediaQuery.of(context).size.width, 180),
      painter: CityScapePainter(isNight: DateTime.now().hour < 6 || DateTime.now().hour >= 20),
    );
  }
}

class UmbrellaPainter extends CustomPainter {
  final double time;
  UmbrellaPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 伞面
    final umbrellaPath = Path()
      ..moveTo(cx - 60, cy)
      ..quadraticBezierTo(cx, cy - 50, cx + 60, cy)
      ..close();
    canvas.drawPath(umbrellaPath, Paint()..color = const Color(0xFF5B9BD5));
    canvas.drawPath(
      umbrellaPath,
      Paint()..color = const Color(0xFF3A7BD5)..style = PaintingStyle.stroke..strokeWidth = 2,
    );

    // 伞柄
    canvas.drawLine(
      Offset(cx, cy - 35),
      Offset(cx, cy + 40),
      Paint()..color = const Color(0xFF8B6914)..strokeWidth = 3,
    );

    // 伞钩
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + 7, cy + 40), width: 14, height: 14),
      -pi / 2, pi, false,
      Paint()..color = const Color(0xFF8B6914)..style = PaintingStyle.stroke..strokeWidth = 3,
    );

    // 雨滴
    final dropPaint = Paint()..color = const Color(0xFF6CB4EE).withOpacity(0.5);
    for (int i = 0; i < 5; i++) {
      final dx = cx - 45 + i * 22;
      final dy = cy + 5 + sin(time * 6 + i * 1.5) * 8;
      canvas.drawOval(Rect.fromCenter(center: Offset(dx, dy), width: 3, height: 7), dropPaint);
    }
  }

  @override
  bool shouldRepaint(covariant UmbrellaPainter old) => true;
}

class CityScapePainter extends CustomPainter {
  final bool isNight;
  CityScapePainter({required this.isNight});

  @override
  void paint(Canvas canvas, Size size) {
    // 地面
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      Paint()..color = isNight ? const Color(0xFF0D1117) : const Color(0xFF2D5016),
    );

    // 建筑
    final buildingPaint = Paint()
      ..color = isNight ? const Color(0xFF1A1A2E) : const Color(0xFF4A5568);
    final windowPaint = Paint()..color = const Color(0xFFFFD93D).withOpacity(0.7);
    final random = Random(42);
    double x = 0;

    while (x < size.width) {
      final w = 30 + random.nextDouble() * 50;
      final h = 60 + random.nextDouble() * 100;
      final y = size.height * 0.7 - h;

      canvas.drawRect(Rect.fromLTWH(x, y, w, h), buildingPaint);

      if (isNight) {
        for (int row = 0; row < (h / 20).floor(); row++) {
          for (int col = 0; col < (w / 15).floor(); col++) {
            if (random.nextBool()) {
              canvas.drawRect(
                Rect.fromLTWH(x + 5 + col * 15, y + 8 + row * 20, 8, 10),
                windowPaint,
              );
            }
          }
        }
      }

      x += w + random.nextDouble() * 15;
    }
  }

  @override
  bool shouldRepaint(covariant CityScapePainter old) => false;
}
