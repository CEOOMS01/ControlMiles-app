package com.olimsys.controlmiles

import android.content.Context
import android.os.Bundle
import com.olimsys.cm_drive_wake.SharedEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

// The screen uses the app's only Flutter engine (2026-11-07, see SharedEngine): if
// a trip is running in the background, opening the app shows that same trip
// instead of starting a second copy. Closing the screen keeps the engine while the
// background service needs it.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        SharedEngine.screens++
        super.onCreate(savedInstanceState)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine = SharedEngine.obtain(context).first

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onDestroy() {
        super.onDestroy()
        SharedEngine.screens--
        if (!isChangingConfigurations) SharedEngine.releaseIfUnused()
    }
}
