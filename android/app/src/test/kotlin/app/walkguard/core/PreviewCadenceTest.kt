package app.walkguard.core

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PreviewCadenceTest {
    @Test fun firstWarningFrameIsImmediateAndLaterFramesAreThrottled() {
        val cadence = PreviewCadence()
        assertFalse(cadence.shouldCapture(100, visible = false))
        assertTrue(cadence.shouldCapture(108, visible = true))
        assertFalse(cadence.shouldCapture(607, visible = true))
        assertTrue(cadence.shouldCapture(608, visible = true))
    }

    @Test fun nextWarningGetsAFrameEvenIfPreviousWarningJustEnded() {
        val cadence = PreviewCadence()
        assertTrue(cadence.shouldCapture(100, visible = true))
        assertFalse(cadence.shouldCapture(150, visible = false))
        assertTrue(cadence.shouldCapture(200, visible = true))
    }

    @Test fun upgradeEnablesPreviewAndNewExplicitOptOutPersists() {
        assertTrue(GuardSettings.fromStoredMap(emptyMap()).preview)
        val upgraded = GuardSettings.fromStoredMap(mapOf("preview" to false, "vibration" to false))
        assertTrue(upgraded.preview)
        assertFalse(upgraded.vibration)
        assertFalse(GuardSettings.fromStoredMap(upgraded.copy(preview = false).toStoredMap()).preview)
    }
}
