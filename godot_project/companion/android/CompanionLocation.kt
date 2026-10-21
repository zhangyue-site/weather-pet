package com.weather.companion

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.Geocoder
import java.util.Locale
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject

/** Foreground, one-shot location. No background tracking or external SDK. */
class CompanionLocation(godot: Godot) : GodotPlugin(godot) {
    private val handler = Handler(Looper.getMainLooper())
    private var listener: LocationListener? = null
    private var generation = 0
    override fun getPluginName() = "CompanionLocation"
    override fun getPluginSignals() = setOf(
        SignalInfo("location_ready", String::class.java),
        SignalInfo("location_name_ready", String::class.java),
        SignalInfo("location_error", String::class.java)
    )

    @UsedByGodot
    fun request_location() {
        activity?.runOnUiThread {
            stop()
            val token = ++generation
            val a = activity ?: return@runOnUiThread
            if (a.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                a.requestPermissions(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION), 4071)
                waitForPermission(token, 0)
            } else locate(token)
        }
    }

    private fun waitForPermission(token: Int, attempt: Int) {
        if (token != generation) return
        val a = activity ?: return
        if (a.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            locate(token)
        } else if (attempt >= 40) {
            emitSignal("location_error", "未获得定位权限，请在设置中选择城市")
        } else handler.postDelayed({ waitForPermission(token, attempt + 1) }, 500)
    }

    @Suppress("MissingPermission")
    private fun locate(token: Int) {
        val a = activity ?: return
        val manager = a.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER).filter {
            runCatching { manager.isProviderEnabled(it) }.getOrDefault(false)
        }
        if (providers.isEmpty()) {
            emitSignal("location_error", "设备定位不可用，请开启定位或选择城市")
            return
        }
        val cached = providers.mapNotNull { runCatching { manager.getLastKnownLocation(it) }.getOrNull() }
            .filter { System.currentTimeMillis() - it.time < 15 * 60 * 1000 }
            .maxByOrNull { it.time }
        if (cached != null) { deliver(cached, token); return }
        listener = object : LocationListener {
            override fun onLocationChanged(location: Location) = deliver(location, token)
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
            @Deprecated("Legacy Android callback")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }
        for (provider in providers) {
            runCatching { manager.requestLocationUpdates(provider, 1000L, 0f, listener!!, Looper.getMainLooper()) }
        }
        handler.postDelayed({
            if (generation == token && listener != null) {
                stop()
                emitSignal("location_error", "暂时未取得位置，请重试或选择城市")
            }
        }, 20000)
    }

    private fun deliver(location: Location, token: Int) {
        if (token != generation) return
        stop()
        val resolvedToken = ++generation
        emitSignal("location_ready", JSONObject().put("lat", location.latitude).put("lon", location.longitude).toString())
        val context = activity ?: return
        Thread {
            @Suppress("DEPRECATION")
            val address = runCatching {
                Geocoder(context, Locale.SIMPLIFIED_CHINESE)
                    .getFromLocation(location.latitude, location.longitude, 1)?.firstOrNull()
            }.getOrNull()
            val name = address?.let {
                listOfNotNull(it.locality ?: it.adminArea, it.subLocality ?: it.subAdminArea)
                    .filter { part -> part.isNotBlank() }.distinct().joinToString(" · ")
            }.orEmpty()
            handler.post {
                if (generation == resolvedToken && name.isNotBlank()) {
                    emitSignal("location_name_ready", name)
                }
            }
        }.start()
    }

    private fun stop() {
        val manager = activity?.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        listener?.let { runCatching { manager?.removeUpdates(it) } }
        listener = null
    }

}
