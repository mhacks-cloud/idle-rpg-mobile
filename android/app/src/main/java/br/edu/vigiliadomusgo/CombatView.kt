package br.edu.vigiliadomusgo

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import org.json.JSONObject

/** Original procedural pixel scene. Draws only when the service supplies another timeline frame. */
internal class CombatView(context: Context) : View(context) {
    private val paint = Paint().apply { isAntiAlias = false }
    private var state = JSONObject()
    fun show(frame: JSONObject) { state = frame; invalidate() }
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val scale = width / 160f
        canvas.save()
        canvas.scale(scale, height / 69f)
        fun rect(x: Float, y: Float, w: Float, h: Float, color: String) {
            paint.color = Color.parseColor(color); canvas.drawRect(x, y, x + w, y + h, paint)
        }
        rect(0f, 0f, 160f, 69f, "#18373F")
        rect(0f, 41f, 160f, 28f, "#254A43")
        for (i in 0..10) {
            val x = (i * 19 % 160).toFloat()
            rect(x, (i * 7 % 16).toFloat(), 4f, 30f, "#20434A")
            rect(x - 5, (i * 7 % 16).toFloat(), 14f, 8f, "#2C5651")
            rect((i * 29 % 160).toFloat(), 46f + i % 4, 3f, 2f, "#719A66")
        }
        val tick = state.optInt("tick")
        val hop = if (state.optString("phase") == "combat") tick % 2 else 0
        val hero = when (state.optString("class_id")) {
            "mage" -> "#B9A4E9"; "healer" -> "#C5E7A6"; "archer" -> "#E6B873"; else -> "#7DC6C6"
        }
        val hx = 36f + hop * 2
        val hy = 31f - hop
        rect(hx, hy, 8f, 8f, "#EDD3A4")
        rect(hx - 1, hy - 3, 10f, 4f, hero)
        rect(hx - 2, hy + 8, 12f, 11f, hero)
        rect(hx, hy + 19, 3f, 5f, "#152A33")
        rect(hx + 6, hy + 19, 3f, 5f, "#152A33")
        rect(hx + 6, hy + 3, 2f, 2f, "#152A33")
        rect(hx + 12, hy + 3, 2f, 14f, "#E8D58E")
        if (state.optInt("enemy_hp") > 0) {
            val boss = state.optString("enemy_id") == "root_guardian"
            val ew = if (boss) 24f else 17f
            val ey = if (boss) 27f else 36f
            rect(108f - hop, ey, ew, 16f, "#BB8C8A")
            rect(111f - hop, ey - 3, ew - 6, 3f, "#DBB29A")
            rect(111f - hop, ey + 4, 3f, 3f, "#26363D")
            rect(121f - hop, ey + 4, 3f, 3f, "#26363D")
            rect(106f - hop, ey + 13, ew + 4, 5f, "#876F7E")
        }
        if (state.optString("phase") == "combat" && hop == 1) {
            rect(78f, 34f, 3f, 9f, "#F4DF9C"); rect(75f, 37f, 9f, 3f, "#F4DF9C")
        }
        val ratio = state.optDouble("hp") / state.optDouble("max_hp", 1.0).coerceAtLeast(1.0)
        rect(10f, 60f, 140f, 3f, "#152A33")
        rect(10f, 60f, (140 * ratio.coerceIn(0.0, 1.0)).toFloat(), 3f, "#B9E18A")
        canvas.restore()
    }
}
