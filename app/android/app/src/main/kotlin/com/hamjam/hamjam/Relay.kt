package com.hamjam.hamjam

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import okio.ByteString.Companion.toByteString
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** Thin WebSocket client for the HamJam relay server. */
class Relay(private val url: String, private val l: Listener) {
    interface Listener {
        fun onOpen()
        fun onMessage(msg: JSONObject)
        fun onAudio(frame: ByteArray)
        fun onClosed(reason: String)
    }

    private val client = OkHttpClient.Builder()
        .pingInterval(20, TimeUnit.SECONDS)
        .build()
    private var ws: WebSocket? = null
    @Volatile private var closed = false

    fun connect() {
        ws = client.newWebSocket(Request.Builder().url(url).build(), object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) = l.onOpen()
            override fun onMessage(webSocket: WebSocket, text: String) {
                try { l.onMessage(JSONObject(text)) } catch (_: Exception) {}
            }
            override fun onMessage(webSocket: WebSocket, bytes: ByteString) = l.onAudio(bytes.toByteArray())
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) = fire("closed")
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) =
                fire(t.message ?: "connection failed")
        })
    }

    private fun fire(reason: String) { if (!closed) { closed = true; l.onClosed(reason) } }

    fun sendJson(o: JSONObject) { ws?.send(o.toString()) }

    fun sendAudio(frame: ByteArray) {
        val w = ws ?: return
        if (w.queueSize() < 256 * 1024) w.send(frame.toByteString())  // drop if the link is backed up
    }

    fun close() { closed = true; ws?.close(1000, null); client.dispatcher.executorService.shutdown() }
}
