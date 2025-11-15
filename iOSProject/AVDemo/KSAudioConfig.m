//
//  KSAudioConfig.m
//  iOSProject
//
//  Created by 刘泽辰 on 2025/11/9.
//

#import "KSAudioConfig.h"

@implementation KSAudioConfig

+(KSAudioConfig *)defaultConfig {
    KSAudioConfig *config = [[KSAudioConfig alloc] init];
    config.channels = 2;
    config.sampleRate = 44100;
    config.bitDepth = 16;
    return config;
}
@end
