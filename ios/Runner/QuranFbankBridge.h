#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Narrow Objective-C boundary around the pinned kaldi-native-fbank library.
/// All calls must be made serially by the owning inference queue.
@interface QuranFbankExtractor : NSObject

@property(nonatomic, readonly) NSInteger featureDimension;
@property(nonatomic, readonly) NSInteger numberOfFramesReady;
@property(nonatomic, readonly) double frameShiftSeconds;

- (BOOL)acceptPCM16LEData:(NSData *)data error:(NSError **)error;
- (nullable NSData *)frameFloat32DataAtIndex:(NSInteger)index error:(NSError **)error;
- (void)finishInput;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
