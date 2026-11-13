package app.walkguard.core

import kotlin.math.*

/** Density-independent, deterministic geometry shared conceptually with the Flutter preview. */
object DotField {
    data class Dot(val x: Float, val y: Float, val opacity: Float, val radius: Float, val halo: Boolean)
    data class Field(val radiusX: Float, val radiusY: Float, val dots: List<Dot>)
    fun create(width: Float, settings: GuardSettings): Field {
        require(width.isFinite() && width > 0f)
        val rx = min(width * .53f, width * .45f * settings.arcSize)
        val ry = min(172f * settings.arcSize, rx * .88f)
        val gap = 5.2f / settings.dotDensity
        val rows = min(24, (ry * .68f / gap).roundToInt()).coerceAtLeast(1)
        val columns = (PI * rx / gap).roundToInt().coerceIn(48, 180)
        val dots = ArrayList<Dot>(rows * columns)
        for (row in rows - 1 downTo 0) {
            val radial = (1f - row.toFloat() / rows).pow(2.8f)
            for (col in 0..columns) {
                val angle = col.toDouble() / columns * PI
                val opacity = radial * sin(angle).coerceAtLeast(0.0).pow(.65).toFloat()
                if (opacity < .008f) continue
                dots.add(Dot(width / 2 + cos(angle).toFloat() * (rx - row * gap),
                    8 + sin(angle).toFloat() * (ry - row * gap), opacity,
                    (.65f + radial * .3f) * settings.arcThickness, row < 5))
            }
        }
        return Field(rx, ry, dots)
    }
}
