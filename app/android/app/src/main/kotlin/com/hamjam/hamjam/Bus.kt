package com.hamjam.hamjam

import org.json.JSONObject
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Session state shared between the services and the Flutter UI. Lives as long as
 * the process, so a UI that was closed can read the current session back on reopen.
 * Chat is kept in memory only (last 100 messages) and dropped when the session ends.
 */
object Bus {
    @Volatile var sink: ((Map<String, Any>) -> Unit)? = null
    /** Set by the running service: sends a JSON message to the relay. */
    @Volatile var sender: ((JSONObject) -> Unit)? = null

    @Volatile var role = ""          // "host" | "guest" | "" (no active session)
    @Volatile var state = "idle"
    @Volatile var code = ""
    @Volatile var guests = 0
    @Volatile var playing = false
    @Volatile var url = ""
    /** Role swap in flight: services hand over to each other without ending the session. */
    @Volatile var swapping = false
    /** True while the app is on screen (then the in-app dialog is enough, no notification). */
    @Volatile var uiVisible = false
    @Volatile var swapIn = ""        // who asked us to swap: "host" | "guest" | ""
    @Volatile var swapOut = false    // we asked and are waiting for an answer
    private val chat = CopyOnWriteArrayList<Map<String, Any>>()
    /** Messages received while the app was off screen (shown in the notification). */
    val unread = CopyOnWriteArrayList<String>()

    fun begin(role: String, url: String, sender: (JSONObject) -> Unit) {
        val keep = swapping   // after a role swap the room code and chat carry over
        this.role = role; this.sender = sender; this.url = url
        state = "connecting"; guests = 0; playing = false
        swapIn = ""; swapOut = false; swapping = false
        if (!keep) { code = ""; chat.clear() }
        emit("role" to role, "state" to state, "code" to code)
    }

    fun end(finalState: String) {
        role = ""; sender = null; state = finalState; code = ""; guests = 0; playing = false
        swapIn = ""; swapOut = false; swapping = false
        chat.clear()
        sink?.invoke(mapOf("state" to finalState))
    }

    fun emit(vararg kv: Pair<String, Any>) {
        for ((k, v) in kv) when (k) {
            "state" -> state = v as String
            "code" -> code = v as String
            "guests" -> guests = v as Int
            "playing" -> playing = v as Boolean
        }
        sink?.invoke(mapOf(*kv))
    }

    /** kind: request (from = who asked) | declined | cancelled | waiting */
    fun swapEvent(kind: String, from: String = "") {
        when (kind) {
            "request" -> swapIn = from
            "waiting" -> swapOut = true
            "declined" -> swapOut = false
            "cancelled" -> swapIn = ""
        }
        sink?.invoke(mapOf("swap" to mapOf("kind" to kind, "from" to from)))
    }

    fun addChat(from: String, text: String, ts: Long) {
        val m = mapOf<String, Any>("from" to from, "text" to text, "ts" to ts)
        chat.add(m)
        while (chat.size > 100) chat.removeAt(0)
        sink?.invoke(mapOf("chat" to m))
    }

    fun snapshot(): Map<String, Any> = mapOf(
        "role" to role, "state" to state, "code" to code, "url" to url, "guests" to guests, "playing" to playing, "swapIn" to swapIn, "swapOut" to swapOut, "chat" to chat.toList())
}
