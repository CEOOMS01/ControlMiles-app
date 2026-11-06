package com.olimsys.controlmiles

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// The gig-app-in-front detection (Usage Access) moved to the local plugin
// packages/cm_usage_access on 2026-11-05: as a plugin it is registered in every
// Flutter engine, including the headless one that runs while the app is closed.
class MainActivity : FlutterActivity() {
    private val liveUpdateChannelName = "controlmiles/live_update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerLiveUpdateChannel(flutterEngine)
    }

    private fun registerLiveUpdateChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, liveUpdateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureRunning" -> {
                        LiveUpdatePromoter.ensureRunning(applicationContext)
                        result.success(null)
                    }
                    "canPromote" -> result.success(LiveUpdatePromoter.canPromote(applicationContext))
                    else -> result.notImplemented()
                }
            }
    }
}
