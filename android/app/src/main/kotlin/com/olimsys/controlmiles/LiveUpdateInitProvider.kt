package com.olimsys.controlmiles

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri

/**
 * Starts [LiveUpdatePromoter] the moment the app's process starts, including
 * when Android brings the process back only to run the background tracking
 * service (the driver swiped the app away): no activity or Flutter engine is
 * needed for the notification to keep being promoted. Holds no data.
 */
class LiveUpdateInitProvider : ContentProvider() {
    override fun onCreate(): Boolean {
        context?.let { LiveUpdatePromoter.ensureRunning(it) }
        return true
    }

    override fun query(
        uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(
        uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?
    ): Int = 0
}
