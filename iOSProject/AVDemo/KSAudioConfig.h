//
//  KSAudioConfig.h
//  iOSProject
//
//  Created by 刘泽辰 on 2025/11/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KSAudioConfig : NSObject


@property (nonatomic, assign) NSUInteger channels; // 声道数 默认为2
@property (nonatomic, assign) NSUInteger sampleRate; // 采样率 默认为 44100
@property (nonatomic, assign) NSUInteger bitDepth; // 量化位深，默认为 16


+(KSAudioConfig *)defaultConfig;

@end

NS_ASSUME_NONNULL_END
