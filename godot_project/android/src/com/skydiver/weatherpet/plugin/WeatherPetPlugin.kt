package com.skydiver.weatherpet.plugin

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.Location
import android.os.BatteryManager
import android.os.Build
import android.os.Looper
import android.telephony.TelephonyManager
import android.view.View
import androidx.core.content.ContextCompat
import androidx.work.*
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.*
import java.util.concurrent.TimeUnit

class WeatherPetPlugin(godot: Godot) : GodotPlugin(godot) {

    // ============================================================
    //  和风天气 API 配置 (QWeather)
    //  认证: 请求头 X-QW-Api-Key + 专属 API Host
    // ============================================================
    private val QWEATHER_KEY: String = "be785dbd3cab4f0d9cc27b3d8a1f3de3"
    private val QWEATHER_HOST: String = "nv5vxkv2bh.re.qweatherapi.com"
    private val QWEATHER_BASE: String get() = "https://$QWEATHER_HOST"

    private var fusedLocationClient: com.google.android.gms.location.FusedLocationProviderClient? = null
    private var lastLocation: Location? = null
    private var receiversRegistered: Boolean = false
    private var weatherScheduled: Boolean = false

    // 位置模式: true=GPS实时定位, false=自定义位置
    private var useGps: Boolean = true
    private var customCoord: String = "114.05,22.55"   // 自定义经纬度
    private var customCity: String = "深圳"             // 自定义城市名

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_BATTERY_CHANGED -> {
                    val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, 100)
                    val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                    val charging = status == BatteryManager.BATTERY_STATUS_CHARGING
                    emitSignal("on_battery", level, charging)
                }
                Intent.ACTION_BATTERY_LOW -> emitSignal("on_battery", 15, false)
                "android.provider.Telephony.SMS_RECEIVED" -> {
                    val sender = intent.extras?.getString("sender") ?: "未知联系人"
                    emitSignal("on_sms", sender)
                }
                "android.intent.action.SIG_STR" -> {
                    val tm = activity?.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                    emitSignal("on_signal", tm?.signalStrength?.level ?: 3)
                }
            }
        }
    }

    override fun getPluginName() = "WeatherPetPlugin"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("on_weather", String::class.java),
        SignalInfo("on_time", Int::class.java, Int::class.java),
        SignalInfo("on_signal", Int::class.java),
        SignalInfo("on_sms", String::class.java),
        SignalInfo("on_battery", Int::class.java, Boolean::class.java),
        SignalInfo("on_festival", String::class.java, String::class.java),
        SignalInfo("on_touch", String::class.java, Float::class.java, Float::class.java),
        SignalInfo("on_location", String::class.java),  // 位置更新: JSON {lon,lat,city,mode}
    )

    override fun onMainCreate(activity: android.app.Activity): View? {
        registerReceivers()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(activity)
        scheduleWeatherRefresh()
        return null
    }

    override fun onMainDestroy() {
        try { activity?.unregisterReceiver(receiver) } catch (_: Exception) {}
        super.onMainDestroy()
    }

    private fun registerReceivers() {
        if (receiversRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_BATTERY_CHANGED)
            addAction(Intent.ACTION_BATTERY_LOW)
            addAction("android.provider.Telephony.SMS_RECEIVED")
            addAction("android.intent.action.SIG_STR")
        }
        activity?.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        receiversRegistered = true
    }

    private fun scheduleWeatherRefresh() {
        if (weatherScheduled) return
        val request = PeriodicWorkRequestBuilder<WeatherWorker>(30, TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        WorkManager.getInstance(activity!!).enqueueUniquePeriodicWork(
            "weather_refresh", ExistingPeriodicWorkPolicy.UPDATE, request)
        weatherScheduled = true
    }

    // ============================================================
    //  GDScript 可调用的方法
    // ============================================================

    /** 启动: 申请权限 + 首次定位取天气 */
    @UsedByGodot
    fun start(weatherApiKey: String) {
        runOnMainThread {
            requestLocationPermission()
            updateTime()
            checkFestival()
            refreshWeather()
        }
    }

    /** 刷新天气: 根据当前模式(GPS/自定义)取数据 */
    @UsedByGodot
    fun refreshWeather() {
        runOnMainThread {
            if (useGps) {
                requestLocationAndWeather()
            } else {
                fetchWeatherAndCity(customCoord, customCity)
            }
        }
    }

    /** 切换到 GPS 实时定位模式 */
    @UsedByGodot
    fun useGpsLocation() {
        useGps = true
        refreshWeather()
    }

    /** 设置自定义位置 (经度, 纬度, 城市名) → 切换到自定义模式并刷新 */
    @UsedByGodot
    fun setCustomLocation(lon: Float, lat: Float, cityName: String) {
        useGps = false
        customCoord = "%.4f,%.4f".format(lon, lat)
        customCity = cityName
        // 通知 GDScript 当前位置
        val loc = JSONObject().apply {
            put("lon", lon); put("lat", lat); put("city", cityName); put("mode", "custom")
        }
        emitSignal("on_location", loc.toString())
        refreshWeather()
    }

    /** 查询当前支持的预设城市 (供 GDScript 做城市选择列表) */
    @UsedByGodot
    fun getCityList(): String {
        // 返回 JSON 数组: [{name, lon, lat}, ...]
        val arr = JSONObject()
        val cities = arrayOf(
            Triple("北京", 116.41, 39.92), Triple("上海", 121.47, 31.23),
            Triple("广州", 113.26, 23.13), Triple("深圳", 114.06, 22.55),
            Triple("杭州", 120.16, 30.27), Triple("成都", 104.07, 30.67),
            Triple("武汉", 114.31, 30.59), Triple("西安", 108.94, 34.34),
            Triple("南京", 118.80, 32.06), Triple("重庆", 106.55, 29.56),
            Triple("哈尔滨", 126.64, 45.75), Triple("昆明", 102.83, 24.88),
            Triple("乌鲁木齐", 87.62, 43.83), Triple("拉萨", 91.13, 29.65),
            Triple("香港", 114.17, 22.32), Triple("台北", 121.56, 25.03)
        )
        val list = org.json.JSONArray()
        for ((name, lon, lat) in cities) {
            val c = JSONObject().apply {
                put("name", name); put("lon", lon); put("lat", lat)
            }
            list.put(c)
        }
        arr.put("cities", list)
        return arr.toString()
    }

    @UsedByGodot
    fun updateTime() {
        val cal = Calendar.getInstance()
        emitSignal("on_time", cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
    }

    @UsedByGodot
    fun checkFestival() {
        val cal = Calendar.getInstance()
        val month = cal.get(Calendar.MONTH) + 1
        val day = cal.get(Calendar.DAY_OF_MONTH)
        val festival = festivals.find { it.month == month && it.day == day }
        if (festival != null) emitSignal("on_festival", festival.name, festival.emoji)
    }

    @UsedByGodot
    fun sendWeather(json: String) { emitSignal("on_weather", json) }

    @UsedByGodot
    fun sendTouch(type: String, x: Float, y: Float) { emitSignal("on_touch", type, x, y) }

    fun runOnMainThread(action: () -> Unit) { activity?.runOnUiThread { action() } }

    // ============================================================
    //  定位权限
    // ============================================================
    private fun requestLocationPermission() {
        val act = activity ?: return
        val perms = arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        val need = perms.any { ContextCompat.checkSelfPermission(act, it) != PackageManager.PERMISSION_GRANTED }
        if (need && act is android.app.Activity) {
            act.requestPermissions(perms, 1001)
        }
    }

    private fun hasLocationPermission(): Boolean {
        val act = activity ?: return false
        val fine = ContextCompat.checkSelfPermission(act, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(act, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    // ============================================================
    //  GPS 定位 + 天气请求
    // ============================================================
    private fun requestLocationAndWeather() {
        if (!hasLocationPermission()) {
            // 无权限: 先申请, 申请后会在下次 refreshWeather 时重试; 当前先用默认
            requestLocationPermission()
            fetchWeatherAndCity("114.05,22.55", "深圳")
            return
        }
        val client = fusedLocationClient ?: run {
            fetchWeatherAndCity("114.05,22.55", "深圳"); return
        }
        try {
            client.lastLocation
                .addOnSuccessListener { loc: Location? ->
                    if (loc != null) {
                        lastLocation = loc
                        val coord = "%.4f,%.4f".format(loc.longitude, loc.latitude)
                        emitLocation(loc.longitude, loc.latitude, "gps")
                        fetchWeatherAndCity(coord, "")
                    } else {
                        requestSingleLocation()
                    }
                }
                .addOnFailureListener { requestSingleLocation() }
        } catch (e: SecurityException) {
            fetchWeatherAndCity("114.05,22.55", "深圳")
        }
    }

    private fun requestSingleLocation() {
        val client = fusedLocationClient ?: return
        try {
            val req = LocationRequest.create().apply {
                priority = LocationRequest.PRIORITY_BALANCED_POWER_ACCURACY
                interval = 10000; fastestInterval = 5000; numUpdates = 1
            }
            val callback = object : LocationCallback() {
                override fun onLocationResult(result: LocationResult) {
                    val loc = result.lastLocation
                    if (loc != null) {
                        lastLocation = loc
                        val coord = "%.4f,%.4f".format(loc.longitude, loc.latitude)
                        emitLocation(loc.longitude, loc.latitude, "gps")
                        fetchWeatherAndCity(coord, "")
                    } else {
                        fetchWeatherAndCity("114.05,22.55", "深圳")
                    }
                }
            }
            client.requestLocationUpdates(req, callback, Looper.getMainLooper())
        } catch (e: SecurityException) { /* ignore */ }
    }

    private fun emitLocation(lon: Double, lat: Double, mode: String) {
        val loc = JSONObject().apply {
            put("lon", lon); put("lat", lat); put("mode", mode)
        }
        emitSignal("on_location", loc.toString())
    }

    // ============================================================
    //  和风天气 API (子线程)
    // ============================================================
    private fun fetchWeatherAndCity(coord: String, knownCity: String) {
        Thread {
            try {
                val weatherJson = httpGet("$QWEATHER_BASE/v7/weather/now?location=$coord&lang=zh")
                if (weatherJson == null) { sendWeatherDemo(coord); return@Thread }
                val wobj = JSONObject(weatherJson)
                if (wobj.optString("code", "") != "200") { sendWeatherDemo(coord); return@Thread }
                val now = wobj.optJSONObject("now") ?: run { sendWeatherDemo(coord); return@Thread }

                val iconCode = now.optString("icon", "100")
                val condition = mapQWeatherCode(iconCode)

                // 城市名: 优先用传入的, 否则反查 GeoAPI
                var cityName = knownCity
                if (cityName.isEmpty()) {
                    val cityJson = httpGet("$QWEATHER_BASE/geo/v2/city/lookup?location=$coord&lang=zh")
                    if (cityJson != null) {
                        val locs = JSONObject(cityJson).optJSONArray("location")
                        if (locs != null && locs.length() > 0) {
                            val first = locs.getJSONObject(0)
                            cityName = first.optString("adm2", first.optString("name", "当前位置"))
                        }
                    }
                    if (cityName.isEmpty()) cityName = "当前位置"
                }

                val payload = JSONObject().apply {
                    put("condition", condition)
                    put("temperature", now.optString("temp", "22").toDouble())
                    put("humidity", now.optString("humidity", "50").toDouble())
                    put("wind_speed", now.optString("windSpeed", "5").toDouble())
                    put("city_name", cityName)
                    put("raw_text", now.optString("text", ""))
                    put("raw_code", iconCode)
                    put("feels_like", now.optString("feelsLike", "").toDoubleOrNull() ?: 0.0)
                }
                emitSignal("on_weather", payload.toString())
            } catch (e: Exception) {
                sendWeatherDemo(coord)
            }
        }.start()
    }

    private fun sendWeatherDemo(coord: String) {
        val payload = JSONObject().apply {
            put("condition", "clear"); put("temperature", 22.0); put("humidity", 50.0)
            put("wind_speed", 5.0); put("city_name", "深圳"); put("raw_text", "")
        }
        emitSignal("on_weather", payload.toString())
    }

    private fun httpGet(urlStr: String): String? {
        return try {
            val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"; connectTimeout = 10000; readTimeout = 10000
                setRequestProperty("Accept-Encoding", "gzip")
                setRequestProperty("X-QW-Api-Key", QWEATHER_KEY)
            }
            if (conn.responseCode !in 200..299) return null
            val stream = if (conn.contentEncoding == "gzip")
                java.util.zip.GZIPInputStream(conn.inputStream) else conn.inputStream
            stream.bufferedReader().use { it.readText() }
        } catch (e: Exception) { null }
    }

    // ============================================================
    //  和风天气 icon 代码 → GDScript condition
    //  参考: https://dev.qweather.com/docs/resource/icons/
    // ============================================================
    private fun mapQWeatherCode(code: String): String = when (code) {
        "100", "150" -> "clear"
        "101", "102", "103", "151", "152", "153" -> "cloudy"
        "104", "154" -> "overcast"
        "300", "301" -> "drizzle"
        "302", "303", "304" -> "thunderstorm"
        "305", "309", "314", "315" -> "rain"
        "306", "313", "316", "317", "318" -> "rain"
        "307", "308", "310", "311", "312", "350", "351", "399" -> "heavy_rain"
        "400", "407", "408", "409", "456" -> "snow"
        "401", "402", "403", "404", "405", "406", "410", "457", "499" -> "heavy_snow"
        "500", "501" -> "fog"
        "502", "503", "504" -> "haze"
        "507", "508" -> "sandstorm"
        "902" -> "windy"
        else -> "clear"
    }

    class WeatherWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
        override fun doWork(): Result {
            instance?.refreshWeather()
            return Result.success()
        }
        companion object { var instance: WeatherPetPlugin? = null }
    }

    init { WeatherWorker.instance = this }

    data class FestivalInfo(val name: String, val month: Int, val day: Int, val emoji: String)

    // 2025-2026 部分节日 (公历固定日期; 农历节日近似)
    private val festivals = listOf(
        FestivalInfo("元旦", 1, 1, "🎉"),
        FestivalInfo("春节", 2, 17, "🧧"),
        FestivalInfo("元宵节", 3, 3, "🏮"),
        FestivalInfo("妇女节", 3, 8, "🌷"),
        FestivalInfo("植树节", 3, 12, "🌳"),
        FestivalInfo("清明节", 4, 5, "🌧"),
        FestivalInfo("劳动节", 5, 1, "🛠"),
        FestivalInfo("青年节", 5, 4, "💪"),
        FestivalInfo("端午节", 5, 31, "🐉"),
        FestivalInfo("儿童节", 6, 1, "🍭"),
        FestivalInfo("七夕节", 8, 29, "💑"),
        FestivalInfo("教师节", 9, 10, "🍎"),
        FestivalInfo("中秋节", 9, 25, "🌙"),
        FestivalInfo("国庆节", 10, 1, "🇨🇳"),
        FestivalInfo("重阳节", 10, 29, "🍂"),
        FestivalInfo("万圣节", 10, 31, "🎃"),
        FestivalInfo("感恩节", 11, 27, "🦃"),
        FestivalInfo("圣诞节", 12, 25, "🎅"),
        FestivalInfo("跨年夜", 12, 31, "🎆"),
    )
}
