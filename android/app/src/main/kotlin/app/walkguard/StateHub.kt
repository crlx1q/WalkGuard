package app.walkguard

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object StateHub {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private val state = mutableMapOf<String, Any?>(
        "phase" to "STOPPED", "camera" to "OFF", "engine" to "UNLOADED",
        "fps" to null, "averageMs" to null, "lastMs" to null, "skipped" to 0L,
        "risk" to "IDLE", "lastDetection" to null, "resolution" to null,
        "model" to "EfficientDet-Lite0 INT8 / 1", "runtime" to "LiteRT 1.4.2 CPU",
        "message" to "Система наблюдения не активна", "pose" to "N/A", "thermal" to "N/A",
        "lens" to "N/A", "error" to null, "detections" to emptyList<Any>(),
    )
    @Synchronized fun snapshot(): Map<String, Any?> = state.toMap()
    fun attach(value: EventChannel.EventSink?) { sink = value; value?.success(snapshot()) }
    fun update(values: Map<String, Any?>) {
        synchronized(this) { state.putAll(values) }
        main.post { sink?.success(snapshot()) }
    }
}
