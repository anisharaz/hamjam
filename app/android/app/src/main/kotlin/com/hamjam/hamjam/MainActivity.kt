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
    private val reqSwapRequest = 1003
    private val reqSwapAccept = 1004
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
                    val url = call.argument<String>("url")!!
                    withPermissions(needMic = true, onDenied = { result.success(false) }) {
                        pendingUrl = url
                        pendingResult = result
                        askProjection(reqProjection)
                    }
                }
                "stopHost" -> {
                    startService(Intent(this, CaptureService::class.java).setAction(CaptureService.ACTION_STOP))
                    result.success(null)
                }
                "join" -> {
                    val url = call.argument<String>("url")
                    val code = call.argument<String>("code")
                    // listening needs no microphone; notifications are nice-to-have
                    withPermissions(needMic = false, onDenied = { result.success(false) }) {
                        startForegroundService(Intent(this, GuestService::class.java)
                            .putExtra(GuestService.EXTRA_URL, url)
                            .putExtra(GuestService.EXTRA_CODE, code))
                        result.success(true)
                    }
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
                "swapRequest" -> {
                    if (Bus.role == "guest") {
                        // becoming host needs the screen-capture consent up front
                        withPermissions(needMic = true, onDenied = { result.success(false) }) {
                            pendingResult = result
                            askProjection(reqSwapRequest)
                        }
                    } else {
                        Bus.swapEvent("waiting")
                        Bus.sender?.invoke(JSONObject().put("type", "swap_request"))
                        result.success(true)
                    }
                }
                "swapRespond" -> {
                    val accept = call.argument<Boolean>("accept") == true
                    if (accept && Bus.role == "guest") {
                        // accepting means this phone will host: get consent first
                        withPermissions(needMic = true, onDenied = { respondSwap(false); result.success(false) }) {
                            pendingResult = result
                            askProjection(reqSwapAccept)
                        }
                    } else {
                        respondSwap(accept)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun askProjection(code: Int) {
        val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        @Suppress("DEPRECATION")
        startActivityForResult(mgr.createScreenCaptureIntent(), code)
    }

    private fun respondSwap(accept: Boolean) {
        Bus.swapEvent("cancelled")
        Bus.sender?.invoke(JSONObject().put("type", "swap_response").put("accept", accept))
    }

    private var afterPermissions: ((Boolean) -> Unit)? = null

    /**
     * Runs [block] once the needed runtime permissions are sorted out: immediately if
     * already granted, otherwise after the user answers the system dialog.
     * [onDenied] runs instead if the microphone (when [needMic]) is refused.
     */
    private fun withPermissions(needMic: Boolean, onDenied: () -> Unit, block: () -> Unit) {
        val wanted = arrayOf(
            android.Manifest.permission.RECORD_AUDIO,
            android.Manifest.permission.POST_NOTIFICATIONS)
            .filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (wanted.isEmpty()) { block(); return }
        afterPermissions = { micGranted ->
            if (!needMic || micGranted) block() else onDenied()
        }
        requestPermissions(wanted.toTypedArray(), 1002)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 1002) return
        val cb = afterPermissions
        afterPermissions = null
        // RECORD_AUDIO may not be in the request if it was already granted
        val micAsked = permissions.indexOf(android.Manifest.permission.RECORD_AUDIO)
        val micGranted = if (micAsked >= 0) grantResults[micAsked] == PackageManager.PERMISSION_GRANTED
            else checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        cb?.invoke(micGranted)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val res = pendingResult
        pendingResult = null
        val granted = resultCode == Activity.RESULT_OK && data != null
        if (requestCode == reqSwapRequest) {
            if (granted) {
                Swap.store(resultCode, data!!)
                Bus.swapEvent("waiting")
                Bus.sender?.invoke(JSONObject().put("type", "swap_request"))
            }
            res?.success(granted)
            return
        }
        if (requestCode == reqSwapAccept) {
            if (granted) Swap.store(resultCode, data!!)
            respondSwap(granted)
            res?.success(granted)
            return
        }
        if (requestCode != reqProjection) return
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
