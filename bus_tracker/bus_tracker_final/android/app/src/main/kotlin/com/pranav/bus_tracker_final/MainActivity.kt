package com.pranav.bus_tracker_final

import android.content.Context
import android.util.Log
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "com.pranav.vibrate"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			if (call.method == "vibrate") {
				val duration = (call.argument<Int>("duration") ?: 500).toLong()
				Log.i("MainActivity", "vibrate method called with duration=$duration")
				val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator?
				if (vibrator != null) {
					try {
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
							vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
						} else {
							@Suppress("DEPRECATION")
							vibrator.vibrate(duration)
						}
						result.success(true)
						Log.i("MainActivity", "vibration invoked successfully")
					} catch (e: Exception) {
						Log.e("MainActivity", "vibration invocation failed: ${e.message}", e)
						result.error("ERROR_VIBRATE", e.message, null)
					}
				} else {
					Log.w("MainActivity", "device has no vibrator")
					result.error("NO_VIBRATOR", "Device has no vibrator", null)
				}
			} else {
				result.notImplemented()
			}
		}
	}
}
