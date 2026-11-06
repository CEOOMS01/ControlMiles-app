package com.olimsys.cm_drive_wake

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class DriveWakeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            // Google forgets the subscriptions on reboot and app update.
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                if (DriveWakeRegistrar.isArmed(context)) DriveWakeRegistrar.register(context)
            }

            // Android says the phone is in a vehicle (or left it).
            DriveWakeRegistrar.ACTION -> {
                if (!ActivityTransitionResult.hasResult(intent)) return
                val result = ActivityTransitionResult.extractResult(intent) ?: return
                if (!DriveWakeRegistrar.isArmed(context)) return
                val entered = result.transitionEvents.any {
                    it.activityType == DetectedActivity.IN_VEHICLE &&
                        it.transitionType == ActivityTransition.ACTIVITY_TRANSITION_ENTER
                }
                val left = result.transitionEvents.any {
                    it.activityType == DetectedActivity.IN_VEHICLE &&
                        it.transitionType == ActivityTransition.ACTIVITY_TRANSITION_EXIT
                }
                if (entered) wake(context, "vehicle")
                // The drive is over: the car is parked here, so the next exit fence goes here.
                if (left) DriveWakeRegistrar.refreshFenceHere(context)
            }

            // The phone left the fence around where it was parked.
            DriveWakeRegistrar.ACTION_FENCE -> {
                val event = GeofencingEvent.fromIntent(intent) ?: return
                if (event.hasError()) {
                    Log.w("CmDriveWake", "Fence error ${event.errorCode}")
                    return
                }
                if (event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_EXIT &&
                    DriveWakeRegistrar.isArmed(context)
                ) {
                    wake(context, "fence")
                }
            }
        }
    }

    private fun wake(context: Context, source: String) {
        Log.i("CmDriveWake", "Wake: $source")
        context.getSharedPreferences(DriveWakeRegistrar.PREFS, Context.MODE_PRIVATE)
            .edit().putString(DriveWakeRegistrar.KEY_WAKE_SOURCE, source).apply()
        try {
            // Allowed from the background because the start comes from an
            // activity-recognition transition or a geofence event.
            ContextCompat.startForegroundService(context, Intent(context, DriveWakeService::class.java))
        } catch (e: Exception) {
            Log.w("CmDriveWake", "Could not start the wake service: $e")
        }
    }
}
