package com.hamjam.hamjam

import android.content.Intent

/**
 * Screen-capture consent obtained ahead of a role swap. Android only allows the
 * prompt while the app is on screen, so whoever will become host approves it first
 * and the capture service picks it up when the swap goes through.
 */
object Swap {
    @Volatile var resultCode = 0
    @Volatile var data: Intent? = null

    fun store(resultCode: Int, data: Intent) { this.resultCode = resultCode; this.data = data }
    fun clear() { resultCode = 0; data = null }
}
