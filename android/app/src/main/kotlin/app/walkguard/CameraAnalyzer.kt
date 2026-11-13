package app.walkguard

import android.graphics.*
import android.os.SystemClock
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import app.walkguard.core.*
import java.io.Closeable
import kotlin.math.min

class CameraAnalyzer(
    private val detector: ObjectDetector, private val pose: PoseMonitor,
    settings: GuardSettings, private val thermalFps: () -> Int,
    private val onFrame: (RiskEvent, Map<String, Any?>, Bitmap?) -> Unit,
    private val onError: (Throwable) -> Unit,
) : ImageAnalysis.Analyzer, Closeable {
    @Volatile var settings = settings
    private val risk = RiskEvaluator(settings.riskConfig())
    private val square = Bitmap.createBitmap(320, 320, Bitmap.Config.ARGB_8888)
    private val canvas = Canvas(square)
    private val paint = Paint(Paint.FILTER_BITMAP_FLAG)
    private var rgba: Bitmap? = null
    private var pixels = IntArray(0)
    private var lastStart = -1000L
    private var lastPublish = -1000L
    private var fpsStart = 0L
    private var frames = 0
    private var fps: Double? = null
    private var skipped = 0L
    private var totalMs = 0.0
    private var processed = 0L
    private val transform = Matrix()
    override fun analyze(image: ImageProxy) {
        try {
            val now = SystemClock.elapsedRealtime()
            val config = settings
            val effectiveFps = min(config.fps, thermalFps())
            if (now - lastStart < 1000 / effectiveFps) { skipped++; return }
            lastStart = now
            risk.config = config.riskConfig()
            if (!pose.useful) {
                fpsStart = 0; frames = 0; fps = null
                val event = risk.reset(now, "КАМЕРА НЕ ВИДИТ ДОРОГУ")
                if (now - lastPublish >= 500) {
                    lastPublish = now
                    onFrame(event, mapOf("pose" to pose.label, "fps" to null, "lastMs" to null,
                        "skipped" to skipped, "resolution" to "${image.width}×${image.height}",
                        "message" to event.message), null)
                }
                return
            }
            // CameraX RGBA plane: respect both pixel and row strides, including padding.
            val plane = image.planes[0]
            val buffer = plane.buffer
            val width = image.width; val height = image.height
            if (rgba?.width != width || rgba?.height != height) {
                rgba?.recycle(); rgba = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                pixels = IntArray(width * height)
            }
            val start = SystemClock.elapsedRealtimeNanos()
            val base = buffer.position()
            for (y in 0 until height) for (x in 0 until width) {
                val at = base + y * plane.rowStride + x * plane.pixelStride
                pixels[y * width + x] = Color.rgb(buffer.get(at).toInt() and 255,
                    buffer.get(at + 1).toInt() and 255, buffer.get(at + 2).toInt() and 255)
            }
            rgba!!.setPixels(pixels, 0, width, 0, 0, width, height)
            val crop = image.cropRect
            val rotation = image.imageInfo.rotationDegrees
            val sourceWidth = if (rotation % 180 == 0) crop.width() else crop.height()
            val sourceHeight = if (rotation % 180 == 0) crop.height() else crop.width()
            val scale = min(320f / sourceWidth, 320f / sourceHeight)
            val padX = (320 - sourceWidth * scale) / 2
            val padY = (320 - sourceHeight * scale) / 2
            transform.reset()
            transform.postTranslate(-crop.exactCenterX(), -crop.exactCenterY())
            transform.postRotate(rotation.toFloat())
            transform.postScale(scale, scale)
            transform.postTranslate(160f, 160f)
            canvas.drawColor(Color.rgb(127, 127, 127))
            val save = canvas.save()
            canvas.clipRect(padX, padY, 320f - padX, 320f - padY)
            canvas.drawBitmap(rgba!!, transform, paint)
            canvas.restoreToCount(save)
            val detections = detector.detect(square, now, scale, padX, padY, sourceWidth, sourceHeight)
            val ms = (SystemClock.elapsedRealtimeNanos() - start) / 1e6
            processed++; totalMs += detector.lastInferenceMs; frames++
            if (fpsStart == 0L) fpsStart = now
            if (now - fpsStart >= 1000) { fps = frames * 1000.0 / (now - fpsStart); frames = 0; fpsStart = now }
            val event = risk.evaluate(detections, now, pose.useful, pose.stable)
            // No bitmap crosses the Flutter bridge. Only one optional warning snapshot is copied.
            val publish = now - lastPublish >= 500
            val metrics = if (publish) {
                lastPublish = now
                mapOf("fps" to fps, "averageMs" to totalMs / processed, "lastMs" to detector.lastInferenceMs, "pipelineMs" to ms,
                    "skipped" to skipped, "resolution" to "${width}×${height} / rot $rotation",
                    "pose" to pose.label, "effectiveTargetFps" to effectiveFps,
                    "lastDetection" to detections.maxByOrNull { it.confidence }?.let { "${it.label} · ${(it.confidence * 100).toInt()}%" },
                    "detections" to detections.map { mapOf("label" to it.label, "confidence" to it.confidence.toDouble(),
                        "box" to listOf(it.box.left, it.box.top, it.box.right, it.box.bottom).map(Float::toDouble), "timestamp" to it.timestamp) })
            } else emptyMap()
            val preview = if (publish && config.alerts && config.preview && event.level != RiskLevel.IDLE)
                square.copy(Bitmap.Config.ARGB_8888, false) else null
            onFrame(event, metrics, preview)
        } catch (e: Exception) { onError(e) }
        catch (e: LinkageError) { onError(e) }
        finally { image.close() }
    }
    override fun close() { detector.close(); rgba?.recycle(); square.recycle() }
}
