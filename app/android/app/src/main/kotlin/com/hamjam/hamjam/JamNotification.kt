package com.hamjam.hamjam

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/** The persistent "HamJam is active" notification shown while a jam runs. */
object JamNotification {
    private const val CHANNEL = "jam"
    const val ID_HOST = 1
    const val ID_GUEST = 2

    fun build(ctx: Context, host: Boolean, code: String, guests: Int, stopTarget: Class<*>): Notification {
        ctx.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Active jam", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shown while HamJam is sharing or playing audio"
            })

        val open = PendingIntent.getActivity(
            ctx, 0,
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(
            ctx, if (host) 1 else 2,
            Intent(ctx, stopTarget).setAction("stop"),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val title = if (host) "HamJam is sharing your audio" else "HamJam is playing a shared jam"
        val text = when {
            code.isEmpty() -> "Connecting…"
            host -> "Code $code · " + if (guests == 1) "1 listener" else "$guests listeners"
            else -> "Code $code"
        }
        return Notification.Builder(ctx, CHANNEL)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, if (host) "End jam" else "Leave", stop).build())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    fun update(ctx: Context, id: Int, n: Notification) =
        ctx.getSystemService(NotificationManager::class.java).notify(id, n)
}
