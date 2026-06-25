---
tags: [obs-code, class]
created: 2026-06-25
source: obs-code
project: weather-pet
class: WeatherPetPlugin
file: weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt
line: 31
---
# WeatherPetPlugin

> 🏷️ `class` in [[WeatherPetPlugin]]:31

## 大白话

weather pet plugin

## 方法 (28)

| 方法 | 大白话 | 行号 |
|------|--------|------|
| `checkFestival` | 验证festival | 200 |
| `doWork` | do work | 389 |
| `emitLocation` | 发送location | 291 |
| `fetchWeatherAndCity` | ============================================================ 和风天气 API (子线程) ======================== | 301 |
| `getCityList` | 启动: 申请权限 + 首次定位取天气 */ fun start(weatherApiKey: String) { runOnMainThread { requestLocationPermission | 169 |
| `getPluginName` | 获取plugin name | 73 |
| `getPluginSignals` | 获取plugin signals | 75 |
| `hasLocationPermission` | 判断location permission | 229 |
| `httpGet` | http get | 352 |
| `mapQWeatherCode` | ============================================================ 和风天气 icon 代码 → GDScript condition 参考: h | 370 |
| `onLocationResult` | 处理location result | 275 |
| `onMainCreate` | 处理main create | 86 |
| `onMainDestroy` | 处理main destroy | 93 |
| `onReceive` | 处理receive | 52 |
| `refreshWeather` | 启动: 申请权限 + 首次定位取天气 */ fun start(weatherApiKey: String) { runOnMainThread { requestLocationPermission | 136 |
| `registerReceivers` | 添加receivers | 98 |
| `requestLocationAndWeather` | ============================================================ GPS 定位 + 天气请求 ========================= | 239 |
| `requestLocationPermission` | ============================================================ 定位权限 ================================== | 220 |
| `requestSingleLocation` | request single location | 267 |
| `runOnMainThread` | run on main thread | 215 |
| `scheduleWeatherRefresh` | schedule weather refresh | 110 |
| `sendTouch` | 发送touch | 212 |
| `sendWeather` | 发送weather | 209 |
| `sendWeatherDemo` | 发送weather demo | 344 |
| `setCustomLocation` | 启动: 申请权限 + 首次定位取天气 */ fun start(weatherApiKey: String) { runOnMainThread { requestLocationPermission | 155 |
| `start` | 启动: 申请权限 + 首次定位取天气 | 125 |
| `updateTime` | 更新time | 194 |
| `useGpsLocation` | 启动: 申请权限 + 首次定位取天气 */ fun start(weatherApiKey: String) { runOnMainThread { requestLocationPermission | 148 |

## Related

- [[WeatherPetPlugin]] — 所在文件
- [[symbols|Symbol Index]]
- [[connections|Call Graph]]
