//
//  KSAudioCapture.h
//  iOSProject
//
//  Created by 刘泽辰 on 2025/11/9.
//

#import <Foundation/Foundation.h>
#import "CoreMedia/CoreMedia.h"
#import "KSAudioConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface KSAudioCapture : NSObject

@property (nonatomic, strong, readonly) KSAudioConfig *config;
@property (nonatomic, copy) void (^sampleBufferOutputCallBack)(CMSampleBufferRef sample); // 音频采集
@property (nonatomic, copy) void (^errorCallBack)(NSError *error); // 音频采集错误回调


- (instancetype)initWithConfig:(KSAudioConfig *)config;
- (void)startCapturing;
- (void)stopCapturing;

@end

NS_ASSUME_NONNULL_END
