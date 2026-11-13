package app.walkguard

import android.content.Context
import android.graphics.Bitmap
import app.walkguard.core.Box
import app.walkguard.core.Detection
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import java.io.Closeable
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

/** Single persistent CPU interpreter. All calls, including close(), use one analysis executor. */
class ObjectDetector(context: Context) : Closeable {
    private val labels = context.assets.open("models/labels.txt").bufferedReader().use { it.readLines() }
    private val interpreter: Interpreter
    private val input = ByteBuffer.allocateDirect(320 * 320 * 3).order(ByteOrder.nativeOrder())
    private val pixels = IntArray(320 * 320)
    private val boxes: Array<Array<FloatArray>>
    private val classes: Array<FloatArray>
    private val scores: Array<FloatArray>
    private val count = FloatArray(1)
    private val outputs: Map<Int, Any>
    var lastInferenceMs: Double = 0.0
        private set
    init {
        val buffer = context.assets.openFd("models/efficientdet_lite0.tflite").use { fd ->
            fd.createInputStream().use { stream ->
                val channel = stream.channel
                channel.map(FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength)
            }
        }
        val engine = Interpreter(buffer, Interpreter.Options().setNumThreads(2))
        try {
            engine.allocateTensors()
            check(engine.getInputTensor(0).dataType() == DataType.UINT8)
            check(engine.getInputTensor(0).shape().contentEquals(intArrayOf(1, 320, 320, 3)))
            check(engine.outputTensorCount == 4) { "Неподдерживаемый контракт модели" }
            val n = engine.getOutputTensor(0).shape()[1]
            boxes = Array(1) { Array(n) { FloatArray(4) } }
            classes = Array(1) { FloatArray(n) }; scores = Array(1) { FloatArray(n) }
            outputs = mapOf(0 to boxes, 1 to classes, 2 to scores, 3 to count)
            interpreter = engine
        } catch (e: Exception) { engine.close(); throw e }
    }
    fun detect(square: Bitmap, now: Long, scale: Float, padX: Float, padY: Float,
               sourceWidth: Int, sourceHeight: Int): List<Detection> {
        square.getPixels(pixels, 0, 320, 0, 0, 320, 320)
        input.rewind()
        for (pixel in pixels) { input.put((pixel shr 16 and 255).toByte()); input.put((pixel shr 8 and 255).toByte()); input.put((pixel and 255).toByte()) }
        input.rewind()
        val inferenceStart = android.os.SystemClock.elapsedRealtimeNanos()
        interpreter.runForMultipleInputsOutputs(arrayOf(input), outputs)
        lastInferenceMs = (android.os.SystemClock.elapsedRealtimeNanos() - inferenceStart) / 1e6
        return (0 until count[0].toInt().coerceIn(0, scores[0].size)).mapNotNull { i ->
            val label = labels.getOrNull(classes[0][i].toInt()) ?: return@mapNotNull null
            if (label == "???" || scores[0][i] < 0.25f) return@mapNotNull null
            val b = boxes[0][i]
            val box = Box(
                ((b[1] * 320 - padX) / scale / sourceWidth).coerceIn(0f, 1f),
                ((b[0] * 320 - padY) / scale / sourceHeight).coerceIn(0f, 1f),
                ((b[3] * 320 - padX) / scale / sourceWidth).coerceIn(0f, 1f),
                ((b[2] * 320 - padY) / scale / sourceHeight).coerceIn(0f, 1f))
            if (box.area <= 0) null else Detection(label, scores[0][i], box, now)
        }
    }
    override fun close() = interpreter.close()
}
