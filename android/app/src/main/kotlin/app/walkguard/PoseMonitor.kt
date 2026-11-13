package app.walkguard

import android.content.Context
import android.hardware.*
import android.os.SystemClock
import kotlin.math.*

/** Gravity/gyro heuristic: useful tilt is not proof that the lens actually faces the path. */
class PoseMonitor(context: Context) : SensorEventListener {
    private val manager = context.getSystemService(SensorManager::class.java)
    private val gravity = manager.getDefaultSensor(Sensor.TYPE_GRAVITY)
    private val accelerometer = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val gyro = manager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
    @Volatile private var tiltUseful = false
    @Volatile private var angularSpeed = Float.POSITIVE_INFINITY
    @Volatile private var lastTilt = 0L
    @Volatile private var lastGyro = 0L
    @Volatile private var accelerationDelta = 0f
    private val filtered = FloatArray(3)
    val useful: Boolean get() = tiltUseful && SystemClock.elapsedRealtime() - lastTilt < 1500
    val stable: Boolean get() = useful && gyro != null && SystemClock.elapsedRealtime() - lastGyro < 1500 && angularSpeed < 0.3f && accelerationDelta < 2f
    val label: String get() = if (gravity == null && accelerometer == null) "SENSOR N/A"
        else if (useful) "USEFUL TILT (HEURISTIC)" else "КАМЕРА НЕ ВИДИТ ДОРОГУ"
    fun start() {
        (gravity ?: accelerometer)?.let { manager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
        gyro?.let { manager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
    }
    fun stop() = manager.unregisterListener(this)
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_GYROSCOPE) {
            angularSpeed = sqrt(event.values.sumOf { (it * it).toDouble() }).toFloat()
            lastGyro = SystemClock.elapsedRealtime(); return
        }
        val norm = sqrt(event.values.sumOf { (it * it).toDouble() }).toFloat().coerceAtLeast(0.01f)
        accelerationDelta = abs(norm - SensorManager.GRAVITY_EARTH)
        for (i in 0..2) filtered[i] = if (gravity != null) event.values[i] else 0.8f * filtered[i] + 0.2f * event.values[i]
        val filteredNorm = sqrt(filtered.sumOf { (it * it).toDouble() }).toFloat().coerceAtLeast(0.01f)
        tiltUseful = abs(filtered[2]) / filteredNorm < 0.88f
        lastTilt = SystemClock.elapsedRealtime()
    }
}
