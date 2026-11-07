package br.edu.vigiliadomusgo

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class TimelineTest {
    private fun payload(duration: Int = 3, boot: String = "7") = JSONObject().put("version", 1)
        .put("duration", duration).put("clock", JSONObject().put("mono", 100.25).put("boot", boot))
        .put("frames", JSONArray().apply { repeat(duration + 1) { put(JSONObject().put("tick", 20 + it)) } }).toString()
    @Test fun `frame selection preserves exact monotonic boundary`() {
        val timeline = Timeline(payload())
        assertEquals(0, timeline.index(100.25, "7"))
        assertEquals(0, timeline.index(101.24, "7"))
        assertEquals(1, timeline.index(101.25, "7"))
        assertEquals(23, timeline.frame(timeline.index(103.25, "7")!!).getInt("tick"))
        assertNull(timeline.index(104.25, "7"))
    }
    @Test fun `reboot and clock regression invalidate preview`() {
        val timeline = Timeline(payload())
        assertNull(timeline.index(100.24, "7"))
        assertNull(timeline.index(101.0, "8"))
        assertNull(timeline.index(Double.NaN, "7"))
    }
    @Test fun `frame access never changes source`() {
        val timeline = Timeline(payload())
        repeat(10) { timeline.frame(timeline.index(102.25, "7")!!) }
        assertEquals(20, timeline.frame(0).getInt("tick"))
    }
    @Test(expected = IllegalArgumentException::class) fun `duration cannot exceed visible session budget`() { Timeline(payload(301)) }
    @Test(expected = IllegalArgumentException::class) fun `unknown boot must fall back`() { Timeline(payload(3, "")) }
    @Test(expected = IllegalArgumentException::class) fun `partial timeline is rejected`() {
        Timeline(JSONObject(payload()).put("duration", 2).toString())
    }
}
