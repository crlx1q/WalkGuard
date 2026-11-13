package app.walkguard

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.ContextCompat
import app.walkguard.core.GuardSettings
import app.walkguard.core.RiskEvent
import app.walkguard.core.RiskLevel
import io.flutter.plugin.common.*

class WalkGuardPlugin(private val activity: MainActivity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methods = MethodChannel(messenger, "walkguard/commands")
    private val events = EventChannel(messenger, "walkguard/events")
    private val store = SettingsStore(activity)
    private val main = Handler(Looper.getMainLooper())
    private var permissionResult: MethodChannel.Result? = null
    private var demo: WarningOverlay? = null
    var visible = false
    init { methods.setMethodCallHandler(this); events.setStreamHandler(this) }
    fun permissions(): Map<String, Boolean> {
        val nm = activity.getSystemService(NotificationManager::class.java)
        val notificationGranted = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        val channelEnabled = Build.VERSION.SDK_INT < 26 ||
            nm.getNotificationChannel(WalkGuardService.CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE
        return mapOf("camera" to (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED),
            "overlay" to Settings.canDrawOverlays(activity),
            "notifications" to (notificationGranted && nm.areNotificationsEnabled() && channelEnabled))
    }
    fun refresh() {
        if (visible && permissionResult == null) WalkGuardService.instance?.resumeOverlay()
        StateHub.update(mapOf("permissions" to permissions()))
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "snapshot" -> result.success(StateHub.snapshot() + mapOf("permissions" to permissions()))
                "settings" -> result.success(store.load().toMap())
                "saveSettings" -> {
                    val settings = GuardSettings.fromMap(call.arguments as? Map<*, *> ?: emptyMap<Any, Any>())
                    store.save(settings)
                    WalkGuardService.instance?.applySettings(settings)
                    result.success(settings.toMap())
                }
                "start" -> {
                    check(visible) { "Запускайте камеру из открытого приложения" }
                    check(permissions().values.all { it }) { "Нужны разрешения камеры, оверлея и уведомлений" }
                    check(WalkGuardService.instance == null) { "Сервис уже запущен или ещё останавливается" }
                    hideDemo()
                    ContextCompat.startForegroundService(activity, Intent(activity, WalkGuardService::class.java).setAction(WalkGuardService.START))
                    result.success(null)
                }
                "stop" -> {
                    // stopService also cancels a pending start; UI waits for the native STOPPED event.
                    activity.stopService(Intent(activity, WalkGuardService::class.java))
                    hideDemo(); result.success(null)
                }
                "requestCamera" -> request(Manifest.permission.CAMERA, result)
                "requestNotifications" -> if (Build.VERSION.SDK_INT >= 33) request(Manifest.permission.POST_NOTIFICATIONS, result)
                    else result.success(permissions())
                "overlaySettings" -> {
                    hideDemo(); WalkGuardService.instance?.hideOverlay()
                    activity.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${activity.packageName}")))
                    result.success(null)
                }
                "appSettings" -> {
                    hideDemo(); WalkGuardService.instance?.hideOverlay()
                    activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}")))
                    result.success(null)
                }
                "notificationSettings" -> {
                    hideDemo(); WalkGuardService.instance?.hideOverlay()
                    activity.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName))
                    result.success(null)
                }
                "demo" -> {
                    check(visible && Settings.canDrawOverlays(activity)) { "Разрешите показ поверх приложений" }
                    check(WalkGuardService.instance == null) { "Остановите прогулку перед DEMO" }
                    hideDemo()
                    demo = WarningOverlay(activity.applicationContext).also {
                        it.show(RiskEvent(RiskLevel.WARNING, "DEMO", 1f, android.os.SystemClock.elapsedRealtime(), "DEMO · СМОТРИ ВПЕРЁД"), store.load(), true)
                    }
                    val fadeMs = if (store.load().reduceMotion || !android.animation.ValueAnimator.areAnimatorsEnabled()) 0L else 420L
                    main.postDelayed({ demo?.hide() }, 4500L - fadeMs)
                    main.postDelayed({ hideDemo() }, 4500)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) { result.error("WALKGUARD", e.message ?: e.javaClass.simpleName, null) }
    }
    private fun request(permission: String, result: MethodChannel.Result) {
        check(visible) { "Откройте приложение для выдачи разрешения" }
        check(permissionResult == null) { "Дождитесь текущего запроса разрешения" }
        hideDemo(); WalkGuardService.instance?.hideOverlay()
        if (ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(permissions()); return
        }
        permissionResult = result
        activity.requestPermissions(arrayOf(permission), 71)
    }
    fun onPermissionResult(code: Int) {
        if (code != 71) return
        permissionResult?.success(permissions()); permissionResult = null; refresh()
    }
    fun hideDemo() { main.removeCallbacksAndMessages(null); demo?.close(); demo = null }
    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) { StateHub.attach(sink); refresh() }
    override fun onCancel(arguments: Any?) { StateHub.attach(null) }
    fun dispose() {
        hideDemo(); permissionResult?.error("CLOSED", "Экран закрыт", null); permissionResult = null
        methods.setMethodCallHandler(null); events.setStreamHandler(null); StateHub.attach(null)
    }
}
