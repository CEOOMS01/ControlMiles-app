package com.olimsys.cm_usage_access

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Gig-app-in-front detection (Android only). It used to live in MainActivity,
// which only exists while the app is open; as a plugin it is registered in
// every Flutter engine, including the headless one Android starts for GPS
// events while ControlMiles is closed -- so a trip can start by itself with the
// app closed. Usage Access is a "special access" permission (no runtime
// dialog): the driver grants it in Settings, checked here through AppOps.
class CmUsageAccessPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "controlmiles/gig_app_detection").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null) {
            result.error("no_context", "plugin detached", null)
            return
        }
        when (call.method) {
            "hasUsageAccess" -> result.success(hasUsageAccess(ctx))
            "openUsageAccessSettings" -> {
                ctx.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(null)
            }
            "getForegroundPackage" -> result.success(getForegroundPackage(ctx))
            else -> result.notImplemented()
        }
    }

    private fun hasUsageAccess(ctx: Context): Boolean {
        val appOps = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            ctx.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // Last ACTIVITY_RESUMED event in the trailing window = the app most recently
    // brought to the front. A long window (2 h) on purpose: the event fires once,
    // when the app opens, and a driver who opens Uber and then just drives
    // produces no further events (see the 2026-09-16 fix this was moved from).
    private fun getForegroundPackage(ctx: Context): String? {
        val usageManager = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = end - 2 * 60 * 60 * 1000L
        val events = usageManager.queryEvents(start, end)
        val event = UsageEvents.Event()
        var currentPackage: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                currentPackage = event.packageName
            }
        }
        return currentPackage
    }
}
