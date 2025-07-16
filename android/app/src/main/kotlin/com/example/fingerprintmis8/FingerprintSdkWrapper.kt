package com.example.fingerprintmis8

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Message
import com.fpreader.fpdevice.Constants
import com.fpreader.fpdevice.UsbReader
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class FingerprintSdkWrapper(private val activity: Activity, private val methodChannel: MethodChannel) {

    private var fpModule: UsbReader? = null
    private val isOpening = AtomicBoolean(false)
    private val isWorking = AtomicBoolean(false)

    private val bmpData = ByteArray(93238)
    private val bmpSize = IntArray(1)
    private val refData = ByteArray(512)
    private val refSize = IntArray(1)
    private val matData = ByteArray(512)
    private val matSize = IntArray(1)

    private val handler = object : Handler() {
        override fun handleMessage(msg: Message) {
            when (msg.what) {
                Constants.FPM_DEVICE -> {
                    when (msg.arg1) {
                        Constants.DEV_ATTACHED -> {
                            // Device attached
                        }
                        Constants.DEV_DETACHED -> {
                            isOpening.set(false)
                            isWorking.set(false)
                            fpModule?.CloseDevice()
                            sendStatus("Device Detached - Closed")
                        }
                        Constants.DEV_OK -> {
                            isOpening.set(true)
                            isWorking.set(false)
                            sendStatus("Open Device OK")
                        }
                        else -> {
                            sendStatus("Open Device Fail")
                        }
                    }
                }
                Constants.FPM_PLACE -> sendStatus("Place Finger")
                Constants.FPM_LIFT -> sendStatus("Lift Finger")
                Constants.FPM_CAPTURE -> {
                    if (msg.arg1 == 1) {
                        sendStatus("Capture Image OK")
                    } else {
                        sendStatus("Capture Image Fail")
                    }
                    isWorking.set(false)
                }
                Constants.FPM_GENCHAR -> {
                    if (msg.arg1 == 1) {
                        sendStatus("Generate Template OK")
                        fpModule?.GetTemplateByGen(matData, matSize)
                        val matchResult = fpModule?.MatchTemplate(refData, matData) ?: -1
                        sendStatus("Match Return: $matchResult")
                        // Send template data to Flutter
                        val templateData = matData.copyOf(matSize[0])
                        sendTemplate(templateData)
                    } else {
                        sendStatus("Generate Template Fail")
                    }
                    isWorking.set(false)
                }
                Constants.FPM_ENRFPT -> {
                    if (msg.arg1 == 1) {
                        sendStatus("Enroll Template OK")
                        fpModule?.GetTemplateByEnl(refData, refSize)
                        // Send template data to Flutter
                        val templateData = refData.copyOf(refSize[0])
                        sendTemplate(templateData)
                    } else {
                        sendStatus("Enroll Template Fail")
                    }
                    isWorking.set(false)
                }
                Constants.FPM_NEWIMAGE -> {
                    fpModule?.GetBmpImage(bmpData, bmpSize)
                    val bitmap = BitmapFactory.decodeByteArray(bmpData, 0, bmpSize[0])
                    sendImage(bitmap)
                }
                Constants.FPM_TIMEOUT -> {
                    sendStatus("Time Out")
                    isWorking.set(false)
                }
                else -> {
                    // Other messages
                }
            }
        }
    }

    init {
        fpModule = UsbReader()
        fpModule?.InitMatch()
        fpModule?.SetContextHandler(activity, handler)
    }

    fun matchTemplates(template1: ByteArray, template2: ByteArray): Int {
        if (fpModule == null) return -1
        val size1 = template1.size
        val size2 = template2.size
        val buf1 = ByteArray(512)
        val buf2 = ByteArray(512)
        System.arraycopy(template1, 0, buf1, 0, size1.coerceAtMost(512))
        System.arraycopy(template2, 0, buf2, 0, size2.coerceAtMost(512))
        return fpModule?.MatchTemplate(buf1, buf2) ?: -1
    }

    fun openDevice(): Boolean {
        if (fpModule == null) return false
        val result = fpModule!!.OpenDevice()
        if (result == 0) {
            isOpening.set(true)
            isWorking.set(false)
            sendStatus("Open Device OK")
            return true
        } else {
            fpModule!!.requestPermission()
            sendStatus("Request Permission")
            return false
        }
    }

    fun closeDevice() {
        fpModule?.CloseDevice()
        isOpening.set(false)
        isWorking.set(false)
        sendStatus("Close Device")
    }

    fun enrollTemplate() {
        if (!isOpening.get() || isWorking.get()) return
        fpModule?.EnrolTemplate()
        isWorking.set(true)
    }

    fun generateTemplate() {
        if (!isOpening.get() || isWorking.get()) return
        fpModule?.GenerateTemplate()
        isWorking.set(true)
    }

    fun pauseUnregister() {
        fpModule?.PauseUnRegister()
    }

    fun resumeRegister() {
        fpModule?.ResumeRegister()
    }

    private fun sendStatus(status: String) {
        activity.runOnUiThread {
            methodChannel.invokeMethod("onStatus", status)
        }
    }

    private fun sendImage(bitmap: Bitmap) {
        val stream = java.io.ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        val byteArray = stream.toByteArray()
        activity.runOnUiThread {
            methodChannel.invokeMethod("onImage", byteArray)
        }
    }

    private fun sendTemplate(templateData: ByteArray) {
        activity.runOnUiThread {
            methodChannel.invokeMethod("onTemplate", templateData)
        }
    }
}
