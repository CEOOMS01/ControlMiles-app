package com.olimsys.cm_drive_wake

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.DetectedActivity
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource

/**
 * Two independent ways to learn that a drive is starting, neither of which keeps GPS
 * or a service running while nothing happens:
 *  1. Android's own "entered a vehicle" (Activity Recognition transitions).
 *  2. A small fence around where the phone was last parked: when the phone leaves it,
 *     Android wakes the app. This does not depend on how Android classifies the
 *     movement (a bus, a slow start, a phone lying on the seat), and the fence centre
 *     is the exact place the trip started.
 * Either one wakes [DriveWakeService]; the Dart side decides whether it is a trip.
 */
object DriveWakeRegistrar {
    const val PREFS = "cm_drive_wake"
    const val KEY_ARMED = "armed"
    const val KEY_FENCE_LAT = "fence_lat"
    const val KEY_FENCE_LNG = "fence_lng"
    const val KEY_FENCE_AT = "fence_at"
    const val KEY_WAKE_SOURCE = "wake_source"
    const val ACTION = "com.olimsys.cm_drive_wake.TRANSITION"
    const val ACTION_FENCE = "com.olimsys.cm_drive_wake.FENCE"
    // 2026-11-11: 100 m (was 150) and a 5 s notice (was up to 30 s) so the phone wakes
    // closer to where the car was parked: the stretch before the first GPS point has no
    // data and was drawn as a straight line across the block (186 to 434 m). 100 m is the
    // smallest radius Google recommends for a reliable exit.
    const val FENCE_RADIUS_M = 100f
    const val FENCE_RESPONSIVENESS_MS = 5_000
    private const val FENCE_ID = "parking"
    private const val TAG = "CmDriveWake"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isArmed(ctx: Context): Boolean = prefs(ctx).getBoolean(KEY_ARMED, false)

    fun hasPermission(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED

    private fun hasLocationPermission(ctx: Context): Boolean =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun pendingIntent(ctx: Context): PendingIntent {
        val intent = Intent(ctx, DriveWakeReceiver::class.java).setAction(ACTION)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        // Google Play services must be able to add the transition result to it.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
        return PendingIntent.getBroadcast(ctx.applicationContext, 4711, intent, flags)
    }

    private fun fencePendingIntent(ctx: Context): PendingIntent {
        val intent = Intent(ctx, DriveWakeReceiver::class.java).setAction(ACTION_FENCE)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
        return PendingIntent.getBroadcast(ctx.applicationContext, 4712, intent, flags)
    }

    fun register(ctx: Context, done: ((Boolean) -> Unit)? = null) {
        if (!hasPermission(ctx)) {
            Log.w(TAG, "ACTIVITY_RECOGNITION not granted; cannot register")
            done?.invoke(false)
            return
        }
        val transitions = listOf(
            ActivityTransition.ACTIVITY_TRANSITION_ENTER,
            ActivityTransition.ACTIVITY_TRANSITION_EXIT,
        ).map {
            ActivityTransition.Builder()
                .setActivityType(DetectedActivity.IN_VEHICLE)
                .setActivityTransition(it)
                .build()
        }
        ActivityRecognition.getClient(ctx.applicationContext)
            .requestActivityTransitionUpdates(ActivityTransitionRequest(transitions), pendingIntent(ctx))
            .addOnSuccessListener {
                Log.i(TAG, "Activity transitions registered")
                done?.invoke(true)
            }
            .addOnFailureListener {
                Log.w(TAG, "Activity transitions failed: $it")
                done?.invoke(false)
            }
        // The parking fence goes back up after a reboot / update too.
        restoreFence(ctx)
    }

    fun unregister(ctx: Context) {
        ActivityRecognition.getClient(ctx.applicationContext)
            .removeActivityTransitionUpdates(pendingIntent(ctx))
            .addOnCompleteListener { Log.i(TAG, "Activity transitions removed") }
        LocationServices.getGeofencingClient(ctx.applicationContext).removeGeofences(fencePendingIntent(ctx))
    }

    /** Puts the exit fence around [lat],[lng] (replacing the previous one). */
    @SuppressLint("MissingPermission")
    fun setFence(ctx: Context, lat: Double, lng: Double) {
        if (!hasLocationPermission(ctx)) return
        prefs(ctx).edit()
            .putLong(KEY_FENCE_LAT, java.lang.Double.doubleToRawLongBits(lat))
            .putLong(KEY_FENCE_LNG, java.lang.Double.doubleToRawLongBits(lng))
            .putLong(KEY_FENCE_AT, System.currentTimeMillis())
            .apply()
        val fence = Geofence.Builder()
            .setRequestId(FENCE_ID)
            .setCircularRegion(lat, lng, FENCE_RADIUS_M)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_EXIT)
            .setNotificationResponsiveness(FENCE_RESPONSIVENESS_MS)
            .build()
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(0)
            .addGeofence(fence)
            .build()
        val client = LocationServices.getGeofencingClient(ctx.applicationContext)
        val pi = fencePendingIntent(ctx)
        client.removeGeofences(pi).addOnCompleteListener {
            client.addGeofences(request, pi)
                .addOnSuccessListener { Log.i(TAG, "Parking fence set ($lat, $lng, ${FENCE_RADIUS_M.toInt()} m)") }
                .addOnFailureListener { Log.w(TAG, "Parking fence failed: $it") }
        }
    }

    /** Re-creates the saved fence (Android forgets fences on reboot and update). */
    fun restoreFence(ctx: Context) {
        val p = prefs(ctx)
        if (!p.contains(KEY_FENCE_LAT)) return
        setFence(
            ctx,
            java.lang.Double.longBitsToDouble(p.getLong(KEY_FENCE_LAT, 0L)),
            java.lang.Double.longBitsToDouble(p.getLong(KEY_FENCE_LNG, 0L)),
        )
    }

    /** Fence around where the phone is right now (a quick, single, low-power fix). */
    @SuppressLint("MissingPermission")
    fun refreshFenceHere(ctx: Context, done: ((Boolean) -> Unit)? = null) {
        if (!hasLocationPermission(ctx)) {
            done?.invoke(false)
            return
        }
        val client = LocationServices.getFusedLocationProviderClient(ctx.applicationContext)
        val cts = CancellationTokenSource()
        // One precise fix (2026-11-11): a low-power one can be off by more than the 100 m
        // fence itself.
        client.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cts.token)
            .addOnSuccessListener { loc ->
                if (loc != null && isSimulated(loc)) {
                    // A faked position must never become the start of a trip.
                    Log.w(TAG, "Ignoring a simulated position for the parking fence")
                    done?.invoke(false)
                } else if (loc != null) {
                    setFence(ctx, loc.latitude, loc.longitude)
                    done?.invoke(true)
                } else {
                    client.lastLocation.addOnSuccessListener { last ->
                        val usable = last != null && !isSimulated(last)
                        if (usable) setFence(ctx, last!!.latitude, last.longitude)
                        done?.invoke(usable)
                    }.addOnFailureListener { done?.invoke(false) }
                }
            }
            .addOnFailureListener {
                Log.w(TAG, "Could not get a position for the fence: $it")
                done?.invoke(false)
            }
    }

    @Suppress("DEPRECATION")
    private fun isSimulated(loc: android.location.Location): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) loc.isMock else loc.isFromMockProvider

    /** Where the last fence was set: [lat, lng, atMillis], or null. */
    fun anchor(ctx: Context): DoubleArray? {
        val p = prefs(ctx)
        if (!p.contains(KEY_FENCE_LAT)) return null
        return doubleArrayOf(
            java.lang.Double.longBitsToDouble(p.getLong(KEY_FENCE_LAT, 0L)),
            java.lang.Double.longBitsToDouble(p.getLong(KEY_FENCE_LNG, 0L)),
            p.getLong(KEY_FENCE_AT, 0L).toDouble(),
        )
    }
}
