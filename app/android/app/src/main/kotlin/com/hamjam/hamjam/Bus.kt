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
    private val chat = CopyOnWriteArrayList<Map<String, Any>>()

    fun begin(role: String, sender: (JSONObject) -> Unit) {
        this.role = role; this.sender = sender
        state = "connecting"; code = ""; guests = 0; chat.clear()
        emit("state" to state)
    }

    fun end(finalState: String) {
        role = ""; sender = null; state = finalState; code = ""; guests = 0
        chat.clear()
        sink?.invoke(mapOf("state" to finalState))
    }

    fun emit(vararg kv: Pair<String, Any>) {
        for ((k, v) in kv) when (k) {
            "state" -> state = v as String
            "code" -> code = v as String
            "guests" -> guests = v as Int
        }
        sink?.invoke(mapOf(*kv))
    }

    fun addChat(from: String, text: String, ts: Long) {
        val m = mapOf<String, Any>("from" to from, "text" to text, "ts" to ts)
        chat.add(m)
        while (chat.size > 100) chat.removeAt(0)
        sink?.invoke(mapOf("chat" to m))
    }

    fun snapshot(): Map<String, Any> = mapOf(
        "role" to role, "state" to state, "code" to code, "guests" to guests, "chat" to chat.toList())
}
