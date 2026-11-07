package br.edu.vigiliadomusgo

import org.json.JSONObject

internal object OverlayRuntime {
    @Volatile var active = false
    @Volatile var state = "idle"
    @Volatile var message = "Janela flutuante pronta."
    // Assigned only during a foreground Activity request and cleared on every completion path.
    var onAttached: (() -> Unit)? = null
    fun status(next: String, text: String) { message = text; state = next }
    fun json(): String = JSONObject().put("state", state).put("message", message).toString()
}
