package app.walkguard.core

/** One immediate frame per warning, then at most two updates per second. */
internal class PreviewCadence {
    private var lastCapture: Long? = null

    fun shouldCapture(now: Long, visible: Boolean): Boolean {
        if (!visible) {
            lastCapture = null
            return false
        }
        val previous = lastCapture
        if (previous != null && now - previous < 500L) return false
        lastCapture = now
        return true
    }
}
