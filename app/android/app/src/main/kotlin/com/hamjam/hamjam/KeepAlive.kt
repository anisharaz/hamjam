package com.hamjam.hamjam

import android.content.Context
import android.net.wifi.WifiManager
import android.os.PowerManager

/** Keeps CPU and Wi-Fi awake while a jam is running in the background. */
class KeepAlive(ctx: Context) {
    private val wake = (ctx.getSystemService(Context.POWER_SERVICE) as PowerManager)
        .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "hamjam:jam")
    private val wifi = (ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
        .createWifiLock(WifiManager.WIFI_MODE_FULL_LOW_LATENCY, "hamjam:jam")

    fun acquire() {
        if (!wake.isHeld) wake.acquire(6 * 60 * 60 * 1000L)  // safety cap: 6 h
        if (!wifi.isHeld) wifi.acquire()
    }

    fun release() {
        if (wake.isHeld) wake.release()
        if (wifi.isHeld) wifi.release()
    }
}
