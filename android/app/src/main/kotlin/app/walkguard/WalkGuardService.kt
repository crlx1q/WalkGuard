package app.walkguard

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.os.*
import android.provider.Settings
import android.util.Size
import android.view.WindowManager
import androidx.camera.core.*
import androidx.camera.core.resolutionselector.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleService
import app.walkguard.core.*
import java.util.concurrent.Executors

class WalkGuardService : LifecycleService(), DisplayManager.DisplayListener {
    companion object {
        const val CHANNEL = "walkguard_camera"
        const val START = "app.walkguard.START"
        const val STOP = "app.walkguard.STOP"
        @Volatile var instance: WalkGuardService? = null
            private set
    }
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val session = SessionState()
    private var provider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    @Volatile private var analyzer: CameraAnalyzer? = null
    private lateinit var overlay: WarningOverlay
    private lateinit var pose: PoseMonitor
    @Volatile private var settings = GuardSettings()
    private var failed = false
    private var destroyed = false
    private var errorMessage: String? = null
    private var heartbeat = 0L
    private val feedbackGate = FeedbackGate()
    @Volatile private var thermal = 0
    private var previousRisk = RiskLevel.IDLE
    private var overlaySuppressed = false
    private val power by lazy { getSystemService(PowerManager::class.java) }
    private val thermalListener = if (Build.VERSION.SDK_INT >= 29) PowerManager.OnThermalStatusChangedListener { status ->
        thermal = status
        StateHub.update(mapOf("thermal" to thermalName(status), "throttled" to (status >= 2)))
        if (status >= 4) fail("Устройство перегрелось. Анализ остановлен.")
    } else null
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                errorMessage = "Анализ остановлен при блокировке экрана"; stopSelf()
            }
        }
    }
    private val watchdog = object : Runnable {
        override fun run() {
            if (destroyed) return
            if (!power.isInteractive || getSystemService(KeyguardManager::class.java).isKeyguardLocked) {
                errorMessage = "Анализ остановлен при блокировке экрана"; stopSelf(); return
            }
            val nm = getSystemService(NotificationManager::class.java)
            if (!nm.areNotificationsEnabled() || nm.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE ||
                (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(this@WalkGuardService,
                    Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)) {
                fail("Уведомления отключены. Анализ остановлен."); return
            }
            if (!Settings.canDrawOverlays(this@WalkGuardService) ||
                ContextCompat.checkSelfPermission(this@WalkGuardService, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                fail("Разрешение камеры или оверлея отозвано"); return
            }
            if (session.phase == SessionPhase.ACTIVE && SystemClock.elapsedRealtime() - heartbeat > 7000) {
                fail("Камера перестала предоставлять кадры"); return
            }
            main.postDelayed(this, 1500)
        }
    }
    override fun onCreate() {
        super.onCreate(); instance = this
        overlay = WarningOverlay(applicationContext); pose = PoseMonitor(this)
        settings = SettingsStore(this).load()
        ContextCompat.registerReceiver(this, screenReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF), ContextCompat.RECEIVER_NOT_EXPORTED)
        getSystemService(DisplayManager::class.java).registerDisplayListener(this, main)
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        if (intent?.action != START) { stopSelf(); return START_NOT_STICKY }
        val token = session.begin() ?: return START_NOT_STICKY
        try {
            check(power.isInteractive && !getSystemService(KeyguardManager::class.java).isKeyguardLocked) { "Экран заблокирован" }
            check(ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) { "Нет разрешения камеры" }
            check(Settings.canDrawOverlays(this)) { "Нет разрешения оверлея" }
            createChannel()
            val serviceType = if (Build.VERSION.SDK_INT >= 30) ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA else 0
            ServiceCompat.startForeground(this, 18, notification(), serviceType)
            StateHub.update(mapOf("phase" to "STARTING", "camera" to "OPENING", "engine" to "LOADING",
                "error" to null, "message" to "Запуск локальной модели и камеры…", "fps" to null,
                "lastMs" to null, "averageMs" to null, "skipped" to 0L, "lastDetection" to null,
                "risk" to "IDLE", "resolution" to null, "detections" to emptyList<Any>()))
            if (Build.VERSION.SDK_INT >= 29) {
                thermal = power.currentThermalStatus
                power.addThermalStatusListener(main::post, thermalListener!!)
                StateHub.update(mapOf("thermal" to thermalName(thermal)))
                if (thermal >= 4) { fail("Устройство перегрелось. Анализ не запущен."); return START_NOT_STICKY }
            }
            pose.start(); heartbeat = SystemClock.elapsedRealtime()
            main.postDelayed(watchdog, 1500)
            main.postDelayed({ if (session.accepts(token) && session.phase == SessionPhase.STARTING) fail("Истекло время запуска камеры") }, 15000)
            executor.execute {
                try {
                    analyzer = CameraAnalyzer(ObjectDetector(this), pose, settings,
                        { if (thermal >= 2) 3 else 10 },
                        { event, metrics, preview -> main.post {
                            if (!session.accepts(token)) { preview?.recycle(); return@post }
                            heartbeat = SystemClock.elapsedRealtime()
                            runCatching {
                                if (metrics.isNotEmpty() || previousRisk != event.level) {
                                    StateHub.update(metrics + event.toMap() + mapOf("engine" to "READY"))
                                }
                                previousRisk = event.level
                                if (overlaySuppressed) preview?.recycle()
                                else overlay.show(event, settings, preview = preview)
                                if (settings.alerts && settings.vibration && feedbackGate.shouldSignal(event.level, heartbeat)) vibrate(event.level)
                            }.onFailure { preview?.takeUnless { it.isRecycled }?.recycle(); fail("Ошибка оверлея: ${it.message}") }
                        } }, { error -> main.post { if (session.accepts(token)) fail("Ошибка инференса: ${error.message}", true) } })
                    main.post { if (session.accepts(token)) openCamera(token) }
                } catch (e: Exception) { main.post { if (session.accepts(token)) fail("Модель не загрузилась: ${e.message}", true) } }
                catch (e: LinkageError) { main.post { if (session.accepts(token)) fail("Нативный runtime ИИ недоступен: ${e.message}", true) } }
            }
        } catch (e: Exception) { fail("Не удалось запустить сервис: ${e.message}") }
        return START_NOT_STICKY
    }
    @androidx.annotation.OptIn(markerClass = [androidx.camera.camera2.interop.ExperimentalCamera2Interop::class])
    private fun openCamera(token: Int) {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            if (!session.accepts(token)) return@addListener
            try {
                provider = future.get()
                analysis = ImageAnalysis.Builder()
                    .setResolutionSelector(ResolutionSelector.Builder().setResolutionStrategy(
                        ResolutionStrategy(Size(640, 480), ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER)).build())
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setTargetRotation(displayRotation())
                    .build().also { it.setAnalyzer(executor, analyzer!!) }
                val (selector, lens) = CameraSelectorFactory.select(provider!!)
                var actualLens = lens
                val camera = try { provider!!.bindToLifecycle(this, selector, analysis) }
                    catch (e: Exception) {
                        provider!!.unbindAll()
                        actualLens = "REAR DEFAULT / wide binding failed"
                        provider!!.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, analysis)
                    }
                StateHub.update(mapOf("lens" to actualLens))
                camera.cameraInfo.cameraState.observe(this) { state ->
                    if (!session.accepts(token)) return@observe
                    if (state.error != null) { fail("Камера недоступна (код ${state.error!!.code})"); return@observe }
                    if (state.type == CameraState.Type.OPEN && session.activate(token)) {
                        StateHub.update(mapOf("phase" to "ACTIVE", "camera" to "ON", "engine" to "READY",
                            "message" to "Камера анализирует пространство впереди"))
                    }
                }
            } catch (e: Exception) { fail("Камера недоступна: ${e.message}") }
        }, ContextCompat.getMainExecutor(this))
    }
    fun applySettings(value: GuardSettings) {
        settings = value; analyzer?.settings = value
        if (!value.alerts) overlay.hide()
        StateHub.update(mapOf("mode" to value.mode))
    }
    fun hideOverlay() { overlaySuppressed = true; overlay.hide() }
    fun resumeOverlay() { overlaySuppressed = false }
    private fun fail(message: String, engineError: Boolean = false) {
        if (destroyed || failed) return
        failed = true; errorMessage = message
        if (engineError) StateHub.update(mapOf("engine" to "ERROR"))
        StateHub.update(mapOf("error" to message, "message" to message)); stopSelf()
    }
    private fun vibrate(level: RiskLevel) {
        val vibrator = if (Build.VERSION.SDK_INT >= 31) getSystemService(VibratorManager::class.java).defaultVibrator
            else getSystemService(Vibrator::class.java)
        if (!vibrator.hasVibrator()) return
        val duration = when (level) { RiskLevel.CRITICAL -> 160L; RiskLevel.WARNING -> 100L; else -> 45L }
        vibrator.vibrate(VibrationEffect.createOneShot(duration, (settings.feedback * 255).toInt().coerceIn(1, 255)))
    }
    private fun createChannel() {
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Наблюдение WalkGuard", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Постоянное уведомление об использовании камеры"; setSound(null, null)
            })
    }
    private fun notification(): Notification {
        val open = PendingIntent.getActivity(this, 1, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 2, Intent(this, WalkGuardService::class.java).setAction(STOP), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return NotificationCompat.Builder(this, CHANNEL).setSmallIcon(R.drawable.ic_guard)
            .setContentTitle("WalkGuard · камера включена")
            .setContentText("Локальный анализ. Поднимайте взгляд от телефона.")
            .setContentIntent(open).addAction(R.drawable.ic_guard, "ОСТАНОВИТЬ", stop)
            .setOngoing(true).setSilent(true).setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE).build()
    }
    override fun onTaskRemoved(rootIntent: Intent?) { stopSelf(); super.onTaskRemoved(rootIntent) }
    override fun onDestroy() {
        destroyed = true; session.stop()
        StateHub.update(mapOf("phase" to "STOPPING", "camera" to "CLOSING"))
        main.removeCallbacksAndMessages(null)
        runCatching { analysis?.clearAnalyzer() }; runCatching { provider?.unbindAll() }
        analysis = null; provider = null
        pose.stop(); overlay.close()
        runCatching { unregisterReceiver(screenReceiver) }
        getSystemService(DisplayManager::class.java).unregisterDisplayListener(this)
        if (Build.VERSION.SDK_INT >= 29 && thermalListener != null) runCatching { power.removeThermalStatusListener(thermalListener!!) }
        // Close the interpreter after any in-flight inference, on the same thread.
        executor.execute { runCatching { analyzer?.close() }; analyzer = null }
        executor.shutdown()
        stopForeground(STOP_FOREGROUND_REMOVE)
        instance = null; session.finish(failed)
        StateHub.update(mapOf("phase" to session.phase.name, "camera" to "OFF", "fps" to null,
            "risk" to "IDLE", "pose" to "N/A", "detections" to emptyList<Any>(),
            "engine" to if (failed && StateHub.snapshot()["engine"] == "ERROR") "ERROR" else "UNLOADED",
            "error" to if (failed) errorMessage else null,
            "message" to (errorMessage ?: "Система наблюдения не активна")))
        super.onDestroy()
    }
    private fun displayRotation(): Int = getSystemService(DisplayManager::class.java)
        .getDisplay(android.view.Display.DEFAULT_DISPLAY)?.rotation ?: android.view.Surface.ROTATION_0
    override fun onDisplayAdded(displayId: Int) = Unit
    override fun onDisplayRemoved(displayId: Int) = Unit
    override fun onDisplayChanged(displayId: Int) {
        analysis?.targetRotation = displayRotation()
    }
    private fun thermalName(value: Int): String = when (value) {
        0 -> "NONE"; 1 -> "LIGHT"; 2 -> "MODERATE · ECO LIMIT"; 3 -> "SEVERE · ECO LIMIT"
        4 -> "CRITICAL"; 5 -> "EMERGENCY"; 6 -> "SHUTDOWN"; else -> "N/A"
    }
}
