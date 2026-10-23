package com.hamjam.hamjam

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.IBinder
import android.util.Base64
import org.json.JSONObject
import java.nio.ByteOrder
import kotlin.math.sqrt

/**
 * Host side. Opens a room on the relay, then captures all media audio
 * (not calls/notifications), encodes it to AAC and streams it to guests.
 * Guest control presses arrive from the relay and become media keys.
 */
class CaptureService : Service(), Relay.Listener {
    companion object {
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"
        const val EXTRA_URL = "url"
        const val EXTRA_CODE = "code"
        const val EXTRA_TOKEN = "token"
        const val ACTION_STOP = "stop"
        const val SAMPLE_RATE = 48000
        const val CHANNELS = 2
    }

    @Volatile private var running = false
    private var projection: MediaProjection? = null
    private var record: AudioRecord? = null
    private var encoder: MediaCodec? = null
    private var relay: Relay? = null
    private var thread: Thread? = null
    private var closing = false
    private var claimCode = ""
    private var claimToken = ""
    private val keepAlive by lazy { KeepAlive(this) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            shutdown("stopped")
            return START_NOT_STICKY
        }
        startForegroundNotification()

        val resultCode = intent!!.getIntExtra(EXTRA_RESULT_CODE, 0)
        @Suppress("DEPRECATION")
        val data = intent.getParcelableExtra<Intent>(EXTRA_DATA)!!
        val url = intent.getStringExtra(EXTRA_URL)!!
        claimCode = intent.getStringExtra(EXTRA_CODE) ?: ""
        claimToken = intent.getStringExtra(EXTRA_TOKEN) ?: ""

        try {
            val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val proj = mgr.getMediaProjection(resultCode, data)!!
            proj.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() = shutdown("stopped")
            }, null)
            projection = proj
            keepAlive.acquire()
            val r = Relay(url, this)
            relay = r
            Bus.begin("host", url) { r.sendJson(it) }
            r.connect()
        } catch (e: Exception) {
            shutdown("error: ${e.message}")
        }
        return START_NOT_STICKY
    }

    // ---- relay events (OkHttp threads) ----

    override fun onOpen() {
        relay?.sendJson(
            if (claimToken.isNotEmpty()) JSONObject().put("type", "claim").put("code", claimCode).put("token", claimToken)
            else JSONObject().put("type", "create"))
    }

    override fun onMessage(msg: JSONObject) {
        when (msg.optString("type")) {
            "created" -> {
                Bus.emit("code" to msg.getString("code"))
                refreshNotification()
                startCapture()
            }
            "guests" -> {
                Bus.emit("guests" to msg.getInt("count"))
                refreshNotification()
            }
            "control" -> MediaKeys.send(this, msg.optString("key"))
            "swap_request" -> Bus.swapEvent("request", msg.optString("from"))
            "swap_cancelled" -> Bus.swapEvent("cancelled")
            "swap_declined" -> { Swap.clear(); Bus.swapEvent("declined") }
            "swap_go" -> if (msg.optString("newRole") == "guest") handOver()
            "error" -> shutdown("error: ${msg.optString("error")}")
            "chat" -> Bus.addChat(msg.optString("from"), msg.optString("text"), msg.optLong("ts"))
        }
    }

    override fun onAudio(frame: ByteArray) {}

    override fun onClosed(reason: String) = shutdown("disconnected: $reason")

    /** Approved swap: stop sharing, rejoin the same room as a listener. */
    private fun handOver() {
        val url = Bus.url
        val code = Bus.code
        Bus.swapping = true
        shutdown("swap")
        startForegroundService(Intent(this, GuestService::class.java)
            .putExtra(GuestService.EXTRA_URL, url)
            .putExtra(GuestService.EXTRA_CODE, code))
    }

    // ---- capture + encode ----

    private fun startCapture() {
        try {
            val config = AudioPlaybackCaptureConfiguration.Builder(projection!!)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
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

            val enc = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            enc.configure(MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, SAMPLE_RATE, CHANNELS).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
            }, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            enc.start()

            record = rec
            encoder = enc
            running = true
            rec.startRecording()
            Bus.emit("state" to "capturing")
            thread = Thread { captureLoop(rec, enc) }.also { it.start() }
        } catch (e: Exception) {
            shutdown("error: ${e.message}")
        }
    }

    private fun captureLoop(rec: AudioRecord, enc: MediaCodec) {
        val buf = ShortArray(SAMPLE_RATE / 50 * CHANNELS)  // 20 ms
        val info = MediaCodec.BufferInfo()
        var ptsUs = 0L
        var lastReport = 0L
        var lastPoll = 0L
        var lastPlaying: Boolean? = null
        val audio = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
        try {
            while (running) {
                val n = rec.read(buf, 0, buf.size)
                if (n <= 0) continue

                val idx = enc.dequeueInputBuffer(10_000)
                if (idx >= 0) {
                    val ib = enc.getInputBuffer(idx)!!
                    ib.clear()
                    ib.order(ByteOrder.nativeOrder()).asShortBuffer().put(buf, 0, n)
                    enc.queueInputBuffer(idx, 0, n * 2, ptsUs, 0)
                    ptsUs += n / CHANNELS * 1_000_000L / SAMPLE_RATE
                }
                drain(enc, info)

                val now = System.currentTimeMillis()
                if (now - lastPoll >= 400) {
                    lastPoll = now
                    val p = audio.isMusicActive
                    if (p != lastPlaying) {
                        lastPlaying = p
                        Bus.emit("playing" to p)
                        relay?.sendJson(JSONObject().put("type", "playback").put("playing", p))
                    }
                }
                if (now - lastReport >= 100) {
                    lastReport = now
                    var sum = 0.0
                    for (i in 0 until n) sum += buf[i].toDouble() * buf[i]
                    Bus.emit("level" to sqrt(sum / n) / Short.MAX_VALUE)
                }
            }
        } catch (e: Exception) {
            if (running) shutdown("error: ${e.message}")
        }
    }

    private fun drain(enc: MediaCodec, info: MediaCodec.BufferInfo) {
        while (true) {
            val oi = enc.dequeueOutputBuffer(info, 0)
            if (oi == MediaCodec.INFO_TRY_AGAIN_LATER) return
            if (oi < 0) continue
            val ob = enc.getOutputBuffer(oi)!!
            val bytes = ByteArray(info.size)
            ob.position(info.offset)
            ob.get(bytes)
            if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                relay?.sendJson(JSONObject()
                    .put("type", "meta")
                    .put("sampleRate", SAMPLE_RATE)
                    .put("channels", CHANNELS)
                    .put("csd", Base64.encodeToString(bytes, Base64.NO_WRAP)))
            } else if (info.size > 0) {
                relay?.sendAudio(bytes)
            }
            enc.releaseOutputBuffer(oi, false)
        }
    }

    // ---- lifecycle ----

    private fun startForegroundNotification() {
        startForeground(JamNotification.ID_HOST, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
    }

    private fun notification() =
        JamNotification.build(this, true, Bus.code, Bus.guests, CaptureService::class.java)

    private fun refreshNotification() = JamNotification.update(this, JamNotification.ID_HOST, notification())

    @Synchronized
    private fun shutdown(state: String) {
        if (!running && relay == null && projection == null) return
        if (closing) return  // projection.stop() calls back into shutdown
        closing = true
        running = false
        if (Thread.currentThread() !== thread) thread?.join(500)
        thread = null
        try { record?.stop() } catch (_: Exception) {}
        record?.release(); record = null
        try { encoder?.stop() } catch (_: Exception) {}
        encoder?.release(); encoder = null
        relay?.close(); relay = null
        projection?.stop(); projection = null
        keepAlive.release()
        if (state != "swap") Bus.end(state)
        stopSelf()
    }

    override fun onDestroy() {
        shutdown("stopped")
        super.onDestroy()
    }
}
