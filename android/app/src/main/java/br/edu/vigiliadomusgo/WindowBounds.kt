package br.edu.vigiliadomusgo

internal data class Box(val x: Int, val y: Int, val width: Int, val height: Int)

/** Pure geometry, shared by drag, resize and rotation handling. Coordinates are display pixels. */
internal object WindowBounds {
    fun fit(box: Box, safe: Box, minWidth: Int, minHeight: Int, maxWidth: Int, maxHeight: Int): Box {
        val availableW = safe.width.coerceAtLeast(1)
        val availableH = safe.height.coerceAtLeast(1)
        val width = box.width.coerceIn(minWidth.coerceAtMost(availableW), maxWidth.coerceAtMost(availableW).coerceAtLeast(minWidth.coerceAtMost(availableW)))
        val height = box.height.coerceIn(minHeight.coerceAtMost(availableH), maxHeight.coerceAtMost(availableH).coerceAtLeast(minHeight.coerceAtMost(availableH)))
        return Box(box.x.coerceIn(safe.x, safe.x + availableW - width),
            box.y.coerceIn(safe.y, safe.y + availableH - height), width, height)
    }
}
