package app.walkguard

import android.hardware.camera2.CameraCharacteristics
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import kotlin.math.atan

object CameraSelectorFactory {
    /** Select only an exposed, bindable rear lens with plausible sensor size AND measured focal FOV. */
    @androidx.camera.camera2.interop.ExperimentalCamera2Interop
    fun select(provider: ProcessCameraProvider): Pair<CameraSelector, String> {
        val rear = provider.availableCameraInfos.filter { it.lensFacing == CameraSelector.LENS_FACING_BACK }
        check(rear.isNotEmpty()) { "Задняя камера недоступна" }
        fun fov(info: CameraInfo): Double? = runCatching {
            val c = Camera2CameraInfo.from(info)
            val sensor = c.getCameraCharacteristic(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE) ?: return@runCatching null
            val focal = c.getCameraCharacteristic(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.minOrNull() ?: return@runCatching null
            if (focal <= 0 || sensor.width <= 0 || sensor.height <= 0) return@runCatching null
            Math.toDegrees(2 * atan(sensor.width.toDouble() / (2 * focal)))
        }.getOrNull()
        val default = rear.firstOrNull { CameraSelector.DEFAULT_BACK_CAMERA.filter(listOf(it)).isNotEmpty() } ?: rear.first()
        val defaultFov = fov(default)
        val wide = rear.mapNotNull { info -> fov(info)?.let { info to it } }
            .filter { (_, angle) -> angle in 90.0..140.0 && defaultFov != null && angle >= defaultFov + 15 }
            .maxByOrNull { it.second }
        return if (wide != null) {
            val id = Camera2CameraInfo.from(wide.first).cameraId
            CameraSelector.Builder().addCameraFilter { infos -> infos.filter { Camera2CameraInfo.from(it).cameraId == id } }.build() to
                "REAR WIDE / FOV ≈${wide.second.toInt()}°"
        } else CameraSelector.DEFAULT_BACK_CAMERA to "REAR DEFAULT / wide not exposed or unverified"
    }
}
