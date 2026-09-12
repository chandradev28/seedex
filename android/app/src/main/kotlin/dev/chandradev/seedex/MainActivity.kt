package dev.chandradev.seedex

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity(), EventChannel.StreamHandler {
    companion object {
        private const val METHOD_CHANNEL = "dev.seedex/intents"
        private const val EVENT_CHANNEL = "dev.seedex/intents/events"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var initialPayload: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        initialPayload = payloadFromIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialPayload" -> {
                        result.success(initialPayload)
                        initialPayload = null
                    }
                    "copyContentUri" -> {
                        val rawUri = call.argument<String>("uri")
                        if (rawUri == null) {
                            result.error("missing_uri", "A content URI is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(copyContentUri(Uri.parse(rawUri)))
                        } catch (error: Exception) {
                            result.error("copy_failed", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        payloadFromIntent(intent)?.let { eventSink?.success(it) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun payloadFromIntent(source: Intent?): Map<String, String>? {
        if (source == null) return null

        val value = when (source.action) {
            Intent.ACTION_SEND -> source.getStringExtra(Intent.EXTRA_TEXT)
                ?: source.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.toString()
            Intent.ACTION_VIEW -> source.dataString
            else -> null
        } ?: return null

        val payload = mutableMapOf(
            "value" to value,
            "action" to (source.action ?: ""),
            "mimeType" to (source.type ?: "")
        )

        val referrer = source.getStringExtra(Intent.EXTRA_REFERRER_NAME)
            ?: source.getParcelableExtra<Uri>(Intent.EXTRA_REFERRER)?.toString()
        if (!referrer.isNullOrBlank()) payload["referrer"] = referrer
        return payload
    }

    private fun copyContentUri(uri: Uri): String {
        val imports = File(cacheDir, "torrent_imports").apply { mkdirs() }
        val output = File(imports, "${System.currentTimeMillis()}.torrent")
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Unable to open the selected torrent" }
            output.outputStream().use { target -> input.copyTo(target) }
        }
        return output.absolutePath
    }
}
