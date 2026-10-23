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
    private const val ID_SWAP = 3
    private const val ID_CHAT = 4
    private const val CHANNEL_SWAP = "swap"
    const val ACTION_SWAP_DECLINE = "swap_decline"
    const val EXTRA_SWAP_ACCEPT = "swap_accept"

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

    /** Heads-up notification for "your partner wants to switch roles", with Accept / Decline. */
    fun showSwapRequest(ctx: Context, from: String, declineTarget: Class<*>) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_SWAP, "Switch requests", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "When your partner asks to switch host and listener"
            })
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        val activity = Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
        val open = PendingIntent.getActivity(ctx, 10, activity, flags)
        val accept = PendingIntent.getActivity(ctx, 11, Intent(activity).putExtra(EXTRA_SWAP_ACCEPT, true), flags)
        val decline = PendingIntent.getService(ctx, 12, Intent(ctx, declineTarget).setAction(ACTION_SWAP_DECLINE), flags)

        val text = if (from == "guest") "Your partner wants to host. You would become the listener."
                   else "Your partner wants you to host. Your phone would share its audio."
        nm.notify(ID_SWAP, Notification.Builder(ctx, CHANNEL_SWAP)
            .setContentTitle("Switch roles?")
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setSmallIcon(android.R.drawable.ic_menu_rotate)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "Accept", accept).build())
            .addAction(Notification.Action.Builder(null, "Decline", decline).build())
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .build())
    }

    fun cancelSwapRequest(ctx: Context) =
        ctx.getSystemService(NotificationManager::class.java).cancel(ID_SWAP)

    /** Heads-up notification for a chat message that arrived while the app is off screen. */
    fun onChat(ctx: Context, from: String, text: String) {
        if (from == Bus.role || Bus.uiVisible) return  // our own echo, or the user is looking at it
        Bus.unread.add(text)
        while (Bus.unread.size > 5) Bus.unread.removeAt(0)

        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel("chat", "Messages", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Chat messages from your partner during a jam"
            })
        val open = PendingIntent.getActivity(
            ctx, 20,
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val lines = Bus.unread.toList()
        val style = Notification.InboxStyle()
        lines.forEach { style.addLine(it) }
        nm.notify(ID_CHAT, Notification.Builder(ctx, "chat")
            .setContentTitle(if (lines.size == 1) "Message from your partner" else "${lines.size} new messages")
            .setContentText(lines.last())
            .setStyle(style)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setContentIntent(open)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .build())
    }

    fun cancelChat(ctx: Context) {
        Bus.unread.clear()
        ctx.getSystemService(NotificationManager::class.java).cancel(ID_CHAT)
    }
}
