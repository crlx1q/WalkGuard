package app.walkguard.core

import kotlin.math.*

data class Box(val left: Float, val top: Float, val right: Float, val bottom: Float) {
    val area: Float get() = (right - left).coerceAtLeast(0f) * (bottom - top).coerceAtLeast(0f)
    val centerX: Float get() = (left + right) / 2
    fun iou(other: Box): Float {
        val intersection = (min(right, other.right) - max(left, other.left)).coerceAtLeast(0f) *
            (min(bottom, other.bottom) - max(top, other.top)).coerceAtLeast(0f)
        return intersection / (area + other.area - intersection).coerceAtLeast(0.00001f)
    }
}
data class Detection(val label: String, val confidence: Float, val box: Box, val timestamp: Long)
enum class RiskLevel { IDLE, ATTENTION, WARNING, CRITICAL }
data class RiskEvent(
    val level: RiskLevel, val detectedClass: String? = null, val confidence: Float? = null,
    val timestamp: Long, val message: String = "Недостаточно информации для оценки",
) {
    fun toMap(): Map<String, Any?> = mapOf("risk" to level.name, "detectedClass" to detectedClass,
        "confidence" to confidence?.toDouble(), "riskTimestamp" to timestamp, "message" to message)
}
data class RiskConfig(
    val confidence: Float = 0.55f, val attentionArea: Float = 0.035f,
    val warningArea: Float = 0.16f, val criticalArea: Float = 0.34f,
    val requiredHits: Int = 3, val hideDelayMs: Long = 1000,
    val maxGapMs: Long = 800, val growthPerSecond: Float = 0.65f,
)

/** Experimental image-space heuristics, never a distance or a collision prediction. */
class RiskEvaluator(var config: RiskConfig = RiskConfig()) {
    private data class Sample(val detection: Detection, val time: Long)
    private val history = ArrayDeque<Sample>()
    private var lastEvidence = -1L
    private var current = RiskEvent(RiskLevel.IDLE, timestamp = 0)
    private var lastTime = -1L
    private val relevant = setOf("person", "bicycle", "car", "motorcycle", "bus", "train", "truck",
        "bench", "dog", "cat", "horse", "cow", "sheep", "suitcase", "chair", "potted plant")

    fun reset(now: Long = 0, message: String = "Недостаточно информации для оценки"): RiskEvent {
        history.clear(); lastEvidence = -1; lastTime = now
        current = RiskEvent(RiskLevel.IDLE, timestamp = now, message = message)
        return current
    }

    fun evaluate(detections: List<Detection>, now: Long, usefulPose: Boolean, stableMotion: Boolean): RiskEvent {
        if (!usefulPose) return reset(now, "КАМЕРА НЕ ВИДИТ ДОРОГУ")
        if (lastTime >= 0 && (now < lastTime || now - lastTime > config.maxGapMs)) reset(now)
        lastTime = now
        val candidate = detections.filter {
            it.label in relevant && it.confidence.isFinite() && it.confidence >= config.confidence &&
                now - it.timestamp in 0..config.maxGapMs &&
                it.box.area.isFinite() && it.box.area >= config.attentionArea &&
                it.box.centerX in 0.28f..0.72f && it.box.bottom > 0.4f
        }.maxByOrNull { it.box.area * it.confidence }
        if (candidate == null) {
            history.clear()
            if (lastEvidence < 0 || now - lastEvidence >= config.hideDelayMs) {
                current = RiskEvent(RiskLevel.IDLE, timestamp = now, message =
                    if (detections.isEmpty()) "Нет обнаружений. Это не означает, что путь безопасен."
                    else "Объект обнаружен; признаков риска недостаточно")
            }
            return current.copy(timestamp = now)
        }
        val previous = history.lastOrNull()
        if (previous != null && (previous.detection.label != candidate.label ||
                previous.detection.box.iou(candidate.box) < 0.25f || now - previous.time > config.maxGapMs)) {
            history.clear()
        }
        history.addLast(Sample(candidate, now))
        while (history.size > 8) history.removeFirst()
        if (history.size < config.requiredHits) {
            if (lastEvidence >= 0 && now - lastEvidence >= config.hideDelayMs) {
                current = RiskEvent(RiskLevel.IDLE, timestamp = now)
            }
            return current.copy(timestamp = now)
        }
        val first = history.first()
        val duration = (now - first.time) / 1000f
        val growth = if (duration >= 0.45f && stableMotion)
            (candidate.box.area / first.detection.box.area - 1f) / duration else 0f
        // Critical needs persistent matched growth, a large central object AND stable phone motion.
        val level = when {
            history.size >= 5 && duration >= 0.6f && growth >= config.growthPerSecond &&
                candidate.box.area >= config.criticalArea && stableMotion -> RiskLevel.CRITICAL
            candidate.box.area >= config.warningArea -> RiskLevel.WARNING
            else -> RiskLevel.ATTENTION
        }
        lastEvidence = now
        // Keep the stronger level briefly: hysteresis prevents pulses at area thresholds.
        val heldLevel = if (level.ordinal < current.level.ordinal &&
            now - current.timestamp < config.hideDelayMs) current.level else level
        if (heldLevel != current.level || current.detectedClass != candidate.label) {
            current = RiskEvent(heldLevel, candidate.label, candidate.confidence, now,
                when (heldLevel) {
                    RiskLevel.CRITICAL -> "СТОП. СМОТРИ ВПЕРЁД"
                    RiskLevel.WARNING -> "ПРЕПЯТСТВИЕ ВПЕРЕДИ"
                    else -> "СМОТРИ ВПЕРЁД"
                })
        }
        return current.copy(confidence = candidate.confidence)
    }
}

/** Vibration is edge-triggered with a global cooldown, never every camera frame. */
class FeedbackGate(private val cooldownMs: Long = 4000) {
    private var last = -cooldownMs
    private var previous = RiskLevel.IDLE
    fun shouldSignal(level: RiskLevel, now: Long): Boolean {
        val rising = level.ordinal > previous.ordinal
        previous = level
        if (!rising || now - last < cooldownMs) return false
        last = now
        return true
    }
}
