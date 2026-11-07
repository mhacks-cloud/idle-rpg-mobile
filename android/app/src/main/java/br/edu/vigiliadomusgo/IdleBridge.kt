package br.edu.vigiliadomusgo

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import androidx.lifecycle.Lifecycle
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import java.io.File

/** Narrow bridge. It cannot edit, award or simulate RPG state. */
class IdleBridge(engine: Godot, private val host: MainActivity) : GodotPlugin(engine) {
    override fun getPluginName() = "IdleBridge"
    @UsedByGodot fun clock_json(): String = NativeClock.json(host)
    @UsedByGodot fun can_overlay(): Boolean = Settings.canDrawOverlays(host)
    @UsedByGodot fun is_overlay_active(): Boolean = OverlayRuntime.active
    @UsedByGodot fun status_json(): String = OverlayRuntime.json()

    private fun visible(): Boolean = host.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
    private fun notificationsGranted() = Build.VERSION.SDK_INT < 33 ||
        host.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    @UsedByGodot fun request_overlay_permission() {
        host.runOnUiThread {
            if (!visible()) return@runOnUiThread
            try {
                if (!can_overlay()) {
                    OverlayRuntime.status("idle", "Autorize a sobreposição e depois toque em Janela flutuante novamente.")
                    host.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${host.packageName}")))
                } else if (!notificationsGranted()) {
                    host.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4701)
                    OverlayRuntime.status("idle", "Autorize as notificações e toque em Janela flutuante novamente.")
                } else OverlayRuntime.status("idle", "Permissões concedidas. Toque em Janela flutuante para iniciar.")
            } catch (error: Exception) {
                OverlayRuntime.status("error", "Este aparelho não abriu a autorização. Continue em tela completa.")
            }
        }
    }

    @UsedByGodot fun start_overlay(payload: String) {
        // Set before queuing UI work so Godot observes the transition atomically at its next tick.
        OverlayRuntime.status("starting", "Preparando expedição flutuante…")
        host.runOnUiThread {
            try {
                check(visible()) { "Abra a tela do jogo antes de iniciar a janela." }
                check(can_overlay()) { "Autorize a sobreposição pelo botão de permissão." }
                if (!notificationsGranted()) {
                    host.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4701)
                    OverlayRuntime.status("error", "Autorize as notificações e tente novamente. Tela completa preservada.")
                    return@runOnUiThread
                }
                check(payload.toByteArray(Charsets.UTF_8).size <= 2_000_000) { "Expedição maior que o limite seguro." }
                val timeline = Timeline(payload)
                check(timeline.index(SystemClock.elapsedRealtime() / 1000.0, NativeClock.boot(host)) != null) {
                    "Relógio indisponível. Continue em tela completa."
                }
                check(!OverlayRuntime.active) { "A janela já está aberta." }
                // The service is non-exported and receives a private file, never a large Binder payload.
                val pending = File(host.filesDir, "overlay-timeline.tmp")
                pending.writeText(payload)
                val destination = File(host.filesDir, "overlay-timeline.json")
                check(pending.renameTo(destination)) { "Não foi possível preparar a janela." }
                OverlayRuntime.onAttached = {
                    if (visible()) host.moveTaskToBack(true)
                }
                host.startForegroundService(Intent(host, OverlayService::class.java))
            } catch (error: Exception) {
                OverlayRuntime.onAttached = null
                OverlayRuntime.status("error", error.message ?: "Janela indisponível. Continue em tela completa.")
                host.stopService(Intent(host, OverlayService::class.java))
            }
        }
    }

    @UsedByGodot fun stop_overlay() {
        host.runOnUiThread {
            OverlayRuntime.onAttached = null
            host.stopService(Intent(host, OverlayService::class.java))
        }
    }
}
