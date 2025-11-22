//
//  KSAudioEncoder.h
//  iOSProject
//
//  Created by 刘泽辰 on 2025/11/18.
//

#import <Foundation/Foundation.h>
#import "CoreMedia/CoreMedia.h"

NS_ASSUME_NONNULL_BEGIN

@interface KSAudioEncoder : NSObject

@property (nonatomic, assign, readonly) NSInteger audioBirate; // 音频编码码率
@property (nonatomic, copy) void (^sampleBufferOutputCallBack)(CMSampleBufferRef sample); // 音频编码回调
@property (nonatomic, copy) void (^errorCallBack)(NSError *error); // 音频编码错误回调。

- (instancetype)initWithAudioBirate:(NSInteger)audioBirrate;
- (void)encodeSampleBuffer:(CMSampleBufferRef)buffer; // 编码

@end

NS_ASSUME_NONNULL_END
