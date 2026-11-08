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
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation

/**
 * Short-lived: started by [DriveWakeReceiver] when the phone enters a vehicle. It
 * runs the app's Dart entry point in its own Flutter engine (so it works with the
 * app closed); that code starts the trip -- which brings up the real tracking
 * service -- and then reports "finished" and this service stops. It also stops by
 * itself after [MAX_LIFETIME_MS] whatever happens.
 */
class DriveWakeService : Service() {
    private var engine: FlutterEngine? = null
    private var bgChannel: MethodChannel? = null
    private val handler = Handler(Looper.getMainLooper())
    // Set by the engine while it carries a trip: no time limit, and its notice
    // hidden while the trip's own tracking notice shows (kept while paused).
    private var keptForTrip = false
    private var keptNotice = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        showForeground()
        // Already running: it is the one trip engine, tell it what happened.
        if (engine == null) startEngine() else bgChannel?.invokeMethod("wake", null)
        if (keptForTrip) {
            if (!keptNotice) stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            handler.removeCallbacksAndMessages(null)
            handler.postDelayed({ stopSelf() }, MAX_LIFETIME_MS)
        }
        return START_NOT_STICKY
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

    private fun startEngine() {
        val handle = getSharedPreferences(DriveWakeRegistrar.PREFS, Context.MODE_PRIVATE)
            .getLong(DriveWakeRegistrar.KEY_HANDLE, 0L)
        if (handle == 0L) {
            Log.w(TAG, "No Dart entry point saved; stopping")
            stopSelf()
            return
        }
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        // Registers the app's plugins (Supabase storage, Tracelet, ...) too.
        val e = FlutterEngine(applicationContext)
        engine = e
        val channel = MethodChannel(e.dartExecutor.binaryMessenger, BG_CHANNEL)
        bgChannel = channel
        channel.setMethodCallHandler { call, result ->
            if (call.method == "finished") {
                result.success(null)
                stopSelf()
            } else if (call.method == "keepAlive") {
                keptForTrip = true
                keptNotice = call.argument<Boolean>("notice") ?: false
                handler.removeCallbacksAndMessages(null)
                if (keptNotice) showForeground() else stopForeground(STOP_FOREGROUND_REMOVE)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        val info = FlutterCallbackInformation.lookupCallbackInformation(handle)
        if (info == null) {
            Log.w(TAG, "Dart entry point not found; stopping")
            stopSelf()
            return
        }
        e.dartExecutor.executeDartCallback(
            DartExecutor.DartCallback(assets, loader.findAppBundlePath(), info)
        )
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        bgChannel = null
        engine?.destroy()
        engine = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "CmDriveWake"
        private const val CHANNEL = "controlmiles_drive_wake"
        private const val BG_CHANNEL = "controlmiles/drive_wake_bg"
        private const val NOTIFICATION_ID = 7702
        private const val MAX_LIFETIME_MS = 4 * 60 * 1000L
    }
}
