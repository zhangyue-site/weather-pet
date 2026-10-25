import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather.dart';

/// 本地天气缓存：启动先显示上次数据，网络回来再刷新（双端通用）
class WeatherCache {
  static const String _key = 'weather_cache_v1';

  static Future<void> save(WeatherData w) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, json.encode(w.toJson()));
    } catch (_) {}
  }

  static Future<WeatherData?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final map = json.decode(raw);
      if (map is! Map<String, dynamic>) return null;
      return WeatherData.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

/// 天气数据源: Open-Meteo (免 key, 非商用免费, 无每人额度)
/// 城市名: 系统地理编码 (iOS CLGeocoder / Android 系统 Geocoder), 免 key
/// 原和风天气 key 已下线 (曾暴露于公开仓库, 建议在和风后台停用)
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// 逆地理只查城市名(与天气接口独立, 失败返回 '未知')
  static Future<String> reverseCityName(double lon, double lat) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon)
          .timeout(const Duration(seconds: 8));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final name =
            p.locality ?? p.subAdministrativeArea ?? p.administrativeArea;
        if (name != null && name.isNotEmpty) return name;
      }
    } catch (_) {}
    return '未知';
  }

  /// 天气+城市名一起取: 并发请求；逆地理失败时沿用缓存城市名
  static Future<WeatherData> fetchWeatherWithCity(double lon, double lat) async {
    final cached = await WeatherCache.load();
    final results = await Future.wait([
      reverseCityName(lon, lat),
      fetchWeather(lon, lat),
    ]);
    final city = results[0] as String;
    final weather = results[1] as WeatherData;
    if (city != '未知' && city.isNotEmpty) {
      weather.cityName = city;
    } else if (cached != null &&
        cached.cityName != '定位中…' && cached.cityName != '未知') {
      weather.cityName = cached.cityName;
    }
    return weather;
  }

  static Future<WeatherData> fetchWeather(double lon, double lat) async {
    try {
      final url = '$_baseUrl?latitude=${lat.toStringAsFixed(4)}'
          '&longitude=${lon.toStringAsFixed(4)}'
          '&current=temperature_2m,relative_humidity_2m,apparent_temperature,'
          'weather_code,wind_speed_10m'
          '&wind_speed_unit=kmh&timezone=auto';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return WeatherData();

      final data = json.decode(response.body);
      final now = data['current'];
      if (now == null) return WeatherData();

      final windKmh = double.tryParse('${now['wind_speed_10m']}') ?? 5.0;
      var condition =
          _mapWmoCode(int.tryParse('${now['weather_code']}') ?? 0);
      // 晴天但风大 (>= 39km/h) 表现为大风
      if (condition == 'clear' && windKmh >= 39) condition = 'windy';

      final weather = WeatherData(
        condition: condition,
        temperature: double.tryParse('${now['temperature_2m']}') ?? 22.0,
        humidity: double.tryParse('${now['relative_humidity_2m']}') ?? 50.0,
        windSpeed: windKmh,
        feelsLike: double.tryParse('${now['apparent_temperature']}') ?? 22.0,
      );
      await WeatherCache.save(weather);
      return weather;
    } catch (e) {
      return WeatherData();
    }
  }

  static Future<String> fetchCityName(double lon, double lat) =>
      reverseCityName(lon, lat);

  /// WMO weather code -> condition (与 weather.dart 的 condition 枚举对齐)
  static String _mapWmoCode(int code) {
    if (code == 0) return 'clear';
    if (code <= 2) return 'cloudy';
    if (code == 3) return 'overcast';
    if (code == 45 || code == 48) return 'fog';
    if (code >= 51 && code <= 57) return 'drizzle';
    if (code >= 61 && code <= 67) return code >= 66 ? 'heavy_rain' : 'rain';
    if (code >= 71 && code <= 77) return code == 75 ? 'heavy_snow' : 'snow';
    if (code >= 80 && code <= 82) return code == 82 ? 'heavy_rain' : 'rain';
    if (code == 85 || code == 86) return code == 86 ? 'heavy_snow' : 'snow';
    if (code >= 95) return 'thunderstorm';
    return 'clear';
  }
}
