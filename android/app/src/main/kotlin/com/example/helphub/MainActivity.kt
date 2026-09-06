package com.example.helphub

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "helphub/device_feedback"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "setTorch") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val enabled = call.argument<Boolean>("enabled") ?: false
                try {
                    val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                    val cameraId = manager.cameraIdList.firstOrNull { id ->
                        manager.getCameraCharacteristics(id)
                            .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                    }
                    if (cameraId == null) {
                        result.error("NO_FLASH", "This device has no flashlight.", null)
                    } else {
                        manager.setTorchMode(cameraId, enabled)
                        result.success(true)
                    }
                } catch (error: Exception) {
                    result.error("TORCH_ERROR", error.message, null)
                }
            }
    }
}
