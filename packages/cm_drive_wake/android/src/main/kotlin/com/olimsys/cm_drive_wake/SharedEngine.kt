package com.olimsys.cm_drive_wake

import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * The app's only Flutter engine (2026-11-07). The screen (MainActivity) and the
 * background service (DriveWakeService) share it, so a trip lives in one place.
 * Whoever needs it first creates it; it is destroyed only when neither uses it.
 */
object SharedEngine {
    const val ID = "controlmiles_main"

    var screens = 0
    var serviceRunning = false

    /** The engine and whether it was just created (its Dart code is only starting). */
    fun obtain(ctx: Context): Pair<FlutterEngine, Boolean> {
        FlutterEngineCache.getInstance().get(ID)?.let { return it to false }
        val app = ctx.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, null)
        val engine = FlutterEngine(app)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ID, engine)
        return engine to true
    }

    /** Neither the screen nor the service needs it: free it, as Flutter would. */
    fun releaseIfUnused() {
        if (screens > 0 || serviceRunning) return
        val cache = FlutterEngineCache.getInstance()
        cache.get(ID)?.destroy()
        cache.remove(ID)
    }
}
