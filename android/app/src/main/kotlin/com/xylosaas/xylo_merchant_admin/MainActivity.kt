package com.xylosaas.xylo_merchant_admin

import android.app.Activity
import android.content.Intent
import android.media.AudioManager
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val CHANNEL = "com.xylosaas.xylo_merchant_admin/alerts"
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var pendingImageResult: MethodChannel.Result? = null
    private val PICK_IMAGE_REQUEST_CODE = 9912

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        tts = TextToSpeech(this, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val bnResult = tts?.setLanguage(Locale("bn", "BD"))
            if (bnResult == TextToSpeech.LANG_MISSING_DATA || bnResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts?.setLanguage(Locale.US)
            }
            tts?.setPitch(1.0f)
            tts?.setSpeechRate(0.95f)
            ttsReady = true
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playAlertAndSpeak" -> {
                    val text = call.argument<String>("text") ?: "New notification received"
                    val lang = call.argument<String>("lang") ?: "bn"
                    playNotificationTone()
                    speakText(text, lang)
                    result.success(true)
                }
                "playToneOnly" -> {
                    playNotificationTone()
                    result.success(true)
                }
                "pickImage" -> {
                    if (pendingImageResult != null) {
                        result.error("ALREADY_ACTIVE", "Image picker is already open", null)
                        return@setMethodCallHandler
                    }
                    pendingImageResult = result
                    val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                        type = "image/*"
                        addCategory(Intent.CATEGORY_OPENABLE)
                    }
                    startActivityForResult(
                        Intent.createChooser(intent, "Select Image"),
                        PICK_IMAGE_REQUEST_CODE
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE_REQUEST_CODE) {
            val res = pendingImageResult
            pendingImageResult = null
            if (res == null) return

            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                try {
                    val uri: Uri = data.data!!
                    val inputStream: InputStream? = contentResolver.openInputStream(uri)
                    val buffer = ByteArrayOutputStream()
                    val dataBuf = ByteArray(8192)
                    var nRead: Int
                    if (inputStream != null) {
                        while (inputStream.read(dataBuf, 0, dataBuf.size).also { nRead = it } != -1) {
                            buffer.write(dataBuf, 0, nRead)
                        }
                        inputStream.close()
                    }
                    val bytes = buffer.toByteArray()
                    val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                    val fileName = uri.lastPathSegment?.substringAfterLast('/') ?: "picked_image.png"
                    val map = HashMap<String, String>()
                    map["base64"] = b64
                    map["name"] = fileName
                    res.success(map)
                } catch (e: Exception) {
                    res.error("READ_ERROR", e.message, null)
                }
            } else {
                res.success(null)
            }
        }
    }

    private fun playNotificationTone() {
        try {
            val notificationUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, notificationUri)
            if (ringtone != null) {
                ringtone.play()
            } else {
                val toneGen = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
                toneGen.startTone(ToneGenerator.TONE_PROP_BEEP2, 450)
            }
        } catch (_: Exception) {
            try {
                val toneGen = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
                toneGen.startTone(ToneGenerator.TONE_PROP_BEEP2, 450)
            } catch (_: Exception) {}
        }
    }

    private fun speakText(text: String, lang: String) {
        if (!ttsReady || tts == null) return
        try {
            if (lang == "bn") {
                val res = tts?.setLanguage(Locale("bn", "BD"))
                if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
                    tts?.setLanguage(Locale("bn", "IN"))
                }
            } else {
                tts?.setLanguage(Locale.US)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                tts?.speak(text, TextToSpeech.QUEUE_ADD, null, "xylo_order_tts_${System.currentTimeMillis()}")
            } else {
                @Suppress("DEPRECATION")
                tts?.speak(text, TextToSpeech.QUEUE_ADD, null)
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
}