package app.walkguard.core

import org.junit.Assert.*
import org.junit.Test

class DotFieldTest {
    @Test fun dotFieldIsBoundedFiniteAndHasVisibleEdge() {
        for (width in listOf(280f, 390f, 840f)) {
            for (size in listOf(.7f, 1f, 1.3f)) {
                val s = GuardSettings(arcSize = size, dotDensity = 1.4f)
                val f = DotField.create(width, s)
                assertTrue(f.dots.size in 100..4400)
                assertTrue(f.radiusY <= 172f * size)
                assertTrue(f.dots.all { it.x.isFinite() && it.y.isFinite() && it.opacity in 0f..1f && it.y >= 8f && it.y <= f.radiusY + 8.01f })
                assertTrue(f.dots.any { it.opacity > .95f })
                assertTrue(f.dots.any { it.opacity < .05f })
            }
        }
    }
    @Test fun fieldIsStableAndDensityActuallyChangesCount() {
        val s = GuardSettings()
        assertEquals(DotField.create(390f, s), DotField.create(390f, s))
        assertTrue(DotField.create(390f, s.copy(dotDensity = 1.4f)).dots.size > DotField.create(390f, s.copy(dotDensity = .6f)).dots.size)
    }
    @Test fun oldSignalMigratesWithoutChangingDetection() {
        val s = GuardSettings.fromMap(mapOf("arcStyle" to "SIGNAL", "sensitivity" to .8, "mode" to "ECO"))
        assertEquals("MATRIX", s.arcStyle)
        assertEquals(.8f, s.sensitivity); assertEquals("ECO", s.mode)
        val n = GuardSettings.fromMap(s.toMap() + mapOf("dotDensity" to 99, "revealMs" to -1))
        assertEquals(1.4f, n.dotDensity); assertEquals(250L, n.revealMs)
        assertEquals(s.riskConfig(), n.riskConfig())
    }
}
