package com.example.controlmiles

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
        val start = end - 60_000
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
