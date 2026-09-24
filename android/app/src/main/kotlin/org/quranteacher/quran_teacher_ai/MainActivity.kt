package org.quranteacher.quran_teacher_ai

import android.Manifest
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audio: QuranAudioService? = null
    private var pendingPermission: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audio = QuranAudioService(flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.quranteacher/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        if (pendingPermission != null) result.error("busy", "Permission request pending", null)
                        else if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                            pendingPermission = result
                            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 7041)
                        } else startAudio(result)
                    }
                    "isSubscribed" -> result.success(audio?.hasListener == true)
                    "stop" -> {
                        pendingPermission?.error("cancelled", "Capture start cancelled", null)
                        pendingPermission = null; audio?.stop(); result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    private fun startAudio(result: MethodChannel.Result) {
        try { audio?.start() ?: error("Audio service unavailable"); result.success(null) }
        catch (e: Exception) { result.error("audio_start_failed", e.message, null) }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 7041) return
        val result = pendingPermission ?: return
        pendingPermission = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) startAudio(result)
        else result.error("microphone_denied", "Allow microphone access in Settings", null)
    }
    override fun onPause() { audio?.interrupt(); super.onPause() }
    override fun onDestroy() {
        audio?.stop(); pendingPermission?.error("disposed", "Activity destroyed", null)
        pendingPermission = null; super.onDestroy()
    }
}
