package br.edu.vigiliadomusgo

import android.content.Intent
import android.os.Bundle
import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotActivity
import org.godotengine.godot.plugin.GodotPlugin

/** One Godot engine in this process. The overlay never creates an engine. */
class MainActivity : GodotActivity() {
    private var bridge: IdleBridge? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // API 35+ enforces edge-to-edge. Keep the Godot viewport inside bars/cutouts
        // on every orientation, instead of putting game controls underneath them.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val content = findViewById<View>(android.R.id.content)
        ViewCompat.setOnApplyWindowInsetsListener(content) { view, insets ->
            val safe = insets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()
            )
            view.setPadding(safe.left, safe.top, safe.right, safe.bottom)
            insets
        }
        ViewCompat.requestApplyInsets(content)
    }
    override fun getHostPlugins(engine: Godot): Set<GodotPlugin> {
        val plugin = bridge ?: IdleBridge(engine, this).also { bridge = it }
        return setOf(plugin)
    }
    override fun getCommandLine(): MutableList<String> =
        super.getCommandLine().toMutableList().apply {
            addAll(listOf("--main-pack", "res://game.pck", "--rendering-method", "gl_compatibility"))
        }

    override fun onResume() {
        super.onResume()
        // Any return to the Activity ends the timeline before GDScript reconciles elapsed time.
        if (OverlayRuntime.active) stopService(Intent(this, OverlayService::class.java))
    }
}
