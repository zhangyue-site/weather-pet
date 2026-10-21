package com.weather.companion

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject
import java.io.File
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import javax.net.ssl.HttpsURLConnection

/** User-initiated APK updates. HTTPS + bounded download + hash/package/version/signer checks. */
class CompanionUpdater(godot: Godot) : GodotPlugin(godot) {
    private val executor = Executors.newSingleThreadExecutor()
    private val generation = AtomicInteger(0)
    @Volatile private var connection: HttpsURLConnection? = null
    @Volatile private var busy = false
    @Volatile private var manifest: JSONObject? = null
    @Volatile private var readyFile: File? = null
    private val host = "zz.zhangyue.site"
    private val prefix = "/weather-companion/"
    private val maxApkBytes = 150L * 1024 * 1024
    override fun getPluginName() = "CompanionUpdater"
    override fun getPluginSignals() = setOf(SignalInfo("update_state", String::class.java))

    @UsedByGodot fun installed_version(): String {
        val a = activity ?: return "{}"
        val info = a.packageManager.getPackageInfo(a.packageName, 0)
        return JSONObject().put("name", info.versionName).put("code", version(info)).toString()
    }
    private fun version(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()
    private fun report(state: String, message: String, extra: JSONObject = JSONObject()) {
        extra.put("state", state).put("message", message)
        activity?.runOnUiThread { emitSignal("update_state", extra.toString()) }
    }
    private fun checkedUrl(text: String): URL {
        val url = URL(text)
        require(url.protocol == "https" && url.host == host && url.userInfo == null && (url.port == -1 || url.port == 443) && url.path.startsWith(prefix) && !url.path.contains("..")) { "更新地址不受信任" }
        return url
    }
    private fun connect(text: String): HttpsURLConnection {
        val c = checkedUrl(text).openConnection() as HttpsURLConnection
        c.connectTimeout = 15000
        c.readTimeout = 20000
        c.instanceFollowRedirects = false
        c.setRequestProperty("Accept-Encoding", "identity")
        connection = c
        require(c.responseCode == 200) { "更新服务器返回 ${c.responseCode}" }
        return c
    }
    @UsedByGodot fun check_update(url: String) {
        if (busy) return
        val token = generation.incrementAndGet()
        busy = true
        manifest = null
        readyFile = null
        report("checking", "正在检查更新…")
        executor.execute {
            try {
                val c = connect(url)
                val bytes = c.inputStream.use { input ->
                    val out = java.io.ByteArrayOutputStream()
                    val buffer = ByteArray(4096)
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        require(out.size() + n <= 32768) { "更新信息过大" }
                        out.write(buffer, 0, n)
                    }
                    out.toByteArray()
                }
                val m = JSONObject(String(bytes, Charsets.UTF_8))
                val a = activity ?: error("应用已关闭")
                require(m.getInt("schema") == 1 && m.getString("package") == a.packageName) { "更新包不属于本应用" }
                require(m.getLong("version_code") > 0 && m.getString("version_name").length in 1..40) { "版本信息无效" }
                require(m.getLong("bytes") in 1..maxApkBytes && m.getString("sha256").matches(Regex("[0-9a-fA-F]{64}"))) { "安装包校验信息无效" }
                require(m.optString("notes").length <= 2000) { "更新说明过长" }
                checkedUrl(m.getString("url"))
                require(m.getInt("min_sdk") <= Build.VERSION.SDK_INT && m.getString("abi") in Build.SUPPORTED_ABIS) { "此更新不支持当前手机" }
                if (generation.get() != token) return@execute
                if (m.getLong("version_code") <= version(a.packageManager.getPackageInfo(a.packageName, 0))) {
                    report("current", "已经是最新版本")
                } else {
                    manifest = m
                    report("available", "发现新版本 ${m.getString("version_name")}", m)
                }
            } catch (e: Exception) {
                if (generation.get() == token) report("error", e.message ?: "无法检查更新，请稍后重试")
            } finally {
                connection?.disconnect(); connection = null; busy = false
            }
        }
    }
    @UsedByGodot fun download_update() {
        val m = manifest ?: return
        if (busy) return
        busy = true
        val token = generation.incrementAndGet()
        executor.execute {
            var partial: File? = null
            try {
                val a = activity ?: error("应用已关闭")
                val dir = File(a.cacheDir, "updates").apply { mkdirs() }
                require(dir.usableSpace > m.getLong("bytes") * 2 + 10 * 1024 * 1024) { "手机存储空间不足" }
                val part = File(dir, "update.part")
                partial = part
                val final = File(dir, "update.apk")
                if (final.exists() && runCatching { verify(final, m) }.isSuccess) {
                    readyFile = final
                    report("ready", "安装包已校验，可以安装")
                    return@execute
                }
                final.delete()
                val c = connect(m.getString("url"))
                val expected = m.getLong("bytes")
                val length = c.getHeaderField("Content-Length")?.toLongOrNull() ?: -1L
                require(length == -1L || length == expected) { "安装包大小与发布信息不一致" }
                var received = 0L
                var lastPercent = -1
                c.inputStream.use { input ->
                    part.outputStream().use { output ->
                        val buffer = ByteArray(65536)
                        while (true) {
                            require(generation.get() == token) { "下载已取消" }
                            val n = input.read(buffer)
                            if (n < 0) break
                            received += n
                            require(received <= expected && received <= maxApkBytes) { "安装包超过预期大小" }
                            output.write(buffer,0,n)
                            val percent = (received * 100 / expected).toInt()
                            if (percent != lastPercent) {
                                lastPercent = percent
                                report("downloading", "下载中 $percent%", JSONObject().put("percent", percent))
                            }
                        }
                        output.fd.sync()
                    }
                }
                require(received == expected) { "安装包未下载完整" }
                verify(part,m)
                require(generation.get() == token) { "下载已取消" }
                require(part.renameTo(final)) { "无法保存安装包" }
                readyFile = final
                report("ready", "下载完成，校验通过")
            } catch (e: Exception) {
                partial?.delete()
                if (generation.get() == token) report("error",e.message ?: "下载失败，请重试")
            } finally {
                connection?.disconnect(); connection = null; busy = false
            }
        }
    }
    @Suppress("DEPRECATION")
    private fun signerSet(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        return signatures.orEmpty().map { bytesHex(MessageDigest.getInstance("SHA-256").digest(it.toByteArray())) }.toSet()
    }
    private fun bytesHex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it.toInt() and 255) }
    private fun verify(file: File,m: JSONObject) {
        require(file.length() == m.getLong("bytes")) { "安装包大小校验失败" }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer=ByteArray(65536)
            while (true) { val n=input.read(buffer); if(n<0) break; digest.update(buffer,0,n) }
        }
        require(bytesHex(digest.digest()).equals(m.getString("sha256"),true)) { "安装包哈希校验失败" }
        val a=activity ?: error("应用已关闭")
        @Suppress("DEPRECATION") val flags = if(Build.VERSION.SDK_INT>=28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val incoming=a.packageManager.getPackageArchiveInfo(file.absolutePath,flags) ?: error("无法识别安装包")
        val installed=a.packageManager.getPackageInfo(a.packageName,flags)
        require(incoming.packageName==a.packageName && version(incoming)==m.getLong("version_code") && version(incoming)>version(installed)) { "包名或版本校验失败" }
        require(signerSet(installed).isNotEmpty() && signerSet(incoming)==signerSet(installed)) { "安装包签名不一致" }
    }
    @UsedByGodot fun cancel_update() {
        generation.incrementAndGet()
        connection?.disconnect()
        report("cancelled","已取消下载，可以重新检查更新")
    }
    @UsedByGodot fun install_update() {
        val file=readyFile ?: return
        val m=manifest ?: return
        if (busy) return
        busy=true
        executor.execute {
            try {
                verify(file,m)
                activity?.runOnUiThread {
                    try {
                        val a=activity ?: return@runOnUiThread
                        if(Build.VERSION.SDK_INT>=26 && !a.packageManager.canRequestPackageInstalls()) {
                            report("permission","请允许小院天气安装更新，返回后点「继续安装」")
                            a.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,Uri.parse("package:${a.packageName}")))
                            return@runOnUiThread
                        }
                        val uri=FileProvider.getUriForFile(a,a.packageName+".updates",file)
                        val intent=Intent(Intent.ACTION_VIEW).setDataAndType(uri,"application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        a.startActivity(intent)
                        report("installer","已打开系统安装页；如取消，可再次点击安装")
                    } catch (e: Exception) { report("error",e.message ?: "无法打开安装程序") }
                }
            } catch(e: Exception) { report("error",e.message ?: "校验失败") }
            finally { busy=false }
        }
    }
}
