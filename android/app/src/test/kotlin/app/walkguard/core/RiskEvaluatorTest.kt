package app.walkguard.core

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.sqrt

class RiskEvaluatorTest {
    private fun detection(time: Long, area: Float = 0.2f, label: String = "person", center: Float = 0.5f, confidence: Float = .9f): Detection {
        val side = sqrt(area)
        return Detection(label, confidence, Box(center - side / 2, .5f - side / 2, center + side / 2, .5f + side / 2), time)
    }
    private fun feed(engine: RiskEvaluator, time: Long, area: Float = .2f, stable: Boolean = true) =
        engine.evaluate(listOf(detection(time, area)), time, true, stable)
    @Test fun requiresRepeatedEvidence() {
        val engine = RiskEvaluator()
        assertEquals(RiskLevel.IDLE, feed(engine, 0).level)
        assertEquals(RiskLevel.IDLE, feed(engine, 170).level)
        assertEquals(RiskLevel.WARNING, feed(engine, 340).level)
    }
    @Test fun staticLargeVehicleNeverCritical() {
        val engine = RiskEvaluator()
        for (i in 0..15) {
            val t = i * 170L
            val r = engine.evaluate(listOf(detection(t, .6f, "car")), t, true, true)
            assertNotEquals(RiskLevel.CRITICAL, r.level)
        }
    }
    @Test fun matchedGrowthAndStableMotionRequiredForCritical() {
        val engine = RiskEvaluator()
        var event = feed(engine, 0, .16f)
        for (i in 1..7) event = feed(engine, i * 170L, .16f + i * .045f)
        assertEquals(RiskLevel.CRITICAL, event.level)
    }
    @Test fun cameraMotionSuppressesCritical() {
        val engine = RiskEvaluator()
        for (i in 0..7) assertNotEquals(RiskLevel.CRITICAL, feed(engine, i * 170L, .16f + i * .045f, false).level)
    }
    @Test fun emptyFramesHoldThenHide() {
        val engine = RiskEvaluator()
        for (i in 0..2) feed(engine, i * 170L)
        assertEquals(RiskLevel.WARNING, engine.evaluate(emptyList(), 510, true, true).level)
        for (t in listOf(680L, 850L, 1020L, 1190L)) engine.evaluate(emptyList(), t, true, true)
        assertEquals(RiskLevel.IDLE, engine.evaluate(emptyList(), 1400, true, true).level)
    }
    @Test fun unsuitablePoseClearsImmediately() {
        val engine = RiskEvaluator()
        for (i in 0..2) feed(engine, i * 170L)
        assertEquals(RiskLevel.IDLE, engine.evaluate(listOf(detection(510)), 510, false, true).level)
        assertEquals(RiskLevel.IDLE, feed(engine, 680).level)
    }
    @Test fun outsideCenterOrLowConfidenceDoesNotTrigger() {
        val engine = RiskEvaluator()
        for (i in 0..6) {
            val t = i * 170L
            val d = listOf(detection(t, center = .05f), detection(t, confidence = .2f))
            assertEquals(RiskLevel.IDLE, engine.evaluate(d, t, true, true).level)
        }
    }
    @Test fun unsupportedClassesAndStaleDetectionsDoNotTrigger() {
        val engine = RiskEvaluator()
        for (i in 0..6) {
            val t = 2000 + i * 170L
            assertEquals(RiskLevel.IDLE, engine.evaluate(listOf(detection(0), detection(t, label = "pothole")), t, true, true).level)
        }
    }
    @Test fun alternatingObjectsDoNotAccumulateHits() {
        val engine = RiskEvaluator()
        for (i in 0..12) {
            val t = i * 170L
            assertEquals(RiskLevel.IDLE, engine.evaluate(listOf(detection(t, label = if (i % 2 == 0) "person" else "car")), t, true, true).level)
        }
    }
    @Test fun unmatchedObjectsCannotHoldOldAlertIndefinitely() {
        val engine = RiskEvaluator()
        for (i in 0..2) feed(engine, i * 170L)
        var event: RiskEvent? = null
        for (i in 3..16) {
            val t = i * 170L
            event = engine.evaluate(listOf(detection(t, label = if (i % 2 == 0) "person" else "car")), t, true, true)
        }
        assertEquals(RiskLevel.IDLE, event!!.level)
    }
    @Test fun gapInvalidatesHistory() {
        val engine = RiskEvaluator()
        feed(engine, 0); feed(engine, 170)
        assertEquals(RiskLevel.IDLE, feed(engine, 2000).level)
    }
    @Test fun sensitivityAndHideDelayAreConfigurable() {
        val engine = RiskEvaluator(RiskConfig(confidence = .99f, hideDelayMs = 350))
        for (i in 0..10) assertEquals(RiskLevel.IDLE, feed(engine, i * 170L).level)
    }
    @Test fun vibrationUsesEdgesAndCooldown() {
        val gate = FeedbackGate()
        assertFalse(gate.shouldSignal(RiskLevel.IDLE, 0))
        assertTrue(gate.shouldSignal(RiskLevel.ATTENTION, 100))
        assertFalse(gate.shouldSignal(RiskLevel.WARNING, 200))
        assertFalse(gate.shouldSignal(RiskLevel.WARNING, 5000))
        gate.shouldSignal(RiskLevel.IDLE, 5100)
        assertTrue(gate.shouldSignal(RiskLevel.WARNING, 5200))
    }
    @Test fun resetClearsRisk() {
        val engine = RiskEvaluator()
        for (i in 0..2) feed(engine, i * 170L)
        engine.reset(500)
        assertEquals(RiskLevel.IDLE, feed(engine, 600).level)
    }
}
