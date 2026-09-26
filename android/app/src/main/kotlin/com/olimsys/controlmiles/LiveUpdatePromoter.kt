package com.olimsys.controlmiles

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Asks Android 16+ to show the tracking notification as a "Live Update" (the
 * status-bar chip, the lock-screen live notification and Samsung's Now Bar, the
 * same presentation the Voice Recorder gets).
 *
 * The notification is NOT created here. It is the tracking engine's own
 * foreground-service notification (channel `controlmiles_tracking`), which
 * already meets every Live Update requirement (ongoing, has a title, standard
 * layout with no custom RemoteViews, chronometer, non-minimum channel). All it
 * lacks is the request for promotion, which the engine cannot set, so this
 * re-posts that same notification -- same id, so the foreground service keeps
 * owning it -- with `android.requestPromotedOngoing` added. No second
 * notification, no duplicate entry in the shade.
 *
 * The engine re-posts its notification on its own on some events (for example
 * when the app moves to the background), which drops the request again. A cheap
 * loop on the main thread therefore re-applies it: every 2 s while a tracking
 * notification exists, every 20 s otherwise. It does nothing below Android 16.
 */
object LiveUpdatePromoter {
    private const val TAG = "LiveUpdatePromoter"
    private const val TRACKING_CHANNEL_ID = "controlmiles_tracking"

    // Notification.EXTRA_REQUEST_PROMOTED_ONGOING (API 36.1). The constant is
    // not in the compile SDK's android.jar, the string key is the same.
    private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"

    // Notification.EXTRA_SHOW_CHRONOMETER
    private const val EXTRA_SHOW_CHRONOMETER = "android.showChronometer"

    private const val ACTIVE_INTERVAL_MS = 2_000L
    private const val IDLE_INTERVAL_MS = 20_000L

    private val handler = Handler(Looper.getMainLooper())
    private var appContext: Context? = null

    @Volatile
    private var running = false

    private val loop = object : Runnable {
        override fun run() {
            val ctx = appContext ?: return
            val hasTrackingNotification = try {
                promoteOnce(ctx)
            } catch (t: Throwable) {
                // Never let a cosmetic feature take the app down.
                Log.w(TAG, "promoteOnce failed: ${t.message}")
                false
            }
            handler.postDelayed(
                this,
                if (hasTrackingNotification) ACTIVE_INTERVAL_MS else IDLE_INTERVAL_MS
            )
        }
    }

    /** Safe to call any number of times, from any thread. */
    fun ensureRunning(context: Context) {
        if (Build.VERSION.SDK_INT < 36) return
        appContext = context.applicationContext
        if (running) return
        synchronized(this) {
            if (running) return
            running = true
        }
        handler.post(loop)
    }

    /** Whether the user allows this app's promoted (Live Update) notifications. */
    fun canPromote(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 36) return false
        val nm = context.getSystemService(NotificationManager::class.java) ?: return false
        return nm.canPostPromotedNotifications()
    }

    /**
     * Requests promotion for the tracking notification if it is showing and not
     * yet promoted. Returns true when a tracking notification exists.
     */
    fun promoteOnce(context: Context): Boolean {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return false
        val sbn = nm.activeNotifications.firstOrNull {
            it.packageName == context.packageName &&
                it.notification.channelId == TRACKING_CHANNEL_ID &&
                (it.notification.flags and Notification.FLAG_FOREGROUND_SERVICE) != 0
        } ?: return false

        val notification = sbn.notification
        if (notification.extras.getBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, false)) return true

        // Only a running trip is a Live Update. While auto-detect is just
        // listening for a gig app the notification has no chronometer, and an
        // idle state must not be promoted as if something were in progress
        // (Android's guidance: promote ongoing activities with a start and an end).
        if (!notification.extras.getBoolean(EXTRA_SHOW_CHRONOMETER, false)) return true

        val rebuilt = Notification.Builder.recoverBuilder(context, notification)
            .addExtras(Bundle().apply { putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true) })
            .build()
        nm.notify(sbn.tag, sbn.id, rebuilt)
        Log.i(TAG, "Requested Live Update promotion for notification ${sbn.id}")
        return true
    }
}
