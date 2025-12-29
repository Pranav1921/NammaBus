package com.benjaminabel.vibration;

import android.content.Context;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class VibrationPlugin implements FlutterPlugin, MethodCallHandler {
    private MethodChannel channel;
    private Vibrator vibrator;
    private Context context;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
        context = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "vibration");
        channel.setMethodCallHandler(this);
        vibrator = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "hasVibrator":
                result.success(vibrator.hasVibrator());
                break;
            case "hasAmplitudeControl":
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    result.success(vibrator.hasAmplitudeControl());
                } else {
                    result.success(false);
                }
                break;
            case "vibrate":
                int duration = call.argument("duration");
                int amplitude = call.argument("amplitude");

                if (vibrator.hasVibrator()) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(duration, amplitude == -1 ? VibrationEffect.DEFAULT_AMPLITUDE : amplitude));
                    } else {
                        vibrator.vibrate(duration);
                    }
                }
                result.success(null);
                break;
            case "cancel":
                if (vibrator.hasVibrator()) {
                    vibrator.cancel();
                }
                result.success(null);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}