package com.hamjam.hamjam

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val reqProjection = 1001
    private val main = Handler(Looper.getMainLooper())
    private var events: EventChannel.EventSink? = null
    private var pendingUrl = ""
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "hamjam/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                    Bus.sink = { m -> main.post { events?.success(m) } }
                }
                override fun onCancel(args: Any?) { events = null; Bus.sink = null }
            })

        MethodChannel(messenger, "hamjam/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "mediaKey" -> {
                    val ok = MediaKeys.send(this, call.argument<String>("key") ?: "")
                    if (ok) result.success(null) else result.notImplemented()
                }
                "host" -> {
                    if (!ensurePermissions()) { result.success(false); return@setMethodCallHandler }
                    pendingUrl = call.argument<String>("url")!!
                    pendingResult = result
                    val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    @Suppress("DEPRECATION")
                    startActivityForResult(mgr.createScreenCaptureIntent(), reqProjection)
                }
                "stopHost" -> {
                    startService(Intent(this, CaptureService::class.java).setAction(CaptureService.ACTION_STOP))
                    result.success(null)
                }
                "join" -> {
                    if (!ensurePermissions()) { result.success(false); return@setMethodCallHandler }
                    startForegroundService(Intent(this, GuestService::class.java)
                        .putExtra(GuestService.EXTRA_URL, call.argument<String>("url"))
                        .putExtra(GuestService.EXTRA_CODE, call.argument<String>("code")))
                    result.success(true)
                }
                "leave" -> {
                    startService(Intent(this, GuestService::class.java).setAction(GuestService.ACTION_STOP))
                    result.success(null)
                }
                "control" -> {
                    Bus.sender?.invoke(JSONObject().put("type", "control").put("key", call.argument<String>("key") ?: ""))
                    result.success(null)
                }
                "chat" -> {
                    Bus.sender?.invoke(JSONObject().put("type", "chat").put("text", call.argument<String>("text") ?: ""))
                    result.success(null)
                }
                "status" -> result.success(Bus.snapshot())
                else -> result.notImplemented()
            }
        }
    }

    /** Asks for mic (needed by playback capture) + notifications. False = asked, user must retry. */
    private fun ensurePermissions(): Boolean {
        val needed = arrayOf(
            android.Manifest.permission.RECORD_AUDIO,
            android.Manifest.permission.POST_NOTIFICATIONS)
            .filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (needed.isEmpty()) return true
        requestPermissions(needed.toTypedArray(), 1002)
        return false
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != reqProjection) return
        val res = pendingResult
        pendingResult = null
        if (resultCode == Activity.RESULT_OK && data != null) {
            startForegroundService(Intent(this, CaptureService::class.java)
                .putExtra(CaptureService.EXTRA_RESULT_CODE, resultCode)
                .putExtra(CaptureService.EXTRA_DATA, data)
                .putExtra(CaptureService.EXTRA_URL, pendingUrl))
            res?.success(true)
        } else {
            res?.success(false)
        }
    }
}
