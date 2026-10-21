import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather.dart';

class WeatherService {
  static const String _apiKey = 'be785dbd3cab4f0d9cc27b3d8a1f3de3';
  static const String _host = 'nv5vxkv2bh.re.qweatherapi.com';
  static const String _baseUrl = 'https://$_host';

  /// 逆地理只查城市名(与天气接口独立, 失败返回 '未知')
  static Future<String> reverseCityName(double lon, double lat) async {
    try {
      final coord = '${lon.toStringAsFixed(4)},${lat.toStringAsFixed(4)}';
      final response = await http.get(
        Uri.parse('$_baseUrl/geo/v2/city/lookup?location=$coord&lang=zh'),
        headers: {'X-QW-Api-Key': _apiKey},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return '未知';
      final data = json.decode(response.body);
      final locations = data['location'];
      if (locations == null || locations.isEmpty) return '未知';
      final loc = locations[0];
      final adm2 = loc['adm2'];
      if (adm2 is String && adm2.isNotEmpty) return adm2;
      return loc['name'] ?? '未知';
    } catch (e) {
      return '未知';
    }
  }

  /// 天气+城市名一起取: 城市名优先独立逆地理结果, 失败时用天气接口自带兜底
  static Future<WeatherData> fetchWeatherWithCity(double lon, double lat) async {
    final results = await Future.wait([
      reverseCityName(lon, lat),
      fetchWeather(lon, lat),
    ]);
    final city = results[0] as String;
    final weather = results[1] as WeatherData;
    if (city != '未知' && city.isNotEmpty) weather.cityName = city;
    return weather;
  }

  static Future<WeatherData> fetchWeather(double lon, double lat) async {
    try {
      final coord = '${lon.toStringAsFixed(4)},${lat.toStringAsFixed(4)}';
      final url = '$_baseUrl/v7/weather/now?location=$coord&lang=zh';
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-QW-Api-Key': _apiKey},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return WeatherData();

      final data = json.decode(response.body);
      if (data['code'] != '200') return WeatherData();

      final now = data['now'];
      final iconCode = now['icon'] ?? '100';
      final condition = _mapIconCode(iconCode);

      // 同时获取城市名
      final cityName = await fetchCityName(lon, lat);

      return WeatherData(
        condition: condition,
        temperature: double.tryParse(now['temp'] ?? '22') ?? 22.0,
        humidity: double.tryParse(now['humidity'] ?? '50') ?? 50.0,
        windSpeed: double.tryParse(now['windSpeed'] ?? '5') ?? 5.0,
        feelsLike: double.tryParse(now['feelsLike'] ?? '22') ?? 22.0,
        cityName: cityName,
      );
    } catch (e) {
      return WeatherData();
    }
  }

  static Future<String> fetchCityName(double lon, double lat) async {
    try {
      final coord = '${lon.toStringAsFixed(4)},${lat.toStringAsFixed(4)}';
      final url = '$_baseUrl/geo/v2/city/lookup?location=$coord&lang=zh';
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-QW-Api-Key': _apiKey},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return '未知';

      final data = json.decode(response.body);
      final locations = data['location'];
      if (locations == null || locations.isEmpty) return '未知';

      return locations[0]['adm2'] ?? locations[0]['name'] ?? '未知';
    } catch (e) {
      return '未知';
    }
  }

  static String _mapIconCode(String code) {
    const map = {
      '100': 'clear', '150': 'clear',
      '101': 'cloudy', '102': 'cloudy', '103': 'cloudy',
      '151': 'cloudy', '152': 'cloudy', '153': 'cloudy',
      '104': 'overcast', '154': 'overcast',
      '300': 'drizzle', '301': 'drizzle',
      '302': 'thunderstorm', '303': 'thunderstorm', '304': 'thunderstorm',
      '305': 'rain', '309': 'rain', '314': 'rain', '315': 'rain',
      '306': 'rain', '313': 'rain', '316': 'rain', '317': 'rain', '318': 'rain',
      '307': 'heavy_rain', '308': 'heavy_rain', '310': 'heavy_rain',
      '311': 'heavy_rain', '312': 'heavy_rain', '350': 'heavy_rain',
      '351': 'heavy_rain', '399': 'heavy_rain',
      '400': 'snow', '407': 'snow', '408': 'snow', '409': 'snow', '456': 'snow',
      '401': 'heavy_snow', '402': 'heavy_snow', '403': 'heavy_snow',
      '404': 'heavy_snow', '405': 'heavy_snow', '406': 'heavy_snow',
      '410': 'heavy_snow', '457': 'heavy_snow', '499': 'heavy_snow',
      '500': 'fog', '501': 'fog',
      '502': 'haze', '503': 'haze', '504': 'haze',
      '507': 'sandstorm', '508': 'sandstorm',
      '902': 'windy',
    };
    return map[code] ?? 'clear';
  }
}
