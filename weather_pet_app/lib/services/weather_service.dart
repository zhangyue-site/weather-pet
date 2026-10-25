import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import '../models/weather.dart';

/// 天气数据源: Open-Meteo (免 key, 非商用免费, 无每人额度焦虑)
/// 城市名: 系统地理编码 (iOS CLGeocoder / Android 系统 Geocoder), 免 key
/// 原和风天气 key 已整体下线 (公共仓库曾暴露, 建议在和风后台停用)
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

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
      // 晴天但风大 (>= 39km/h, 8级) 表现为大风
      if (condition == 'clear' && windKmh >= 39) condition = 'windy';

      return WeatherData(
        condition: condition,
        temperature: double.tryParse('${now['temperature_2m']}') ?? 22.0,
        humidity: double.tryParse('${now['relative_humidity_2m']}') ?? 50.0,
        windSpeed: windKmh,
        feelsLike: double.tryParse('${now['apparent_temperature']}') ?? 22.0,
        cityName: await _cityName(lon, lat),
      );
    } catch (e) {
      return WeatherData();
    }
  }

  static Future<String> _cityName(double lon, double lat) async {
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
    return '当前位置';
  }

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
