package com.example.brainy

import android.content.Intent
import android.net.Uri
import android.util.Base64
import java.io.ByteArrayOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "brainy/quick_capture"
    private var channel: MethodChannel? = null
    private var pending: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "takePending") {
                result.success(pending)
                pending = null
            } else result.notImplemented()
        }
        receive(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
    }

    private fun receive(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        val content = mutableMapOf<String, String>()
        intent.getStringExtra(Intent.EXTRA_SUBJECT)?.let { content["title"] = it }
        intent.getStringExtra(Intent.EXTRA_TEXT)?.let { content["text"] = it }
        @Suppress("DEPRECATION")
        val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        if (uri != null) {
            try {
                contentResolver.openInputStream(uri)?.use { stream ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (output.size() <= 2 * 1024 * 1024) {
                        val count = stream.read(buffer)
                        if (count < 0) break
                        output.write(buffer, 0, count)
                    }
                    val bytes = output.toByteArray()
                    if (bytes.size <= 2 * 1024 * 1024) {
                        content["fileBase64"] = Base64.encodeToString(bytes, Base64.NO_WRAP)
                        content["fileName"] = uri.lastPathSegment?.substringAfterLast('/') ?: "shared-file"
                        content["mimeType"] = intent.type ?: "application/octet-stream"
                    } else content["fileError"] = "File exceeds 2 MiB"
                }
            } catch (_: Exception) { content["fileError"] = "Cannot read shared file" }
        }
        if (content.isNotEmpty()) {
            pending = content
            channel?.invokeMethod("incoming", content)
        }
    }
}
