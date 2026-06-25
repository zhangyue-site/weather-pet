import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/weather.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../widgets/pet_widget.dart';
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

  late AnimationController _timeController;
  late AnimationController _stateController;
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

    _stateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

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
        final cityName = await WeatherService.fetchCityName(
          position.longitude,
          position.latitude,
        );
        setState(() {
          _weather = WeatherData(
            condition: weather.condition,
            temperature: weather.temperature,
            humidity: weather.humidity,
            windSpeed: weather.windSpeed,
            cityName: cityName,
            feelsLike: weather.feelsLike,
          );
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
    // 每 8 秒切换天气 (演示模式)
    _weatherTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_isDemoMode) _updateDemoWeather();
    });

    // 每 5-12 秒切换小人状态
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

    if (w.isStormy) {
      newState = PetState.stormScared;
    } else if (w.isRaining) {
      newState = PetState.rainUmbrella;
    } else if (w.isSnowing) {
      newState = Random().nextBool() ? PetState.snowCatch : PetState.snowFight;
    } else if (w.isFoggy) {
      newState = PetState.fogWander;
    } else if (w.isWindy) {
      newState = PetState.windLean;
    } else if (w.isHot) {
      newState = PetState.hotMelt;
    } else if (w.isCold) {
      newState = PetState.coldShiver;
    } else if (hour < 6) {
      newState = PetState.sleeping;
    } else if (hour < 8) {
      newState = PetState.idle;
    } else if (hour < 12) {
      newState = PetState.walking;
    } else if (hour < 14) {
      newState = PetState.eating;
    } else if (hour < 18) {
      newState = PetState.walking;
    } else if (hour < 20) {
      newState = PetState.phoneScroll;
    } else {
      newState = PetState.sleeping;
    }

    setState(() => _petState = newState);
  }

  void _onPetTap() {
    setState(() {
      _petState = Random().nextBool() ? PetState.waving : PetState.jumping;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _updatePetState();
    });
  }

  void _onPetLongPress() {
    setState(() => _petState = PetState.playDead);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _updatePetState();
    });
  }

  void _onPetDoubleTap() {
    setState(() => _petState = PetState.spinning);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _updatePetState();
    });
  }

  @override
  void dispose() {
    _timeController.dispose();
    _stateController.dispose();
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

          // 小人
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: PetWidget(
                state: _petState,
                onTap: _onPetTap,
                onLongPress: _onPetLongPress,
                onDoubleTap: _onPetDoubleTap,
              ),
            ),
          ),

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
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
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

  Widget _buildCityScape() {
    return CustomPaint(
      size: Size(MediaQuery.of(context).size.width, 200),
      painter: CityScapePainter(isNight: DateTime.now().hour < 6 || DateTime.now().hour >= 20),
    );
  }
}

class CityScapePainter extends CustomPainter {
  final bool isNight;

  CityScapePainter({required this.isNight});

  @override
  void paint(Canvas canvas, Size size) {
    final groundPaint = Paint()
      ..color = isNight ? const Color(0xFF0D1117) : const Color(0xFF2D5016);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      groundPaint,
    );

    final buildingPaint = Paint()
      ..color = isNight ? const Color(0xFF1A1A2E) : const Color(0xFF4A5568);

    final random = Random(42);
    double x = 0;
    while (x < size.width) {
      final w = 30 + random.nextDouble() * 50;
      final h = 60 + random.nextDouble() * 100;
      final y = size.height * 0.7 - h;

      canvas.drawRect(Rect.fromLTWH(x, y, w, h), buildingPaint);

      // 窗户
      if (isNight) {
        final windowPaint = Paint()
          ..color = const Color(0xFFFFD93D).withOpacity(0.7);
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
  bool shouldRepaint(covariant CityScapePainter oldDelegate) => false;
}
