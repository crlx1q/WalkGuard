package app.walkguard.core

/** Shared native settings schema; the Android bridge persists this map atomically. */
data class GuardSettings(
    val mode: String = "BALANCED", val sensitivity: Float = 0.5f,
    val alerts: Boolean = true, val hideDelayMs: Long = 1000,
    val arcSize: Float = 1f, val glow: Float = 0.7f, val preview: Boolean = true,
    val showText: Boolean = true, val vibration: Boolean = true, val feedback: Float = 0.6f,
    val arcStyle: String = "MATRIX", val arcThickness: Float = 1f, val topOffset: Float = 0f,
    val dotDensity: Float = 1f, val revealMs: Long = 650,
    val reduceMotion: Boolean = false, val welcomeComplete: Boolean = false, val showMetrics: Boolean = true,
) {
    val fps: Int get() = when (mode) { "ECO" -> 3; "PERFORMANCE" -> 10; else -> 6 }
    fun riskConfig() = RiskConfig(confidence = 0.75f - sensitivity * 0.35f, hideDelayMs = hideDelayMs)
    fun toMap(): Map<String, Any> = mapOf("mode" to mode, "sensitivity" to sensitivity.toDouble(),
        "alerts" to alerts, "hideDelayMs" to hideDelayMs, "arcSize" to arcSize.toDouble(),
        "glow" to glow.toDouble(), "preview" to preview, "showText" to showText,
        "vibration" to vibration, "feedback" to feedback.toDouble(), "arcStyle" to arcStyle, "arcThickness" to arcThickness.toDouble(),
        "topOffset" to topOffset.toDouble(), "reduceMotion" to reduceMotion,
        "welcomeComplete" to welcomeComplete, "showMetrics" to showMetrics, "dotDensity" to dotDensity.toDouble(), "revealMs" to revealMs)
    fun toStoredMap(): Map<String, Any> = toMap() + ("previewDefaultVersion" to 1)

    companion object {
        fun fromStoredMap(values: Map<String, Any?>): GuardSettings {
            // Older releases persisted the old default alongside deliberate choices.
            val version = (values["previewDefaultVersion"] as? Number)?.toInt() ?: 0
            return fromMap(if (version == 0) values - "preview" else values)
        }


        fun fromMap(m: Map<*, *>): GuardSettings {
            fun float(key: String, default: Float, min: Float = 0f, max: Float = 1f): Float {
                val value = (m[key] as? Number)?.toFloat() ?: default
                return if (value.isFinite()) value.coerceIn(min, max) else default
            }
            return GuardSettings(
                mode = (m["mode"] as? String)?.takeIf { it in setOf("ECO", "BALANCED", "PERFORMANCE") } ?: "BALANCED",
                sensitivity = float("sensitivity", 0.5f), alerts = m["alerts"] as? Boolean ?: true,
                hideDelayMs = ((m["hideDelayMs"] as? Number)?.toLong() ?: 1000L).coerceIn(350, 3000),
                arcSize = float("arcSize", 1f, 0.7f, 1.3f), glow = float("glow", 0.7f, 0f, 1f),
                preview = m["preview"] as? Boolean ?: true, showText = m["showText"] as? Boolean ?: true,
                vibration = m["vibration"] as? Boolean ?: true, feedback = float("feedback", 0.6f, 0.2f, 1f),
                arcStyle = (m["arcStyle"] as? String)?.takeIf { it in setOf("MATRIX", "CONTOUR", "SEGMENTS") } ?: "MATRIX",
                arcThickness = float("arcThickness", 1f, .75f, 2f), topOffset = float("topOffset", 0f, 0f, 48f),
                reduceMotion = m["reduceMotion"] as? Boolean ?: false,
                welcomeComplete = m["welcomeComplete"] as? Boolean ?: false,
                showMetrics = m["showMetrics"] as? Boolean ?: true,
                dotDensity = float("dotDensity", 1f, .6f, 1.4f),
                revealMs = ((m["revealMs"] as? Number)?.toLong() ?: 650L).coerceIn(250, 1000))
        }
    }
}
