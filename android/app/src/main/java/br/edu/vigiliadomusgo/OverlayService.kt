package br.edu.vigiliadomusgo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.Display
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import java.io.File

/** A finite, visible presentation service, not a second game simulation. */
class OverlayService : Service() {
    private lateinit var windows: WindowManager
    private var windowContext: Context? = null
    private var observedInsets: Rect? = null
    private lateinit var params: WindowManager.LayoutParams
    private lateinit var timeline: Timeline
    private var panel: LinearLayout? = null
    private lateinit var scene: CombatView
    private lateinit var stats: TextView
    private lateinit var event: TextView
    private lateinit var area: TextView
    private val handler = Handler(Looper.getMainLooper())
    private var receiverRegistered = false
    private val screenOff = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                OverlayRuntime.status("closed", "Tela desligada: janela encerrada para economizar bateria.")
                stopSelf()
            }
        }
    }
    private val update = object : Runnable {
        override fun run() {
            if (!Settings.canDrawOverlays(this@OverlayService)) {
                fail("Permissão de sobreposição revogada. Progresso preservado."); return
            }
            if (!getSystemService(PowerManager::class.java).isInteractive) { stopSelf(); return }
            val index = timeline.index(SystemClock.elapsedRealtime() / 1000.0, NativeClock.boot(this@OverlayService))
            if (index == null || index >= timeline.duration) {
                OverlayRuntime.status("closed", "Expedição de 5 minutos concluída. Abra o jogo para atualizar.")
                stopSelf(); return
            }
            val frame = timeline.frame(index)
            scene.show(frame)
            stats.text = "${frame.optString("class_name")} · Nv. ${frame.optInt("level")} · ${frame.optInt("gold")} sementes\nPV ${frame.optInt("hp")}/${frame.optInt("max_hp")}  ·  XP ${frame.optInt("xp")}/${frame.optInt("xp_next") }"
            area.text = "Bosque · etapa ${frame.optInt("stage")}  |  ${timeline.duration - index}s"
            event.text = frame.optString("event", "Explorando o bosque…")
            handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) { stopSelf(); return START_NOT_STICKY }
        if (panel != null) return START_NOT_STICKY
        try {
            check(Settings.canDrawOverlays(this)) { "Sobreposição não autorizada." }
            val source = File(filesDir, "overlay-timeline.json")
            check(source.length() in 1..2_000_000) { "Expedição ausente ou inválida." }
            timeline = Timeline(source.readText())
            check(timeline.index(SystemClock.elapsedRealtime() / 1000.0, NativeClock.boot(this)) != null)
            val notification = createNotification()
            if (Build.VERSION.SDK_INT >= 34) startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            else startForeground(NOTIFICATION_ID, notification)
            windowContext = if (Build.VERSION.SDK_INT >= 30) {
                val display = getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)
                createDisplayContext(display).createWindowContext(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, null)
            } else this
            windows = windowContext!!.getSystemService(WindowManager::class.java)
            createPanel()
            val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
            if (Build.VERSION.SDK_INT >= 33) registerReceiver(screenOff, filter, Context.RECEIVER_NOT_EXPORTED)
            else registerReceiver(screenOff, filter)
            receiverRegistered = true
            OverlayRuntime.active = true
            OverlayRuntime.status("active", "Expedição flutuante ativa por até 5 minutos.")
            OverlayRuntime.onAttached?.invoke()
            OverlayRuntime.onAttached = null
            handler.post(update)
        } catch (error: Exception) {
            fail("Janela indisponível neste aparelho: ${error.javaClass.simpleName}. Continue em tela completa.")
        }
        return START_NOT_STICKY
    }

    private fun createNotification(): Notification {
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Expedição flutuante", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Exibida apenas durante a janela flutuante solicitada por você."
                setSound(null, null)
            })
        val open = PendingIntent.getActivity(this, 1, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val close = PendingIntent.getService(this, 2, Intent(this, OverlayService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_moss)
            .setContentTitle("Vigília do Musgo · janela ativa")
            .setContentText("Expedição de até 5 minutos. Toque para abrir o jogo.")
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .addAction(Notification.Action.Builder(null, "Fechar janela", close).build())
            .setCategory(Notification.CATEGORY_SERVICE).build()
    }

    private fun uiContext(): Context = windowContext ?: this
    private fun dp(value: Int) = (value * uiContext().resources.displayMetrics.density).toInt()
    private fun label(size: Float) = TextView(uiContext()).apply {
        textSize = size; setTextColor(Color.parseColor("#EDF0DB")); maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
    }
    private fun createPanel() {
        val root = LinearLayout(uiContext()).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(4), dp(8), dp(4))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#142D33")); cornerRadius = dp(8).toFloat()
                setStroke(dp(2), Color.parseColor("#99BB85"))
            }
            elevation = dp(8).toFloat()
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        }
        val header = LinearLayout(uiContext())
        val title = label(13f).apply {
            text = "VIGÍLIA  •  arraste"; gravity = Gravity.CENTER_VERTICAL
            contentDescription = "Arraste para mover a janela"
        }
        header.addView(title, LinearLayout.LayoutParams(0, dp(44), 1f))
        fun button(text: String, description: String, action: () -> Unit) = Button(uiContext()).apply {
            this.text = text; textSize = 14f; minWidth = 0; minimumWidth = 0
            setPadding(0, 0, 0, 0); contentDescription = description; setOnClickListener { action() }
        }
        header.addView(button("↗", "Abrir jogo em tela completa") {
            try {
                startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                stopSelf()
            } catch (_: Exception) { fail("Abra o jogo pelo ícone ou pela notificação.") }
        }, LinearLayout.LayoutParams(dp(44), dp(44)))
        header.addView(button("×", "Fechar janela") { stopSelf() }, LinearLayout.LayoutParams(dp(44), dp(44)))
        root.addView(header)
        area = label(11f)
        root.addView(area, LinearLayout.LayoutParams(-1, dp(19)))
        scene = CombatView(uiContext()).apply { contentDescription = "Representação compacta da expedição automática" }
        root.addView(scene, LinearLayout.LayoutParams(-1, 0, 1f))
        stats = label(12f).apply { maxLines = 2 }
        root.addView(stats, LinearLayout.LayoutParams(-1, dp(38)))
        event = label(11f)
        root.addView(event, LinearLayout.LayoutParams(-1, dp(20)))
        val resize = label(11f).apply {
            text = "↘ Arraste para ajustar tamanho"; gravity = Gravity.END or Gravity.CENTER_VERTICAL
            contentDescription = "Arraste para redimensionar a janela"
        }
        root.addView(resize, LinearLayout.LayoutParams(-1, dp(28)))
        params = WindowManager.LayoutParams(dp(320), dp(240),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT).apply { gravity = Gravity.TOP or Gravity.LEFT; x = dp(12); y = dp(64) }
        fitBounds()
        installDrag(title, false)
        installDrag(resize, true)
        windows.addView(root, params)
        panel = root
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val safe = insets.getInsetsIgnoringVisibility(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()
            )
            val current = Rect(safe.left, safe.top, safe.right, safe.bottom)
            if (current != observedInsets) {
                observedInsets = current
                try { fitBounds(); windows.updateViewLayout(root, params) }
                catch (_: Exception) { fail("Janela encerrada ao atualizar limites da tela.") }
            }
            insets
        }
        ViewCompat.requestApplyInsets(root)
    }

    private fun installDrag(view: View, resize: Boolean) {
        var downX = 0f; var downY = 0f
        var start = Box(0, 0, 0, 0)
        view.setOnTouchListener { target, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX; downY = event.rawY
                    start = Box(params.x, params.y, params.width, params.height); true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - downX).toInt(); val dy = (event.rawY - downY).toInt()
                    if (resize) { params.width = start.width + dx; params.height = start.height + dy }
                    else { params.x = start.x + dx; params.y = start.y + dy }
                    fitBounds()
                    try { panel?.let { windows.updateViewLayout(it, params) } }
                    catch (_: Exception) { fail("A janela foi encerrada pelo sistema. Progresso preservado.") }
                    true
                }
                MotionEvent.ACTION_UP -> { target.performClick(); true }
                MotionEvent.ACTION_CANCEL -> true
                else -> false
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun safeBounds(): Box {
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = windows.currentWindowMetrics
            val bounds = metrics.bounds
            val inset = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            return Box(bounds.left + inset.left, bounds.top + inset.top,
                bounds.width() - inset.left - inset.right, bounds.height() - inset.top - inset.bottom)
        }
        val display = android.util.DisplayMetrics()
        windows.defaultDisplay.getRealMetrics(display)
        // Before the first inset dispatch, reserve room for legacy side navigation.
        // Once attached, use the actual bars and API 28+ cutout dimensions.
        val sideGuard = if (display.widthPixels > display.heightPixels) dp(80) else dp(24)
        val safe = observedInsets ?: Rect(sideGuard, dp(40), sideGuard, dp(80))
        return Box(safe.left, safe.top,
            (display.widthPixels - safe.left - safe.right).coerceAtLeast(1),
            (display.heightPixels - safe.top - safe.bottom).coerceAtLeast(1))
    }
    private fun fitBounds() {
        val fitted = WindowBounds.fit(Box(params.x, params.y, params.width, params.height), safeBounds(), dp(260), dp(220), dp(440), dp(360))
        params.x = fitted.x; params.y = fitted.y; params.width = fitted.width; params.height = fitted.height
    }
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        observedInsets = null
        if (panel != null) {
            try { fitBounds(); windows.updateViewLayout(panel, params) }
            catch (_: Exception) { fail("Janela encerrada após mudança de tela. Abra o jogo para continuar.") }
            panel?.let { ViewCompat.requestApplyInsets(it) }
        }
    }
    private fun fail(message: String) {
        OverlayRuntime.status("error", message); OverlayRuntime.onAttached = null; stopSelf()
    }
    override fun onTaskRemoved(rootIntent: Intent?) { stopSelf(); super.onTaskRemoved(rootIntent) }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (receiverRegistered) unregisterReceiver(screenOff)
        panel?.let { try { windows.removeViewImmediate(it) } catch (_: Exception) {} }
        panel = null
        OverlayRuntime.active = false
        OverlayRuntime.onAttached = null
        if (OverlayRuntime.state != "error" && OverlayRuntime.state != "closed")
            OverlayRuntime.status("closed", "Janela fechada. Abra o jogo para continuar.")
        File(filesDir, "overlay-timeline.json").delete()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
    companion object {
        private const val CHANNEL = "visible_expedition"
        private const val NOTIFICATION_ID = 4701
        private const val ACTION_STOP = "br.edu.vigiliadomusgo.STOP_OVERLAY"
    }
}
