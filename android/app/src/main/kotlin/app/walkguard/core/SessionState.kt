package app.walkguard.core

enum class SessionPhase { STOPPED, STARTING, ACTIVE, STOPPING, ERROR }

/** Main-thread lifecycle gate; late asynchronous camera callbacks cannot revive a stopped session. */
class SessionState {
    var phase = SessionPhase.STOPPED
        private set
    var generation = 0
        private set
    fun begin(): Int? {
        if (phase == SessionPhase.STARTING || phase == SessionPhase.ACTIVE || phase == SessionPhase.STOPPING) return null
        phase = SessionPhase.STARTING
        return ++generation
    }
    fun activate(token: Int): Boolean {
        if (token != generation || phase != SessionPhase.STARTING) return false
        phase = SessionPhase.ACTIVE
        return true
    }
    fun stop() { ++generation; phase = SessionPhase.STOPPING }
    fun finish(error: Boolean = false) { phase = if (error) SessionPhase.ERROR else SessionPhase.STOPPED }
    fun accepts(token: Int) = generation == token && (phase == SessionPhase.ACTIVE || phase == SessionPhase.STARTING)
}
