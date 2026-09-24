#include <jni.h>

#include <cstdint>
#include <memory>
#include <vector>

#include "kaldi-native-fbank/csrc/online-feature.h"

namespace {
constexpr float kSampleRate = 16000.0f;
constexpr int32_t kFeatureDimension = 80;

struct Extractor {
  Extractor() { Reset(); }

  void Reset() {
    knf::FbankOptions options;
    options.frame_opts.samp_freq = kSampleRate;
    options.frame_opts.dither = 0.0f;
    options.frame_opts.snip_edges = false;
    options.frame_opts.window_type = "povey";
    options.mel_opts.num_bins = kFeatureDimension;
    options.mel_opts.high_freq = -400.0f;
    fbank = std::make_unique<knf::OnlineFbank>(options);
  }

  std::unique_ptr<knf::OnlineFbank> fbank;
};

Extractor* FromHandle(jlong handle) {
  return reinterpret_cast<Extractor*>(handle);
}
}  // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_org_quranteacher_quran_1teacher_1ai_QuranFbankNative_nativeCreate(
    JNIEnv*, jobject) {
  return reinterpret_cast<jlong>(new Extractor());
}

extern "C" JNIEXPORT void JNICALL
Java_org_quranteacher_quran_1teacher_1ai_QuranFbankNative_nativeAccept(
    JNIEnv* env, jobject, jlong handle, jshortArray pcm) {
  auto* extractor = FromHandle(handle);
  if (!extractor || !pcm) return;
  const jsize count = env->GetArrayLength(pcm);
  jshort* input = env->GetShortArrayElements(pcm, nullptr);
  std::vector<float> samples(count);
  for (jsize i = 0; i < count; ++i) {
    samples[i] = static_cast<float>(input[i]) / 32768.0f;
  }
  env->ReleaseShortArrayElements(pcm, input, JNI_ABORT);
  if (!samples.empty()) {
    extractor->fbank->AcceptWaveform(kSampleRate, samples.data(), count);
  }
}

extern "C" JNIEXPORT jint JNICALL
Java_org_quranteacher_quran_1teacher_1ai_QuranFbankNative_nativeNumFrames(
    JNIEnv*, jobject, jlong handle) {
  auto* extractor = FromHandle(handle);
  return extractor ? extractor->fbank->NumFramesReady() : 0;
}

extern "C" JNIEXPORT jfloatArray JNICALL
Java_org_quranteacher_quran_1teacher_1ai_QuranFbankNative_nativeGetFrame(
    JNIEnv* env, jobject, jlong handle, jint index) {
  auto* extractor = FromHandle(handle);
  if (!extractor || index < 0 || index >= extractor->fbank->NumFramesReady()) {
    return nullptr;
  }
  const float* frame = extractor->fbank->GetFrame(index);
  jfloatArray output = env->NewFloatArray(kFeatureDimension);
  env->SetFloatArrayRegion(output, 0, kFeatureDimension, frame);
  return output;
}

extern "C" JNIEXPORT void JNICALL
Java_org_quranteacher_quran_1teacher_1ai_QuranFbankNative_nativeFinish(
    JNIEnv*, jobject, jlong handle) {
  auto* extractor = FromHandle(handle);
  if (extractor) extractor->fbank->InputFinished();
}

extern "C" JNIEXPORT void JNICALL
Java_org_quranteacher_quran_1teacher_1ai_QuranFbankNative_nativeReset(
    JNIEnv*, jobject, jlong handle) {
  auto* extractor = FromHandle(handle);
  if (extractor) extractor->Reset();
}

extern "C" JNIEXPORT void JNICALL
Java_org_quranteacher_quran_1teacher_1ai_QuranFbankNative_nativeDestroy(
    JNIEnv*, jobject, jlong handle) {
  delete FromHandle(handle);
}
