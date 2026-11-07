package br.edu.vigiliadomusgo

import org.junit.Assert.*
import org.junit.Test

class WindowBoundsTest {
    @Test fun `drag cannot cross safe insets`() {
        assertEquals(Box(20, 420, 300, 200), WindowBounds.fit(Box(-50, 999, 300, 200), Box(20, 40, 400, 580), 260, 200, 440, 360))
    }
    @Test fun `oversize is limited and repositioned`() {
        assertEquals(Box(20, 40, 400, 360), WindowBounds.fit(Box(99, -1, 900, 900), Box(20, 40, 400, 580), 260, 200, 440, 360))
    }
    @Test fun `small split screen overrides minimum dimensions safely`() {
        assertEquals(Box(0, 20, 180, 120), WindowBounds.fit(Box(50, 50, 300, 220), Box(0, 20, 180, 120), 260, 200, 440, 360))
    }
    @Test fun `random requests remain contained`() {
        val random = java.util.Random(17)
        repeat(1000) {
            val safe = Box(16, 32, random.nextInt(1000) + 1, random.nextInt(1000) + 1)
            val result = WindowBounds.fit(Box(random.nextInt(), random.nextInt(), random.nextInt(), random.nextInt()), safe, 260, 200, 440, 360)
            assertTrue(result.x >= safe.x && result.y >= safe.y)
            assertTrue(result.x + result.width <= safe.x + safe.width)
            assertTrue(result.y + result.height <= safe.y + safe.height)
            assertTrue(result.width > 0 && result.height > 0)
        }
    }
}
