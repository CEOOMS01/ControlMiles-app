package com.olimsys.cm_drive_wake

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Keeps the app's engine (see SharedEngine) running in the background: when a drive
 * may be starting, while a trip is open, and when Tracelet has a fix for an open
 * trip with the app closed. The Dart side (TripHost) tells it to hold the engine
 * for a trip and to let go when nothing is left to do; it also stops by itself
 * after [MAX_LIFETIME_MS] unless it is holding a trip.
 */
class DriveWakeService : Service() {
    private var engine: FlutterEngine? = null
    private var bgChannel: MethodChannel? = null
    private val handler = Handler(Looper.getMainLooper())
    // A drive check the Dart side has not picked up yet.
    private var pendingWake = false
    // Set by the Dart side while a trip is open: no time limit, and this notice
    // hidden while the trip's own tracking notice shows (kept while paused).
    private var keptForTrip = false
    private var keptNotice = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        showForeground()
        SharedEngine.serviceRunning = true
        val source = getSharedPreferences(DriveWakeRegistrar.PREFS, Context.MODE_PRIVATE)
            .getString(DriveWakeRegistrar.KEY_WAKE_SOURCE, "vehicle")
        if (source != "app") pendingWake = true
        if (engine == null) attachEngine() else deliverWake()
        if (keptForTrip) {
            if (!keptNotice) stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            handler.removeCallbacksAndMessages(null)
            handler.postDelayed({ stopSelf() }, MAX_LIFETIME_MS)
        }
        return START_NOT_STICKY
    }

    private fun deliverWake() {
        if (!pendingWake) return
        bgChannel?.invokeMethod("wake", null, object : MethodChannel.Result {
            override fun success(result: Any?) { pendingWake = false }
            override fun error(code: String, message: String?, details: Any?) {}
            override fun notImplemented() {}
        })
    }

    private fun showForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "ControlMiles drive check", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val spanish = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.controlmiles_lang", "en") == "es"
        val icon = resources.getIdentifier("ic_stat_tracking", "drawable", packageName)
            .takeIf { it != 0 } ?: android.R.drawable.ic_menu_mylocation
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(icon)
            .setContentTitle("ControlMiles")
            .setContentText(if (spanish) "Revisando tu manejo…" else "Checking your drive…")
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun attachEngine() {
        val (e, created) = SharedEngine.obtain(this)
        engine = e
        val channel = MethodChannel(e.dartExecutor.binaryMessenger, BG_CHANNEL)
        bgChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // A newly started engine asks once it is ready.
                "hello" -> {
                    result.success(pendingWake)
                    pendingWake = false
                }
                "finished" -> {
                    result.success(null)
                    stopSelf()
                }
                "keepAlive" -> {
                    keptForTrip = true
                    keptNotice = call.argument<Boolean>("notice") ?: false
                    handler.removeCallbacksAndMessages(null)
                    if (keptNotice) showForeground() else stopForeground(STOP_FOREGROUND_REMOVE)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // An engine that was already running (the screen is open) gets told now.
        if (!created) deliverWake()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        bgChannel?.setMethodCallHandler(null)
        bgChannel = null
        engine = null
        SharedEngine.serviceRunning = false
        SharedEngine.releaseIfUnused()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "controlmiles_drive_wake"
        private const val BG_CHANNEL = "controlmiles/drive_wake_bg"
        private const val NOTIFICATION_ID = 7702
        private const val MAX_LIFETIME_MS = 4 * 60 * 1000L
    }
}
