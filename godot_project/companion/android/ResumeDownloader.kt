package com.weather.companion

import android.app.Activity
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import javax.net.ssl.HttpsURLConnection

/**
 * 断点续传下载器（205/1.3.5 起）。
 *
 * 发布说明：205 的 APK 由 repack 管线构建，本类以 Java 源码经 javac+d8 编为 classes5.dex 注入；
 * 此 Kotlin 版与发布实现行为一致，作为维护用参考。下载循环通过 CompanionUpdater 的
 * 包级桥方法（act/verifyB/reportB/genGet/setReady/maxBytes/finishB/connectResumeB）访问宿主。
 */
object ResumeDownloader {
    private const val TAG = "WCResume"

    fun resume(up: CompanionUpdater, m: JSONObject, token: Int) {
        var part: File? = null
        var received = 0L
        try {
            val a: Activity = up.act() ?: error("应用已关闭")
            val dir = File(a.cacheDir, "updates").apply { mkdirs() }
            val expected = m.getLong("bytes")
            require(dir.usableSpace > expected * 2 + 10L * 1024 * 1024) { "手机存储空间不足" }
            val contentHash = m.getString("sha256")
            require(contentHash.matches(Regex("[0-9a-fA-F]{64}"))) { "Invalid update hash" }
            part = File(dir, "$contentHash.part")
            val fin = File(dir, "$contentHash.apk")
            if (fin.exists()) {
                up.verifyB(fin, m)
                up.setReady(fin)
                up.reportB("ready", "安装包已校验，可以安装", JSONObject())
                return
            }
            fin.delete()
            var have = part.length()
            Log.i(TAG, "part.length=$have expected=$expected")
            if (have < 0 || have == expected) have = 0
            val c = up.connectResumeB(m.getString("url"), have)
            val code = c.responseCode
            val cr = c.getHeaderField("Content-Range")
            Log.i(TAG, "code=$code contentRange=$cr")
            if (code == 206) {
                // 服务器续传：校验回执起点与本地点一致才追加，否则回退全量重下
                var ok = false
                if (cr != null && cr.startsWith("bytes ")) {
                    val dash = cr.indexOf('-', 6)
                    if (dash > 6) {
                        ok = try {
                            val server = cr.substring(6, dash).toLong()
                            server == have && server < expected
                        } catch (_: NumberFormatException) {
                            false
                        }
                    }
                }
                if (!ok) have = 0
            } else {
                have = 0
            }
            Log.i(TAG, "resumeFrom=$have")
            FileOutputStream(part.absolutePath, have > 0).use { out ->
                c.inputStream.use { input ->
                    val buf = ByteArray(65536)
                    received = have
                    var lastPercent = -1
                    while (true) {
                        require(up.genGet() == token) { "下载已取消" }
                        val n = input.read(buf)
                        if (n <= 0) break
                        received += n
                        require(received <= expected && received <= up.maxBytes()) { "安装包超过预期大小" }
                        out.write(buf, 0, n)
                        out.flush()
                        val percent = (received * 100 / expected).toInt()
                        if (percent != lastPercent) {
                            lastPercent = percent
                            up.reportB("downloading", "下载中 $percent%", JSONObject().put("percent", percent))
                        }
                    }
                }
            }
            Log.i(TAG, "final received=$received expected=$expected")
            require(received == expected) { "安装包未下载完整，进度已保留" }
            up.verifyB(part, m)
            require(up.genGet() == token) { "下载已取消" }
            require(part.renameTo(fin)) { "无法保存安装包" }
            up.setReady(fin)
            up.reportB("ready", "下载完成，校验通过", JSONObject())
            Log.i(TAG, "DONE")
        } catch (e: Exception) {
            // 进度保留策略：同 token 且 .part 有字节则保留断点，否则清掉重来
            val keep = up.genGet() == token && part != null && part.exists() && part.length() > 0
            try {
                if (keep) {
                    up.reportB("error", "${e.message}（进度已保留，重试继续）", JSONObject())
                } else {
                    part?.takeIf { it.exists() }?.delete()
                    if (up.genGet() == token) up.reportB("error", e.message, JSONObject())
                }
            } catch (_: Exception) {
            }
        } finally {
            up.finishB()
        }
    }
}
