package br.edu.vigiliadomusgo

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import org.json.JSONObject

internal object NativeClock {
    fun boot(context: Context): String = try {
        Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT).toString()
    } catch (_: Exception) { "" }
    fun json(context: Context): String = JSONObject()
        .put("wall", System.currentTimeMillis() / 1000.0)
        .put("mono", SystemClock.elapsedRealtime() / 1000.0)
        .put("boot", boot(context)).toString()
}
