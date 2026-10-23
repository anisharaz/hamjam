package com.hamjam.hamjam

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaCodec
import android.media.MediaFormat
import android.os.IBinder
import android.util.Base64
import org.json.JSONObject
import java.nio.ByteBuffer
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/** Guest side: joins a room, decodes the host's AAC stream and plays it. */
class GuestService : Service(), Relay.Listener {
    companion object {
        const val EXTRA_URL = "url"
        const val EXTRA_CODE = "code"
        const val ACTION_STOP = "stop"
        private const val MAX_QUEUED_FRAMES = 60  // ~1.3 s; beyond that drop the oldest to stay live

        @Volatile private var current: GuestService? = null
    }

    private var relay: Relay? = null
    private var code = ""
    private val frames = LinkedBlockingQueue<ByteArray>()
    @Volatile private var playing = false
    private var player: Thread? = null
    private val keepAlive by lazy { KeepAlive(this) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == JamNotification.ACTION_SWAP_DECLINE) {
            Bus.sender?.invoke(JSONObject().put("type", "swap_response").put("accept", false))
            Bus.swapEvent("cancelled")
            JamNotification.cancelSwapRequest(this)
            if (Bus.role.isEmpty()) stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_STOP) { shutdown("left"); return START_NOT_STICKY }
        startForegroundNotification()
        code = intent!!.getStringExtra(EXTRA_CODE)!!
        current = this
        keepAlive.acquire()
        val r = Relay(intent.getStringExtra(EXTRA_URL)!!, this)
        relay = r
        Bus.begin("guest", intent.getStringExtra(EXTRA_URL)!!) { r.sendJson(it) }
        Bus.emit("code" to code)
        refreshNotification()
        r.connect()
        return START_NOT_STICKY
    }

    override fun onOpen() {
        relay?.sendJson(JSONObject().put("type", "join").put("code", code))
    }

    override fun onMessage(msg: JSONObject) {
        when (msg.optString("type")) {
            "joined" -> Bus.emit("state" to "connected")
            "error" -> shutdown(if (msg.optString("error") == "room_not_found") "room not found" else "error")
            "swap_request" -> {
                val from = msg.optString("from")
                Bus.swapEvent("request", from)
                if (!Bus.uiVisible) JamNotification.showSwapRequest(this, from, GuestService::class.java)
            }
            "swap_cancelled" -> { Bus.swapEvent("cancelled"); JamNotification.cancelSwapRequest(this) }
            "swap_declined" -> { Swap.clear(); Bus.swapEvent("declined") }
            "swap_go" -> if (msg.optString("newRole") == "host") takeOver(msg.optString("token"))
            "playback" -> Bus.emit("playing" to msg.optBoolean("playing"))
            "chat" -> {
                val from = msg.optString("from")
                val text = msg.optString("text")
                Bus.addChat(from, text, msg.optLong("ts"))
                JamNotification.onChat(this, from, text)
            }
            "ended" -> shutdown("the host ended the jam")
            "meta" -> if (msg.has("csd")) startPlayer(
                msg.getInt("sampleRate"), msg.getInt("channels"),
                Base64.decode(msg.getString("csd"), Base64.NO_WRAP))
        }
    }

    /** Approved swap: stop listening and start sharing in the same room. */
    private fun takeOver(token: String) {
        val data = Swap.data
        if (data == null) { shutdown("error: screen-capture permission missing"); return }
        val i = Intent(this, CaptureService::class.java)
            .putExtra(CaptureService.EXTRA_RESULT_CODE, Swap.resultCode)
            .putExtra(CaptureService.EXTRA_DATA, data)
            .putExtra(CaptureService.EXTRA_URL, Bus.url)
            .putExtra(CaptureService.EXTRA_CODE, code)
            .putExtra(CaptureService.EXTRA_TOKEN, token)
        Swap.clear()
        Bus.swapping = true
        shutdown("swap")
        startForegroundService(i)
    }

    override fun onAudio(frame: ByteArray) {
        while (frames.size >= MAX_QUEUED_FRAMES) frames.poll()
        frames.offer(frame)
    }

    override fun onClosed(reason: String) = shutdown("disconnected: $reason")

    @Synchronized
    private fun startPlayer(sampleRate: Int, channels: Int, csd: ByteArray) {
        if (playing) return
        playing = true
        player = Thread {
            var dec: MediaCodec? = null
            var track: AudioTrack? = null
            try {
                val fmt = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channels)
                fmt.setByteBuffer("csd-0", ByteBuffer.wrap(csd))
                dec = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
                dec.configure(fmt, null, null, 0)
                dec.start()

                val mask = if (channels == 1) AudioFormat.CHANNEL_OUT_MONO else AudioFormat.CHANNEL_OUT_STEREO
                val minBuf = AudioTrack.getMinBufferSize(sampleRate, mask, AudioFormat.ENCODING_PCM_16BIT)
                track = AudioTrack.Builder()
                    .setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                    .setAudioFormat(AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate).setChannelMask(mask).build())
                    .setBufferSizeInBytes(minBuf * 4)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
                track.play()
                Bus.emit("state" to "listening")

                val info = MediaCodec.BufferInfo()
                var pts = 0L
                var lastLevel = 0L
                while (playing) {
                    val f = frames.poll(20, TimeUnit.MILLISECONDS)
                    if (f != null) {
                        val idx = dec.dequeueInputBuffer(5_000)
                        if (idx >= 0) {
                            val ib = dec.getInputBuffer(idx)!!
                            ib.clear(); ib.put(f)
                            dec.queueInputBuffer(idx, 0, f.size, pts, 0)
                            pts += 1024L * 1_000_000 / sampleRate
                        }
                    }
                    while (true) {
                        val oi = dec.dequeueOutputBuffer(info, 0)
                        if (oi == MediaCodec.INFO_TRY_AGAIN_LATER) break
                        if (oi < 0) continue
                        val ob = dec.getOutputBuffer(oi)!!
                        val pcm = ByteArray(info.size)
                        ob.position(info.offset); ob.get(pcm)
                        dec.releaseOutputBuffer(oi, false)
                        track.write(pcm, 0, pcm.size)
                        val now = System.currentTimeMillis()
                        if (now - lastLevel >= 100) {
                            lastLevel = now
                            val sb = ByteBuffer.wrap(pcm).order(java.nio.ByteOrder.nativeOrder()).asShortBuffer()
                            var sum = 0.0
                            val n = sb.remaining()
                            for (i in 0 until n) { val v = sb.get(i).toDouble(); sum += v * v }
                            if (n > 0) Bus.emit("level" to kotlin.math.sqrt(sum / n) / Short.MAX_VALUE)
                        }
                    }
                }
            } catch (e: Exception) {
                if (playing) shutdown("error: ${e.message}")
            } finally {
                try { track?.stop() } catch (_: Exception) {}
                track?.release()
                try { dec?.stop() } catch (_: Exception) {}
                dec?.release()
            }
        }.also { it.start() }
    }

    private fun startForegroundNotification() {
        startForeground(JamNotification.ID_GUEST, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
    }

    private fun notification() =
        JamNotification.build(this, false, Bus.code, Bus.guests, GuestService::class.java)

    private fun refreshNotification() = JamNotification.update(this, JamNotification.ID_GUEST, notification())

    @Synchronized
    private fun shutdown(state: String) {
        if (current !== this) return
        current = null
        playing = false
        if (Thread.currentThread() !== player) player?.join(500)
        player = null
        relay?.close(); relay = null
        keepAlive.release()
        JamNotification.cancelSwapRequest(this)
        JamNotification.cancelChat(this)
        if (state != "swap") Bus.end(state)
        stopSelf()
    }

    override fun onDestroy() {
        shutdown("left")
        super.onDestroy()
    }
}
