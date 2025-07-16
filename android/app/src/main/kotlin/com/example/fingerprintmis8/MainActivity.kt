package com.example.fingerprintmis8

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.fingerprintmis8/fingerprint_sdk"

    private var fingerprintSdkWrapper: FingerprintSdkWrapper? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
            ?: throw IllegalStateException("BinaryMessenger is null")

        fingerprintSdkWrapper = FingerprintSdkWrapper(this, MethodChannel(messenger, CHANNEL))

        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDevice" -> {
                    val success = fingerprintSdkWrapper?.openDevice() ?: false
                    result.success(success)
                }
                "closeDevice" -> {
                    fingerprintSdkWrapper?.closeDevice()
                    result.success(null)
                }
                "enrollTemplate" -> {
                    fingerprintSdkWrapper?.enrollTemplate()
                    result.success(null)
                }
                "generateTemplate" -> {
                    fingerprintSdkWrapper?.generateTemplate()
                    result.success(null)
                }
                "pauseUnregister" -> {
                    fingerprintSdkWrapper?.pauseUnregister()
                    result.success(null)
                }
                "resumeRegister" -> {
                    fingerprintSdkWrapper?.resumeRegister()
                    result.success(null)
                }
                "matchTemplates" -> {
                    val args = call.arguments as Map<String, Any>
                    val template1 = args["template1"] as ByteArray
                    val template2 = args["template2"] as ByteArray
                    val score = fingerprintSdkWrapper?.matchTemplates(template1, template2) ?: -1
                    result.success(score)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
