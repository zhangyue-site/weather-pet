import 'package:flutter/material.dart';
import '../models/weather.dart';

class HudWidget extends StatelessWidget {
  final WeatherData weather;
  final PetState petState;
  final int batteryPercent;
  final int signalStrength;
  final bool isDemoMode;
  final VoidCallback? onDemoToggle;

  const HudWidget({
    super.key,
    required this.weather,
    required this.petState,
    this.batteryPercent = 85,
    this.signalStrength = 4,
    this.isDemoMode = false,
    this.onDemoToggle,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部: 时间 + 温度
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左: 时间 + 城市
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${weather.cityName} · ${_timePeriod(now.hour)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                // 右: 温度 + 天气
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${weather.temperature.toStringAsFixed(0)}°',
                      style: const TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${weather.conditionIcon} ${weather.conditionLabel}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(),

            // 底部状态栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 电量
                  Row(
                    children: [
                      Icon(
                        batteryPercent > 20
                            ? Icons.battery_std
                            : Icons.battery_alert,
                        color: batteryPercent > 20
                            ? const Color(0xFF66DD88)
                            : const Color(0xFFFF6B6B),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$batteryPercent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  // 分隔
                  Container(
                    width: 1,
                    height: 16,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  // 信号
                  Row(
                    children: [
                      Icon(
                        Icons.signal_cellular_alt,
                        color: signalStrength > 2
                            ? Colors.white
                            : const Color(0xFFFFAA33),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${signalStrength > 2 ? 4 : 3}G',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  // 分隔
                  Container(
                    width: 1,
                    height: 16,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  // 小人状态
                  Text(
                    petState.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timePeriod(int hour) {
    if (hour < 6) return '凌晨';
    if (hour < 11) return '上午';
    if (hour < 13) return '中午';
    if (hour < 18) return '下午';
    if (hour < 22) return '傍晚';
    return '深夜';
  }
}
