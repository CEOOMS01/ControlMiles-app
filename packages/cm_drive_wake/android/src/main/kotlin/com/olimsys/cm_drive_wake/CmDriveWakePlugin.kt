package com.olimsys.cm_drive_wake

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** App-facing side: arm / disarm the wake-ups and read what woke the app. */
class CmDriveWakePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "controlmiles/drive_wake").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("no_context", "No context", null)
        val prefs = ctx.getSharedPreferences(DriveWakeRegistrar.PREFS, Context.MODE_PRIVATE)
        when (call.method) {
            "register" -> {
                prefs.edit().putBoolean(DriveWakeRegistrar.KEY_ARMED, true).apply()
                DriveWakeRegistrar.register(ctx) { ok -> result.success(ok) }
                // Fence around where the phone is now, so the first drive is also caught.
                DriveWakeRegistrar.refreshFenceHere(ctx)
            }
            "unregister" -> {
                prefs.edit().putBoolean(DriveWakeRegistrar.KEY_ARMED, false).apply()
                DriveWakeRegistrar.unregister(ctx)
                result.success(true)
            }
            "refreshFence" -> {
                if (DriveWakeRegistrar.isArmed(ctx)) {
                    // Where the trip ended, when the app knows it (2026-11-11); else ask now.
                    val lat = call.argument<Double>("lat")
                    val lng = call.argument<Double>("lng")
                    if (lat != null && lng != null) DriveWakeRegistrar.setFence(ctx, lat, lng)
                    else DriveWakeRegistrar.refreshFenceHere(ctx)
                }
                result.success(true)
            }
            "isArmed" -> result.success(DriveWakeRegistrar.isArmed(ctx))
            // A trip needs the engine kept alive (the app, or Tracelet with no engine).
            "startEngine" -> {
                prefs.edit().putString(DriveWakeRegistrar.KEY_WAKE_SOURCE, "app").apply()
                try {
                    androidx.core.content.ContextCompat.startForegroundService(
                        ctx, android.content.Intent(ctx, DriveWakeService::class.java)
                    )
                    result.success(true)
                } catch (e: Exception) {
                    result.error("start_failed", e.message, null)
                }
            }
            // What woke the app ("vehicle" or "fence") and where the phone was parked.
            "wakeInfo" -> {
                val a = DriveWakeRegistrar.anchor(ctx)
                result.success(
                    mapOf(
                        "source" to (prefs.getString(DriveWakeRegistrar.KEY_WAKE_SOURCE, "vehicle") ?: "vehicle"),
                        "lat" to a?.get(0),
                        "lng" to a?.get(1),
                        "atMs" to a?.get(2)?.toLong(),
                    )
                )
            }
            else -> result.notImplemented()
        }
    }
}
