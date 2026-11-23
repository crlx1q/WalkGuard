package app.walkguard

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.hardware.input.InputManager
import android.os.Build
import android.view.*
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import app.walkguard.core.*
import java.io.Closeable
import kotlin.math.ceil
import kotlin.math.min
import kotlin.math.sin

/** One noninteractive, bounded window; opacity stays below Android's touch-obscuring threshold. */
class WarningOverlay(private val context: Context) : Closeable {
    private val manager = context.getSystemService(WindowManager::class.java)
    private val view = ArcView(context)
    private var attached = false
    private var animator: ValueAnimator? = null
    private var revision = 0
    private var shownLevel = RiskLevel.IDLE
    private fun attach() {
        if (attached) return
        val dp = context.resources.displayMetrics.density
        view.topInset = 28 * dp // Conservative until this actual overlay window receives insets.
        ViewCompat.setOnApplyWindowInsetsListener(view) { _, insets ->
            view.topInset = insets.getInsetsIgnoringVisibility(
                WindowInsetsCompat.Type.statusBars() or WindowInsetsCompat.Type.displayCutout()).top.toFloat()
            if (attached) {
                val params = view.layoutParams as WindowManager.LayoutParams
                val desiredHeight = view.requiredHeight()
                if (params.height != desiredHeight) {
                    params.height = desiredHeight; manager.updateViewLayout(view, params)
                }
            }
            view.invalidate()
            insets
        }
        val opacity = if (Build.VERSION.SDK_INT >= 31)
            min(0.75f, context.getSystemService(InputManager::class.java).maximumObscuringOpacityForTouch) else 0.75f
        val params = WindowManager.LayoutParams(WindowManager.LayoutParams.MATCH_PARENT,
            view.requiredHeight(), WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT).apply { gravity = Gravity.TOP; alpha = opacity; title = "WalkGuard warning" }
        manager.addView(view, params); attached = true; view.alpha = 0f
        ViewCompat.requestApplyInsets(view)
    }
    fun show(event: RiskEvent, settings: GuardSettings, demo: Boolean = false, preview: Bitmap? = null) {
        if (event.level == RiskLevel.IDLE || !settings.alerts && !demo) { preview?.recycle(); hide(); return }
        val needsRedraw = (view.event.level != event.level || view.event.message != event.message) || view.settings != settings || view.demo != demo || preview != null
        view.event = event; view.settings = settings; view.demo = demo
        attach()
        val params = view.layoutParams as WindowManager.LayoutParams
        if (params.height != view.requiredHeight()) {
            params.height = view.requiredHeight(); manager.updateViewLayout(view, params)
        }
        if (!settings.preview || demo) {
            preview?.recycle()
            clearPreview()
        } else if (preview != null) {
            // The Android render thread can still reference the previous bitmap.
            view.preview = preview
        }
        if (needsRedraw) { view.prepareLayer(); view.invalidate() }
        if (shownLevel == RiskLevel.IDLE) animate(1f, settings.revealMs, false)
        shownLevel = event.level
    }
    fun hide() {
        if (shownLevel == RiskLevel.IDLE) return
        shownLevel = RiskLevel.IDLE
        clearPreview()
        animate(0f, 420, true)
    }
    private fun animate(target: Float, duration: Long, remove: Boolean) {
        revision++; val token = revision
        animator?.cancel()
        if (view.settings.reduceMotion || !ValueAnimator.areAnimatorsEnabled()) {
            view.alpha = target; view.translationY = 0f; if (remove) detach(); return
        }
        animator = ValueAnimator.ofFloat(view.alpha, target).apply {
            this.duration = duration
            interpolator = android.view.animation.DecelerateInterpolator(2f)
            addUpdateListener {
                val value = it.animatedValue as Float
                view.alpha = value
                view.translationY = (1f - value) * -6 * context.resources.displayMetrics.density
            }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    if (remove && revision == token) detach()
                }
            })
            start()
        }
    }
    fun clearPreview() {
        if (view.preview != null) {
            view.preview = null
            view.invalidate()
        }
    }

    private fun detach() {
        if (attached) { runCatching { manager.removeViewImmediate(view) }; attached = false }
    }
    override fun close() {
        revision++; animator?.cancel(); animator = null
        clearPreview()
        shownLevel = RiskLevel.IDLE; detach(); view.releaseLayer()
    }
    private class ArcView(context: Context) : View(context) {
        private val dp = resources.displayMetrics.density
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val textPlate = RectF()
        private val previewRect = RectF()
        private val previewClip = Path()
        private val labelFont = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        private var layer: Bitmap? = null
        private var layerSettings: GuardSettings? = null
        private var layerWidth = 0
        var topInset = 0f
        var event = RiskEvent(RiskLevel.IDLE, timestamp = 0)
        var settings = GuardSettings()
        var demo = false
        var preview: Bitmap? = null
        init { importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO; setWillNotDraw(false) }
        private fun radiusY(): Float {
            val w = if (width > 0) width.toFloat() / dp else resources.displayMetrics.widthPixels / dp
            return min(172f * settings.arcSize, min(w * .53f, w * .45f * settings.arcSize) * .88f)
        }
        fun requiredHeight(): Int = ceil(topInset + (36 + settings.topOffset + 172f * settings.arcSize +
            (if (settings.showText || demo) 40 else 0)) * dp).toInt()
        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh); prepareLayer()
        }
        fun releaseLayer() { layer = null; layerSettings = null; layerWidth = 0 }
        fun prepareLayer() {
            if (width <= 0 || (layerWidth == width && layerSettings == settings && layer != null)) return
            releaseLayer()
            val field = DotField.create(width / dp, settings)
            val bitmap = Bitmap.createBitmap(width, ((field.radiusY + 24) * dp).toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
            val c = Canvas(bitmap); c.scale(dp, dp)
            val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val red = Color.rgb(255, 59, 53)
            val rect = RectF(width / dp / 2 - field.radiusX, 8 - field.radiusY, width / dp / 2 + field.radiusX, 8 + field.radiusY)
            if (settings.arcStyle == "MATRIX") {
                for (dot in field.dots) {
                    if (dot.halo && settings.glow > 0) {
                        p.color = red; p.alpha = (dot.opacity * 14 * settings.glow).toInt()
                        c.drawCircle(dot.x, dot.y, 6 * settings.arcThickness, p)
                        p.alpha = (dot.opacity * 28 * settings.glow).toInt()
                        c.drawCircle(dot.x, dot.y, 2.8f * settings.arcThickness, p)
                    }
                    p.color = red; p.alpha = (dot.opacity * 255).toInt()
                    c.drawCircle(dot.x, dot.y, dot.radius, p)
                }
                p.style = Paint.Style.STROKE; p.strokeWidth = .6f
                for (i in 0..89) {
                    p.alpha = (sin((i + .5) / 90 * Math.PI).let { it * it } * 107).toInt()
                    c.drawArc(rect, i * 2f, 2.12f, false, p)
                }
            } else {
                p.color = red; p.style = Paint.Style.STROKE; p.strokeWidth = 1.4f * settings.arcThickness; p.strokeCap = Paint.Cap.ROUND
                if (settings.arcStyle == "SEGMENTS") {
                    for (i in 0..34) c.drawArc(rect, i * 5.14f + .8f, 3.5f, false, p)
                } else c.drawArc(rect, 0f, 180f, false, p)
            }
            layer = bitmap; layerWidth = width; layerSettings = settings
        }
        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val cx = width / 2f
            val top = topInset + (12 + settings.topOffset) * dp
            val intensity = when (event.level) { RiskLevel.CRITICAL -> 1f; RiskLevel.WARNING -> .9f; else -> .7f }
            paint.color = Color.WHITE; paint.alpha = (intensity * 255).toInt(); paint.style = Paint.Style.FILL
            layer?.let { canvas.drawBitmap(it, 0f, top, paint) }
            preview?.let { drawCameraFrame(canvas, it, cx, top) }
            val nextY = top + (radiusY() + 24) * dp
            if (settings.showText || demo) {
                val label = if (demo) "DEMO · Смотри вперёд" else event.message
                paint.typeface = labelFont; paint.textAlign = Paint.Align.CENTER; paint.textSize = 15 * dp
                val maximum = (width - 48 * dp).coerceAtLeast(1f)
                val textWidth = paint.measureText(label)
                if (textWidth > maximum) paint.textSize *= maximum / textWidth
                val halfWidth = paint.measureText(label) / 2 + 12 * dp
                textPlate.set(cx - halfWidth, nextY, cx + halfWidth, nextY + 32 * dp)
                paint.color = Color.rgb(12, 12, 12); paint.alpha = 235
                canvas.drawRoundRect(textPlate, 8 * dp, 8 * dp, paint)
                paint.color = Color.rgb(255, 133, 128); paint.alpha = 255
                canvas.drawText(label, cx, nextY + 16 * dp - (paint.ascent() + paint.descent()) / 2, paint)
            }
        }

        private fun drawCameraFrame(canvas: Canvas, bitmap: Bitmap, cx: Float, top: Float) {
            val radius = radiusY() * dp
            val scale = min(min(156 * dp, radius * 1.18f) / bitmap.width,
                min(92 * dp, radius * .61f) / bitmap.height)
            val halfWidth = bitmap.width * scale / 2
            val frameTop = top + 8 * dp
            previewRect.set(cx - halfWidth, frameTop, cx + halfWidth, frameTop + bitmap.height * scale)
            paint.color = Color.rgb(16, 16, 16)
            canvas.drawRoundRect(previewRect, 8 * dp, 8 * dp, paint)
            previewClip.reset()
            previewClip.addRoundRect(previewRect, 8 * dp, 8 * dp, Path.Direction.CW)
            val checkpoint = canvas.save()
            canvas.clipPath(previewClip)
            paint.color = Color.WHITE
            paint.isFilterBitmap = true
            canvas.drawBitmap(bitmap, null, previewRect, paint)
            canvas.restoreToCount(checkpoint)
        }
    }
}
