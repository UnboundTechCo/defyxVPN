package de.unboundtech.defyxvpn

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val TAG = "VibrationPlugin"

class VibrationPlugin(private val context: Context) {
    private var lastVibrationTime: Long = 0
    private val throttleDurationMs: Long = 5000

    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasVibrator" -> {
                result.success(vibrator.hasVibrator())
            }
            "vibrate" -> {
                val duration = call.argument<Int>("duration") ?: 50
                vibrate(duration, result)
            }
            "cancel" -> {
                cancel(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun canVibrate(): Boolean {
        val currentTime = System.currentTimeMillis()
        val timeSinceLastVibration = currentTime - lastVibrationTime
        return timeSinceLastVibration >= throttleDurationMs
    }

    private fun recordVibration() {
        lastVibrationTime = System.currentTimeMillis()
    }

    private fun vibrate(duration: Int, result: MethodChannel.Result) {
        if (!canVibrate()) {
            Log.d(TAG, "Vibration throttled")
            result.success(false)
            return
        }

        try {
            if (!vibrator.hasVibrator()) {
                result.success(false)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val effect = VibrationEffect.createOneShot(
                    duration.toLong(),
                    VibrationEffect.DEFAULT_AMPLITUDE
                )
                val attributes = android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                    .build()
                vibrator.vibrate(effect, attributes)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createOneShot(
                    duration.toLong(),
                    VibrationEffect.DEFAULT_AMPLITUDE
                )
                vibrator.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(duration.toLong())
            }

            recordVibration()
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error in vibration: ${e.message}", e)
            result.error("VIBRATION_ERROR", "Failed to vibrate", e.message)
        }
    }

    private fun cancel(result: MethodChannel.Result) {
        try {
            vibrator.cancel()
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error canceling vibration: ${e.message}", e)
            result.error("CANCEL_ERROR", "Failed to cancel vibration", e.message)
        }
    }
}
