import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';

class PhoneService {
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  int _batteryLevel = 85;
  bool _isCharging = false;
  String _connectionType = 'wifi';
  bool _isWalking = false;
  double _batteryTemperature = 25.0;

  int get batteryLevel => _batteryLevel;
  bool get isCharging => _isCharging;
  String get connectionType => _connectionType;
  bool get isWalking => _isWalking;
  double get batteryTemperature => _batteryTemperature;
  bool get isOverheating => _batteryTemperature > 40;
  bool get isSevereOverheating => _batteryTemperature > 45;

  StreamSubscription? _batterySub;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _accelSub;

  Timer? _tempInferTimer;
  bool _isDemoMode = false;

  void startMonitoring({bool demoMode = false}) {
    _isDemoMode = demoMode;
    if (demoMode) {
      _startDemoSimulation();
      return;
    }
    _startBatteryMonitoring();
    _startConnectivityMonitoring();
    _startMotionDetection();
    _startTemperatureInference();
  }

  void _startBatteryMonitoring() {
    _battery.onBatteryStateChanged.listen((BatteryState state) {
      _isCharging = state == BatteryState.charging || state == BatteryState.full;
    });
    _battery.batteryLevel.then((level) => _batteryLevel = level);
  }

  void _startConnectivityMonitoring() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.wifi)) {
        _connectionType = 'wifi';
      } else if (results.contains(ConnectivityResult.mobile)) {
        _connectionType = 'data';
      } else {
        _connectionType = 'none';
      }
    });
  }

  void _startMotionDetection() {
    _accelSub = accelerometerEventStream().listen((event) {
      final magnitude = (event.x * event.x + event.y * event.y + event.z * event.z);
      _isWalking = magnitude > 120 && magnitude < 200;
    });
  }

  void _startTemperatureInference() {
    _tempInferTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _inferTemperature();
    });
  }

  void _inferTemperature() {
    // 推断温度: 充电中温度会上升
    if (_isCharging) {
      _batteryTemperature = (_batteryTemperature + 0.5).clamp(25.0, 50.0);
    } else {
      _batteryTemperature = (_batteryTemperature - 0.3).clamp(20.0, 45.0);
    }
    // 低电量时温度可能升高
    if (_batteryLevel < 20) {
      _batteryTemperature += 0.2;
    }
  }

  void _startDemoSimulation() {
    Timer.periodic(const Duration(seconds: 10), (_) {
      _batteryLevel = 50 + (DateTime.now().second % 50);
      _connectionType = ['wifi', 'data', 'none'][DateTime.now().second % 3];
      _isCharging = DateTime.now().second % 4 == 0;
      _isWalking = DateTime.now().second % 5 == 0;
      _batteryTemperature = 25 + (DateTime.now().second % 20).toDouble();
    });
  }

  void stopMonitoring() {
    _batterySub?.cancel();
    _connectivitySub?.cancel();
    _accelSub?.cancel();
    _tempInferTimer?.cancel();
  }
}
