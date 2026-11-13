package app.walkguard.core

import org.junit.Assert.*
import org.junit.Test

class SettingsAndSessionTest {
    @Test fun settingsRoundTrip() {
        val s = GuardSettings(mode = "ECO", sensitivity = .8f, preview = true, hideDelayMs = 600)
        assertEquals(s, GuardSettings.fromMap(s.toMap()))
        assertEquals(3, s.fps)
        assertEquals(6, GuardSettings().fps)
        assertEquals(10, GuardSettings(mode = "PERFORMANCE").fps)
    }
    @Test fun clampsInvalidSettings() {
        val s = GuardSettings.fromMap(mapOf("mode" to "INVALID", "glow" to Float.NaN,
            "hideDelayMs" to -1L, "sensitivity" to 4.0, "arcSize" to 10))
        assertEquals("BALANCED", s.mode); assertEquals(.7f, s.glow)
        assertEquals(350L, s.hideDelayMs); assertEquals(1f, s.sensitivity); assertEquals(1.3f, s.arcSize)
    }
    @Test fun existingSettingsMigrateAndCustomAppearanceRoundTrips() {
        val old = GuardSettings.fromMap(mapOf("mode" to "ECO", "sensitivity" to .8))
        assertEquals("ECO", old.mode); assertFalse(old.welcomeComplete)
        assertEquals("MATRIX", old.arcStyle); assertTrue(old.showMetrics)
        val custom = old.copy(arcStyle = "SEGMENTS", arcThickness = 1.7f, topOffset = 40f,
            reduceMotion = true, welcomeComplete = true, showMetrics = false, glow = 0f)
        assertEquals(custom, GuardSettings.fromMap(custom.toMap()))
        assertEquals(old.riskConfig(), custom.riskConfig())
    }
    @Test fun appearanceBoundsCannotMoveWarningOffscreen() {
        val s = GuardSettings.fromMap(mapOf("arcStyle" to "INVALID", "arcThickness" to 99,
            "topOffset" to -10, "glow" to -1))
        assertEquals("MATRIX", s.arcStyle); assertEquals(2f, s.arcThickness)
        assertEquals(0f, s.topOffset); assertEquals(0f, s.glow)
    }
    @Test fun lateCameraCallbackAfterStopCannotActivate() {
        val s = SessionState(); val token = s.begin()!!
        s.stop(); assertFalse(s.activate(token)); assertFalse(s.accepts(token))
        s.finish(); assertEquals(SessionPhase.STOPPED, s.phase)
    }
    @Test fun duplicateStartIsRejected() {
        val s = SessionState(); val token = s.begin()!!
        assertNull(s.begin()); assertTrue(s.activate(token)); assertNull(s.begin())
        s.stop(); assertNull(s.begin()); s.finish()
        val next = s.begin()!!; assertFalse(s.activate(token)); assertTrue(s.activate(next))
    }
    @Test fun errorsPermitAnExplicitFreshStart() {
        val s = SessionState(); val token = s.begin()!!
        s.stop(); s.finish(true); assertEquals(SessionPhase.ERROR, s.phase)
        val next = s.begin()!!; assertFalse(s.accepts(token)); assertTrue(s.activate(next))
    }
}
