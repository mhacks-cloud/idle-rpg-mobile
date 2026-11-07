package br.edu.vigiliadomusgo

import org.json.JSONObject
import kotlin.math.floor

/** Time selection only: all combat, rewards and RNG already ran in GDScript. */
internal class Timeline(payload: String) {
    private val root = JSONObject(payload)
    private val frames = root.getJSONArray("frames")
    val duration = root.getInt("duration")
    val originMono = root.getJSONObject("clock").getDouble("mono")
    val boot = root.getJSONObject("clock").getString("boot")
    init {
        require(root.getInt("version") == 1)
        require(duration in 1..300 && frames.length() == duration + 1)
        require(originMono.isFinite() && originMono >= 0 && boot.isNotEmpty())
        repeat(frames.length()) { require(frames.get(it) is JSONObject) }
    }
    fun index(nowMono: Double, currentBoot: String): Int? {
        if (!nowMono.isFinite() || currentBoot != boot || nowMono < originMono) return null
        val elapsed = floor(nowMono - originMono)
        if (elapsed > duration) return null
        return elapsed.toInt()
    }
    fun frame(index: Int): JSONObject = frames.getJSONObject(index)
}
