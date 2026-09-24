package org.quranteacher.quran_teacher_ai

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.os.Process
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicInteger

/** Real microphone PCM only. No recognition or substitute fbank. */
class QuranAudioService(messenger: BinaryMessenger) : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private val pending = AtomicInteger(0)
    private var sink: EventChannel.EventSink? = null
    val hasListener: Boolean get() = sink != null
    @Volatile private var recorder: AudioRecord? = null
    @Volatile private var generation = 0
    private var worker: Thread? = null
    init { EventChannel(messenger, "org.quranteacher/audio/events").setStreamHandler(this) }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { stop(); sink = null }
    @Suppress("MissingPermission")
    fun start() {
        check(sink != null) { "Subscribe to audio events first" }
        if (recorder != null) return
        val minimum = AudioRecord.getMinBufferSize(16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        check(minimum > 0) { "16 kHz mono PCM16 unsupported" }
        val device = AudioRecord.Builder().setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
            .setAudioFormat(AudioFormat.Builder().setSampleRate(16000)
                .setChannelMask(AudioFormat.CHANNEL_IN_MONO).setEncoding(AudioFormat.ENCODING_PCM_16BIT).build())
            .setBufferSizeInBytes(maxOf(minimum * 4, 12800)).build()
        try {
            check(device.state == AudioRecord.STATE_INITIALIZED && device.sampleRate == 16000 && device.channelCount == 1)
            device.startRecording(); check(device.recordingState == AudioRecord.RECORDSTATE_RECORDING)
        } catch (e: Exception) { device.release(); throw e }
        generation += 1; val token = generation; recorder = device
        worker = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
            val samples = ShortArray(1600)
            var sequence = 0; var offset = 0L
            while (generation == token) {
                val count = device.read(samples, 0, samples.size, AudioRecord.READ_BLOCKING)
                if (generation != token) break
                if (count < 0) { fail(token, "audio_read_failed", "AudioRecord error $count"); break }
                if (count == 0) continue
                if (pending.incrementAndGet() > 8) {
                    pending.decrementAndGet(); fail(token, "audio_overrun", "Audio delivery overflow; restart capture"); break
                }
                val bytes = ByteBuffer.allocate(count*2).order(ByteOrder.LITTLE_ENDIAN)
                for (i in 0 until count) bytes.putShort(samples[i])
                val event = mapOf("pcm" to bytes.array(), "sampleRate" to 16000,
                    "inputSampleRate" to device.sampleRate.toDouble(), "channels" to 1,
                    "encoding" to "pcm16le", "sequence" to sequence++, "startSample" to offset)
                offset += count
                main.post {
                    try { if (generation == token) sink?.success(event) }
                    finally { pending.decrementAndGet() }
                }
            }
        }, "QuranAudioCapture").also { it.start() }
    }
    private fun fail(token: Int, code: String, message: String) {
        main.post { if (generation == token) { stop(); sink?.error(code, message, null) } }
    }
    fun interrupt() {
        if (recorder != null) { stop(); sink?.error("capture_interrupted", "App left foreground; capture stopped", null) }
    }
    fun stop() {
        generation += 1
        val device = recorder; recorder = null
        try { device?.stop() } catch (_: IllegalStateException) { }
        worker?.join(1000)
        if (worker?.isAlive == true) {
            val thread = worker
            Thread { thread?.join(); device?.release() }.start()
        } else device?.release()
        worker = null
    }
}
