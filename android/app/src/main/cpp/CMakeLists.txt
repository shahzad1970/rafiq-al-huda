cmake_minimum_required(VERSION 3.22.1)
project(quran_fbank)

set(ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../..)
set(KNF ${ROOT}/third_party/kaldi-native-fbank/kaldi-native-fbank/csrc)
set(KISS ${ROOT}/third_party/kissfft)

add_library(quran_fbank SHARED
  quran_fbank_jni.cc
  ${KNF}/feature-fbank.cc
  ${KNF}/feature-functions.cc
  ${KNF}/feature-mfcc.cc
  ${KNF}/feature-raw-audio-samples.cc
  ${KNF}/feature-window.cc
  ${KNF}/istft.cc
  ${KNF}/kaldi-math.cc
  ${KNF}/mel-computations.cc
  ${KNF}/online-feature.cc
  ${KNF}/rfft.cc
  ${KNF}/stft.cc
  ${KNF}/whisper-feature.cc
  ${KISS}/kiss_fft.c
  ${KISS}/kiss_fftr.c
)

target_include_directories(quran_fbank PRIVATE
  ${ROOT}/third_party/kaldi-native-fbank
  ${KISS}
)

find_library(log-lib log)
target_link_libraries(quran_fbank ${log-lib})
