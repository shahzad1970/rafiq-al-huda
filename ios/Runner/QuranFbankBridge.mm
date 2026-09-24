#import "QuranFbankBridge.h"

#include <cstdint>
#include <memory>
#include <vector>

#include "kaldi-native-fbank/csrc/online-feature.h"

namespace {
constexpr float kSampleRate = 16000.0f;
constexpr int32_t kFeatureDimension = 80;

std::unique_ptr<knf::OnlineFbank> MakeFbank() {
  knf::FbankOptions options;
  options.frame_opts.samp_freq = kSampleRate;
  options.frame_opts.dither = 0.0f;
  options.frame_opts.snip_edges = false;
  options.frame_opts.window_type = "povey";
  options.mel_opts.num_bins = kFeatureDimension;
  options.mel_opts.high_freq = -400.0f;
  return std::make_unique<knf::OnlineFbank>(options);
}

NSError *BridgeError(NSString *message) {
  return [NSError errorWithDomain:@"QuranFbank" code:1
                         userInfo:@{NSLocalizedDescriptionKey: message}];
}
}  // namespace

@implementation QuranFbankExtractor {
  std::unique_ptr<knf::OnlineFbank> _fbank;
  NSInteger _firstAvailableFrame;
}

- (instancetype)init {
  self = [super init];
  if (self) { _fbank = MakeFbank(); }
  return self;
}

- (NSInteger)featureDimension { return kFeatureDimension; }
- (NSInteger)numberOfFramesReady { return _fbank->NumFramesReady(); }
- (double)frameShiftSeconds { return _fbank->FrameShiftInSeconds(); }

- (BOOL)acceptPCM16LEData:(NSData *)data error:(NSError **)error {
  if (data.length % sizeof(int16_t) != 0) {
    if (error) { *error = BridgeError(@"PCM16 byte count must be even."); }
    return NO;
  }
  const NSUInteger count = data.length / sizeof(int16_t);
  const uint8_t *bytes = static_cast<const uint8_t *>(data.bytes);
  std::vector<float> samples(count);
  for (NSUInteger i = 0; i < count; ++i) {
    const uint16_t bits = static_cast<uint16_t>(bytes[i * 2]) |
      (static_cast<uint16_t>(bytes[i * 2 + 1]) << 8);
    samples[i] = static_cast<float>(static_cast<int16_t>(bits)) / 32768.0f;
  }
  if (!samples.empty()) {
    _fbank->AcceptWaveform(kSampleRate, samples.data(), static_cast<int32_t>(samples.size()));
  }
  return YES;
}

- (NSData *)frameFloat32DataAtIndex:(NSInteger)index error:(NSError **)error {
  if (index < _firstAvailableFrame || index >= _fbank->NumFramesReady()) {
    if (error) { *error = BridgeError(@"Requested fbank frame is not ready."); }
    return nil;
  }
  const float *frame = _fbank->GetFrame(static_cast<int32_t>(index));
  NSData *copy = [NSData dataWithBytes:frame length:sizeof(float) * kFeatureDimension];
  // Swift consumes frames in order. Keep absolute frame numbering while
  // recycling features immediately; the extractor retains waveform overlap.
  _fbank->Pop(static_cast<int32_t>(index - _firstAvailableFrame + 1));
  _firstAvailableFrame = index + 1;
  return copy;
}

- (void)finishInput { _fbank->InputFinished(); }
- (void)reset { _fbank = MakeFbank(); _firstAvailableFrame = 0; }

@end
