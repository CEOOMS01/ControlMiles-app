package com.olimsys.controlmiles

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Premium auto-detect feature: gig-app-active detection (Android only,
// no iOS equivalent exists). UsageStatsManager access is a "special
// access" permission -- there's no runtime dialog for it, the user must
// grant it manually via Settings.ACTION_USAGE_ACCESS_SETTINGS, checked
// here via AppOpsManager since PackageManager.checkPermission always
// reports this one as granted regardless of the real Settings toggle.
class MainActivity : FlutterActivity() {
    private val channelName = "controlmiles/gig_app_detection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "openUsageAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "getForegroundPackage" -> result.success(getForegroundPackage())
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // Last ACTIVITY_RESUMED event in the trailing window -- the most
    // recently foregrounded app. A short window on purpose: this is
    // polled periodically by AutoTripDetectionService while auto-detect
    // is armed, so "what's in front right now" is what matters, not a
    // full shift's history.
    private fun getForegroundPackage(): String? {
        val usageManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        // BUG FIX (2026-09-16): this window used to be 60 seconds, which made
        // detection miss the app far more often than it caught it.
        // queryEvents() only returns events that happened INSIDE the window,
        // and ACTIVITY_RESUMED fires once, at the moment the app comes to the
        // front. A driver who opens Uber and then just drives generates no
        // further events -- so 90 seconds later there was nothing in the
        // 60-second window and this returned null, i.e. "no gig app open"
        // while Uber was plainly on screen. The 30s poll only ever caught it
        // if a tick happened to land in that first minute, and ticks are
        // throttled once ControlMiles is backgrounded, which is exactly when
        // this feature is supposed to work.
        //
        // A long lookback is still correct for "what is in front right now":
        // the loop below keeps only the LAST resumed package, so switching
        // back to ControlMiles (or to any other app) immediately wins over the
        // older event and detection correctly stops reporting the gig app.
        val start = end - 2 * 60 * 60 * 1000L // 2 hours
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
