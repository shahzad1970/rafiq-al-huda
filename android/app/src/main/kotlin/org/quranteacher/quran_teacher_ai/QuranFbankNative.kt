package org.quranteacher.quran_teacher_ai

/** Exact pinned kaldi-native-fbank frontend used by the Quran-Lab model. */
class QuranFbankNative : AutoCloseable {
    private var handle = nativeCreate()

    init { check(handle != 0L) { "Could not create Quran fbank extractor" } }

    fun accept(pcm: ShortArray) { check(handle != 0L); nativeAccept(handle, pcm) }
    val numFramesReady: Int get() { check(handle != 0L); return nativeNumFrames(handle) }
    fun frame(index: Int): FloatArray = nativeGetFrame(handle, index)
        ?: error("Fbank frame $index is unavailable")
    fun finish() { check(handle != 0L); nativeFinish(handle) }
    fun reset() { check(handle != 0L); nativeReset(handle) }

    override fun close() {
        if (handle != 0L) nativeDestroy(handle)
        handle = 0
    }

    private external fun nativeCreate(): Long
    private external fun nativeAccept(handle: Long, pcm: ShortArray)
    private external fun nativeNumFrames(handle: Long): Int
    private external fun nativeGetFrame(handle: Long, index: Int): FloatArray?
    private external fun nativeFinish(handle: Long)
    private external fun nativeReset(handle: Long)
    private external fun nativeDestroy(handle: Long)

    companion object { init { System.loadLibrary("quran_fbank") } }
}
