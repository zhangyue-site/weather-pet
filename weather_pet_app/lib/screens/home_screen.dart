import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/weather.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  WeatherData _weather = WeatherData();
  PetState _petState = PetState.idle;
  bool _isDemoMode = true;
  bool _isFastDemo = false;
  bool _isLoading = true;

  String _catAnim = 'assets/animations/cat1.json';
  String _weatherAnim = 'assets/animations/weather_clear.json';
  bool _showWeatherOverlay = false;

  // 演示模式的时间 (模拟)
  int _demoHour = 8;
  int _demoMinute = 0;
  String _demoPeriod = '上午';

  late AnimationController _timeCtrl;
  late AnimationController _bounceCtrl;
  Timer? _stateTimer;
  Timer? _fastDemoTimer;
  double _animTime = 0;

  int _demoIndex = 0;
  int _catIndex = 0;

  // 完整演示场景: 天气 × 时间 × 猫咪动作
  static const _demoScenes = [
    // === 早晨 ===
    {'hour': 6, 'min': 30, 'weather': 'clear', 'temp': 18.0, 'cat': 1, 'state': 'idle', 'label': '🌅 清晨晴天'},
    {'hour': 7, 'min': 0, 'weather': 'clear', 'temp': 20.0, 'cat': 2, 'state': 'eating', 'label': '🍳 早餐时间'},
    {'hour': 7, 'min': 30, 'weather': 'cloudy', 'temp': 19.0, 'cat': 3, 'state': 'walking', 'label': '⛅ 多云散步'},
    // === 上午 ===
    {'hour': 9, 'min': 0, 'weather': 'clear', 'temp': 24.0, 'cat': 4, 'state': 'walking', 'label': '☀️ 上午晴天'},
    {'hour': 10, 'min': 0, 'weather': 'drizzle', 'temp': 20.0, 'cat': 5, 'state': 'rainUmbrella', 'label': '🌦 小雨撑伞'},
    {'hour': 11, 'min': 0, 'weather': 'rain', 'temp': 18.0, 'cat': 6, 'state': 'rainUmbrella', 'label': '🌧 中雨撑伞'},
    // === 中午 ===
    {'hour': 12, 'min': 0, 'weather': 'clear', 'temp': 28.0, 'cat': 7, 'state': 'eating', 'label': '🍽 午饭时间'},
    {'hour': 13, 'min': 0, 'weather': 'clear', 'temp': 32.0, 'cat': 1, 'state': 'idle', 'label': '☀️ 午后晴'},
    // === 下午 ===
    {'hour': 14, 'min': 0, 'weather': 'heavy_rain', 'temp': 16.0, 'cat': 2, 'state': 'stormScared', 'label': '🌧 大雨害怕'},
    {'hour': 15, 'min': 0, 'weather': 'thunderstorm', 'temp': 14.0, 'cat': 3, 'state': 'stormScared', 'label': '⛈ 雷暴发抖'},
    {'hour': 16, 'min': 0, 'weather': 'snow', 'temp': -2.0, 'cat': 4, 'state': 'snowCatch', 'label': '❄️ 下雪接雪花'},
    {'hour': 17, 'min': 0, 'weather': 'fog', 'temp': 10.0, 'cat': 5, 'state': 'fogWander', 'label': '🌫 雾中溜达'},
    // === 傍晚 ===
    {'hour': 18, 'min': 0, 'weather': 'clear', 'temp': 22.0, 'cat': 6, 'state': 'idle', 'label': '🌇 傍晚晴'},
    {'hour': 19, 'min': 0, 'weather': 'wind', 'temp': 15.0, 'cat': 7, 'state': 'windLean', 'label': '💨 大风吹'},
    // === 夜晚 ===
    {'hour': 20, 'min': 0, 'weather': 'clear', 'temp': 12.0, 'cat': 1, 'state': 'idle', 'label': '🌙 晚上晴'},
    {'hour': 21, 'min': 0, 'weather': 'clear', 'temp': 10.0, 'cat': 2, 'state': 'sleeping', 'label': '😴 夜深了'},
    {'hour': 23, 'min': 0, 'weather': 'clear', 'temp': 8.0, 'cat': 3, 'state': 'sleeping', 'label': '🌙 深夜'},
    // === 极端天气 ===
    {'hour': 12, 'min': 0, 'weather': 'clear', 'temp': 38.0, 'cat': 4, 'state': 'hotMelt', 'label': '🥵 热化了'},
    {'hour': 12, 'min': 0, 'weather': 'clear', 'temp': 2.0, 'cat': 5, 'state': 'coldShiver', 'label': '🥶 冷得发抖'},
    {'hour': 12, 'min': 0, 'weather': 'haze', 'temp': 15.0, 'cat': 6, 'state': 'fogWander', 'label': '🌫 霾天'},
    // === 互动 ===
    {'hour': 12, 'min': 0, 'weather': 'clear', 'temp': 22.0, 'cat': 7, 'state': 'waving', 'label': '👋 招手'},
    {'hour': 12, 'min': 0, 'weather': 'clear', 'temp': 22.0, 'cat': 1, 'state': 'jumping', 'label': '🤸 跳跃'},
    {'hour': 12, 'min': 0, 'weather': 'clear', 'temp': 22.0, 'cat': 2, 'state': 'spinning', 'label': '🌀 转圈'},
    {'hour': 12, 'min': 0, 'weather': 'clear', 'temp': 22.0, 'cat': 3, 'state': 'playDead', 'label': '💫 趴下'},
  ];

  @override
  void initState() {
    super.initState();
    _timeCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _timeCtrl.addListener(() => setState(() => _animTime += 0.016));
    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
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
        final weather = await WeatherService.fetchWeather(position.longitude, position.latitude);
        setState(() { _weather = weather; _isDemoMode = false; });
      } else {
        _startDemoMode();
      }
    } catch (e) {
      _startDemoMode();
    }
  }

  void _startDemoMode() {
    setState(() { _isDemoMode = true; _isFastDemo = false; _demoIndex = 0; });
    _applyDemoScene();
    _stateTimer?.cancel();
    _stateTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_isFastDemo) _nextDemoScene();
    });
  }

  void _startFastDemo() {
    setState(() { _isFastDemo = true; _demoIndex = 0; });
    _applyDemoScene();
    _stateTimer?.cancel();
    _fastDemoTimer?.cancel();
    _fastDemoTimer = Timer.periodic(const Duration(seconds: 2), (_) => _nextDemoScene());
  }

  void _stopFastDemo() {
    _fastDemoTimer?.cancel();
    setState(() => _isFastDemo = false);
    _startDemoMode();
  }

  void _nextDemoScene() {
    _demoIndex = (_demoIndex + 1) % _demoScenes.length;
    _catIndex = (_catIndex + 1) % 7;
    _applyDemoScene();
  }

  void _applyDemoScene() {
    final scene = _demoScenes[_demoIndex];
    final hour = scene['hour'] as int;
    final minute = scene['min'] as int;
    final condition = scene['weather'] as String;
    final temp = scene['temp'] as double;
    final catNum = _catIndex + 1;
    final stateName = scene['state'] as String;

    String weatherAnim;
    bool showOverlay = true;
    switch (condition) {
      case 'clear':
        if (temp > 35) { weatherAnim = 'assets/animations/weather_clear_day.json'; }
        else if (hour < 6 || hour >= 20) { weatherAnim = 'assets/animations/weather_clear_night.json'; }
        else { weatherAnim = 'assets/animations/weather_clear.json'; showOverlay = false; }
        break;
      case 'cloudy': weatherAnim = 'assets/animations/weather_cloudy.json'; break;
      case 'rain': case 'heavy_rain': weatherAnim = 'assets/animations/weather_rain.json'; break;
      case 'drizzle': weatherAnim = 'assets/animations/weather_drizzle.json'; break;
      case 'thunderstorm': weatherAnim = 'assets/animations/weather_thunderstorm.json'; break;
      case 'snow': weatherAnim = 'assets/animations/weather_snow.json'; break;
      case 'fog': weatherAnim = 'assets/animations/weather_fog.json'; break;
      case 'wind': weatherAnim = 'assets/animations/weather_wind.json'; break;
      case 'haze': weatherAnim = 'assets/animations/weather_haze.json'; break;
      default: weatherAnim = 'assets/animations/weather_clear.json'; showOverlay = false;
    }

    String period;
    if (hour < 6) period = '凌晨';
    else if (hour < 11) period = '上午';
    else if (hour < 13) period = '中午';
    else if (hour < 18) period = '下午';
    else if (hour < 22) period = '傍晚';
    else period = '深夜';

    setState(() {
      _weather = WeatherData(condition: condition, temperature: temp, humidity: 50, windSpeed: 5, cityName: '北京');
      _demoHour = hour;
      _demoMinute = minute;
      _demoPeriod = period;
      _catAnim = 'assets/animations/cat$catNum.json';
      _weatherAnim = weatherAnim;
      _showWeatherOverlay = showOverlay;
      _petState = _stateFromName(stateName);
    });
  }

  PetState _stateFromName(String name) {
    const map = {
      'idle': PetState.idle, 'walking': PetState.walking, 'sleeping': PetState.sleeping,
      'eating': PetState.eating, 'waving': PetState.waving, 'jumping': PetState.jumping,
      'spinning': PetState.spinning, 'rainUmbrella': PetState.rainUmbrella,
      'stormScared': PetState.stormScared, 'snowCatch': PetState.snowCatch,
      'snowFight': PetState.snowFight, 'coldShiver': PetState.coldShiver,
      'hotMelt': PetState.hotMelt, 'windLean': PetState.windLean,
      'fogWander': PetState.fogWander, 'playDead': PetState.playDead,
    };
    return map[name] ?? PetState.idle;
  }

  void _startTimers() {
    _scheduleNextState();
  }

  void _scheduleNextState() {
    final delay = 5 + Random().nextInt(8);
    _stateTimer = Timer(Duration(seconds: delay), () {
      if (!_isDemoMode) _updatePetState();
      _scheduleNextState();
    });
  }

  void _updatePetState() {
    final hour = DateTime.now().hour;
    final w = _weather;
    PetState newState;

    if (w.isStormy) { newState = PetState.stormScared; }
    else if (w.isRaining) { newState = PetState.rainUmbrella; }
    else if (w.isSnowing) { newState = Random().nextBool() ? PetState.snowCatch : PetState.snowFight; }
    else if (w.isFoggy) { newState = PetState.fogWander; }
    else if (w.isWindy) { newState = PetState.windLean; }
    else if (w.isHot) { newState = PetState.hotMelt; }
    else if (w.isCold) { newState = PetState.coldShiver; }
    else if (hour < 6) { newState = PetState.sleeping; }
    else if (hour < 8) { newState = PetState.eating; }
    else if (hour < 12) { newState = PetState.walking; }
    else if (hour < 14) { newState = PetState.eating; }
    else if (hour < 18) { newState = PetState.walking; }
    else if (hour < 20) { newState = PetState.idle; }
    else { newState = PetState.sleeping; }

    setState(() {
      _petState = newState;
      _catAnim = 'assets/animations/cat${(_catIndex % 7) + 1}.json';
      _catIndex++;
    });
  }

  void _onPetTap() {
    setState(() {
      _petState = Random().nextBool() ? PetState.waving : PetState.jumping;
      _catAnim = 'assets/animations/cat${Random().nextInt(7) + 1}.json';
    });
    _bounceCtrl.forward(from: 0);
    Future.delayed(const Duration(seconds: 2), () { if (mounted && !_isDemoMode) _updatePetState(); });
  }

  void _onPetLongPress() {
    setState(() { _petState = PetState.playDead; _catAnim = 'assets/animations/cat5.json'; });
    Future.delayed(const Duration(seconds: 2), () { if (mounted && !_isDemoMode) _updatePetState(); });
  }

  void _onPetDoubleTap() {
    setState(() { _petState = PetState.spinning; _catAnim = 'assets/animations/cat3.json'; });
    Future.delayed(const Duration(seconds: 2), () { if (mounted && !_isDemoMode) _updatePetState(); });
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _bounceCtrl.dispose();
    _stateTimer?.cancel();
    _fastDemoTimer?.cancel();
    super.dispose();
  }

  // 天空颜色根据时间变化
  Color _skyTopColor() {
    final h = _isDemoMode ? _demoHour : DateTime.now().hour;
    if (h < 5) return const Color(0xFF0A0A2E);
    if (h < 7) return const Color(0xFF2A3A6E);
    if (h < 9) return const Color(0xFF5B8CC5);
    if (h < 17) return const Color(0xFF4A90D9);
    if (h < 19) return const Color(0xFFE87040);
    if (h < 21) return const Color(0xFF3A2A6E);
    return const Color(0xFF0A0A2E);
  }

  Color _skyBottomColor() {
    final h = _isDemoMode ? _demoHour : DateTime.now().hour;
    if (h < 5) return const Color(0xFF1A1A4E);
    if (h < 7) return const Color(0xFFE8956D);
    if (h < 9) return const Color(0xFFB0D4F1);
    if (h < 17) return const Color(0xFF87CEEB);
    if (h < 19) return const Color(0xFFFF8C49);
    if (h < 21) return const Color(0xFF1A1A3E);
    return const Color(0xFF1A1A4E);
  }

  bool _isNightTime() {
    final h = _isDemoMode ? _demoHour : DateTime.now().hour;
    return h < 6 || h >= 20;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 天空渐变 (随时间变化)
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_skyTopColor(), _skyBottomColor()],
              ),
            ),
          ),
          // 天气 Lottie 特效
          if (_showWeatherOverlay)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.5,
                  child: Lottie.asset(_weatherAnim, fit: BoxFit.cover, repeat: true, animate: true),
                ),
              ),
            ),
          // 星星 (夜晚)
          if (_isNightTime())
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _StarPainter(_animTime)))),
          // 月亮 (夜晚)
          if (_isNightTime())
            Positioned(
              top: 60, right: 40,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF5E6B8),
                  boxShadow: [BoxShadow(color: const Color(0xFFF5E6B8).withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                ),
              ),
            ),
          // 城市背景
          Positioned(bottom: 0, left: 0, right: 0, child: _buildCityScape()),
          // 猫咪
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: GestureDetector(
                onTap: _onPetTap,
                onLongPress: _onPetLongPress,
                onDoubleTap: _onPetDoubleTap,
                child: AnimatedBuilder(
                  animation: _bounceCtrl,
                  builder: (context, child) {
                    double offsetY = 0, offsetX = 0;
                    if (_bounceCtrl.isAnimating) {
                      offsetY = -_bounceCtrl.value * 30 * (1 - _bounceCtrl.value);
                    }
                    switch (_petState) {
                      case PetState.stormScared: offsetX = sin(_animTime * 20) * 5; break;
                      case PetState.coldShiver: offsetX = sin(_animTime * 15) * 3; break;
                      case PetState.windLean: offsetX = -8; break;
                      case PetState.jumping: offsetY = -(sin(_animTime * 4)).abs() * 40; break;
                      default: offsetY = sin(_animTime * 1.5) * 2;
                    }
                    return Transform.translate(
                      offset: Offset(offsetX, offsetY),
                      child: SizedBox(
                        width: 220, height: 220,
                        child: Lottie.asset(_catAnim, fit: BoxFit.contain, repeat: true, animate: true),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // HUD
          _buildHud(),
          // 加载
          if (_isLoading) const Center(child: CircularProgressIndicator(color: Colors.white)),
          // 顶部按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16, right: 16,
            child: Row(children: [
              _buildTopButton(
                _isDemoMode ? '🎮 演示' : '📍 GPS',
                _isDemoMode ? const Color(0xFFFFD93D) : Colors.white24,
                () { if (_isDemoMode) { _loadWeather(); } else { _startDemoMode(); } },
              ),
              const SizedBox(width: 8),
              if (_isDemoMode)
                _buildTopButton(
                  _isFastDemo ? '⏸ 停止快演' : '⚡ 快速演示',
                  _isFastDemo ? const Color(0xFFFF6B6B) : const Color(0xFF6BCB77),
                  () { if (_isFastDemo) { _stopFastDemo(); } else { _startFastDemo(); } },
                ),
              const Spacer(),
              if (_isDemoMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                  child: Text('${_demoIndex + 1}/${_demoScenes.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildTopButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Text(label, style: TextStyle(
          color: color == const Color(0xFFFFD93D) ? Colors.black87 : Colors.white,
          fontSize: 12, fontWeight: FontWeight.w600,
        )),
      ),
    );
  }

  Widget _buildHud() {
    final timeStr = _isDemoMode
        ? '${_demoHour.toString().padLeft(2, '0')}:${_demoMinute.toString().padLeft(2, '0')}'
        : '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    final period = _isDemoMode ? _demoPeriod : _timePeriod(DateTime.now().hour);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 36),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(timeStr, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w300, color: Colors.white)),
              Text('${_weather.cityName} · $period',
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6))),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${_weather.temperature.toStringAsFixed(0)}°',
                style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w200, color: Colors.white)),
              Text('${_weather.conditionIcon} ${_weather.conditionLabel}',
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6))),
            ]),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Text(_petState.label, style: const TextStyle(color: Colors.white, fontSize: 13)),
              Container(width: 1, height: 16, color: Colors.white.withOpacity(0.2)),
              Text('$_demoPeriod · ${_weather.conditionLabel}',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildCityScape() {
    return CustomPaint(
      size: Size(MediaQuery.of(context).size.width, 180),
      painter: _CityPainter(isNight: _isNightTime()),
    );
  }

  String _timePeriod(int hour) {
    if (hour < 6) return '凌晨'; if (hour < 11) return '上午'; if (hour < 13) return '中午';
    if (hour < 18) return '下午'; if (hour < 22) return '傍晚'; return '深夜';
  }
}

class _StarPainter extends CustomPainter {
  final double time;
  _StarPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final r = Random(42);
    for (int i = 0; i < 50; i++) {
      final x = r.nextDouble() * size.width;
      final y = r.nextDouble() * size.height * 0.5;
      final brightness = (sin(time * 1.5 + i * 0.7) + 1.0) * 0.5;
      final sz = 1.0 + r.nextDouble() * 2.0;
      paint.color = Color.fromRGBO(255, 255, 230, brightness * 0.7);
      canvas.drawCircle(Offset(x, y), sz, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => true;
}

class _CityPainter extends CustomPainter {
  final bool isNight;
  _CityPainter({required this.isNight});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      Paint()..color = isNight ? const Color(0xFF0D1117) : const Color(0xFF2D5016));
    final bPaint = Paint()..color = isNight ? const Color(0xFF1A1A2E) : const Color(0xFF4A5568);
    final wPaint = Paint()..color = const Color(0xFFFFD93D).withOpacity(0.7);
    final r = Random(42);
    double x = 0;
    while (x < size.width) {
      final w = 30 + r.nextDouble() * 50;
      final h = 60 + r.nextDouble() * 100;
      final y = size.height * 0.7 - h;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), bPaint);
      if (isNight) {
        for (int row = 0; row < (h / 20).floor(); row++) {
          for (int col = 0; col < (w / 15).floor(); col++) {
            if (r.nextBool()) canvas.drawRect(Rect.fromLTWH(x + 5 + col * 15, y + 8 + row * 20, 8, 10), wPaint);
          }
        }
      }
      x += w + r.nextDouble() * 15;
    }
  }

  @override
  bool shouldRepaint(covariant _CityPainter old) => false;
}
