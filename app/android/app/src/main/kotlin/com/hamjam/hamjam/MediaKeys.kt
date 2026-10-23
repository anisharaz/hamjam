package com.hamjam.hamjam

import android.content.Context
import android.media.AudioManager
import android.view.KeyEvent

object MediaKeys {
    /** Sends a media key to whichever app currently owns the media session. */
    fun send(ctx: Context, key: String): Boolean {
        val code = when (key) {
            "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
            "playPause" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
            "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> return false
        }
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
        return true
    }

    /** Pauses whatever is playing (no-op if nothing is). */
    fun pauseIfPlaying(ctx: Context) {
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (am.isMusicActive) send(ctx, "pause")
    }
}
