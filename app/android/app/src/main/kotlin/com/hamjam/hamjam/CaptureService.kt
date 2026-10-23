package com.hamjam.hamjam

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.IBinder
import kotlin.math.sqrt

/**
 * Foreground service that captures the audio of ONE app (matched by UID)
 * using AudioPlaybackCapture. For now it only reports the signal level;
 * later the PCM frames feed the WebRTC encoder.
 */
class CaptureService : Service() {
    companion object {
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"
        const val EXTRA_UID = "uid"
        const val ACTION_STOP = "stop"
        const val SAMPLE_RATE = 48000

        // Set by MainActivity; called from the capture thread.
        @Volatile var onLevel: ((Double) -> Unit)? = null
        @Volatile var onState: ((String) -> Unit)? = null
        @Volatile var running = false
    }

    private var projection: MediaProjection? = null
    private var record: AudioRecord? = null
    private var thread: Thread? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopCapture()
            stopSelf()
            return START_NOT_STICKY
        }
        startForegroundNotification()

        val resultCode = intent!!.getIntExtra(EXTRA_RESULT_CODE, 0)
        @Suppress("DEPRECATION")
        val data = intent.getParcelableExtra<Intent>(EXTRA_DATA)!!
        val uid = intent.getIntExtra(EXTRA_UID, -1)

        try {
            val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val proj = mgr.getMediaProjection(resultCode, data)!!
            proj.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() { stopCapture(); stopSelf() }
            }, null)
            projection = proj

            val config = AudioPlaybackCaptureConfiguration.Builder(proj)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .addMatchingUid(uid)
                .build()
            val format = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(SAMPLE_RATE)
                .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
                .build()
            val minBuf = AudioRecord.getMinBufferSize(
                SAMPLE_RATE, AudioFormat.CHANNEL_IN_STEREO, AudioFormat.ENCODING_PCM_16BIT)
            val rec = AudioRecord.Builder()
                .setAudioPlaybackCaptureConfig(config)
                .setAudioFormat(format)
                .setBufferSizeInBytes(minBuf * 2)
                .build()
            record = rec
            rec.startRecording()
            running = true
            onState?.invoke("capturing")

            thread = Thread {
                // 20 ms of stereo 16-bit audio
                val buf = ShortArray(SAMPLE_RATE / 50 * 2)
                var lastReport = 0L
                while (running) {
                    val n = rec.read(buf, 0, buf.size)
                    if (n <= 0) continue
                    val now = System.currentTimeMillis()
                    if (now - lastReport >= 100) {
                        lastReport = now
                        var sum = 0.0
                        for (i in 0 until n) sum += buf[i].toDouble() * buf[i]
                        onLevel?.invoke(sqrt(sum / n) / Short.MAX_VALUE)
                    }
                }
            }.also { it.start() }
        } catch (e: Exception) {
            onState?.invoke("error: ${e.message}")
            stopCapture()
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun startForegroundNotification() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel("jam", "Jam", NotificationManager.IMPORTANCE_LOW))
        val n = Notification.Builder(this, "jam")
            .setContentTitle("HamJam")
            .setContentText("Sharing audio")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()
        startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
    }

    private fun stopCapture() {
        running = false
        thread?.join(500)
        thread = null
        try { record?.stop() } catch (_: Exception) {}
        record?.release()
        record = null
        projection?.stop()
        projection = null
        onState?.invoke("stopped")
    }

    override fun onDestroy() {
        if (running || record != null) stopCapture()
        super.onDestroy()
    }
}
