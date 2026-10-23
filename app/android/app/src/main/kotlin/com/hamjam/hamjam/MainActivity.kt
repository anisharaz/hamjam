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

class MainActivity : FlutterActivity() {
    private val reqProjection = 1001
    private val main = Handler(Looper.getMainLooper())
    private var events: EventChannel.EventSink? = null
    private var pendingUid = -1
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "hamjam/capture_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                    CaptureService.onLevel = { lvl -> main.post { events?.success(mapOf("level" to lvl)) } }
                    CaptureService.onState = { st -> main.post { events?.success(mapOf("state" to st)) } }
                }
                override fun onCancel(args: Any?) {
                    events = null
                    CaptureService.onLevel = null
                    CaptureService.onState = null
                }
            })

        MethodChannel(messenger, "hamjam/capture").setMethodCallHandler { call, result ->
            when (call.method) {
                "listApps" -> result.success(listApps())
                "start" -> {
                    val needed = arrayOf(
                        android.Manifest.permission.RECORD_AUDIO,
                        android.Manifest.permission.POST_NOTIFICATIONS)
                        .filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
                    if (needed.isNotEmpty()) {
                        requestPermissions(needed.toTypedArray(), 1002)
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    pendingUid = call.argument<Int>("uid")!!
                    pendingResult = result
                    val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    @Suppress("DEPRECATION")
                    startActivityForResult(mgr.createScreenCaptureIntent(), reqProjection)
                }
                "stop" -> {
                    startService(Intent(this, CaptureService::class.java)
                        .setAction(CaptureService.ACTION_STOP))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != reqProjection) return
        val res = pendingResult
        pendingResult = null
        if (resultCode == Activity.RESULT_OK && data != null) {
            val i = Intent(this, CaptureService::class.java)
                .putExtra(CaptureService.EXTRA_RESULT_CODE, resultCode)
                .putExtra(CaptureService.EXTRA_DATA, data)
                .putExtra(CaptureService.EXTRA_UID, pendingUid)
            startForegroundService(i)
            res?.success(true)
        } else {
            res?.success(false)
        }
    }

    /** Launchable apps, sorted by name. */
    private fun listApps(): List<Map<String, Any>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName != packageName }
            .map { mapOf(
                "name" to pm.getApplicationLabel(it).toString(),
                "package" to it.packageName,
                "uid" to it.uid) }
            .sortedBy { (it["name"] as String).lowercase() }
    }
}
