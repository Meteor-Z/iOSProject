//
//  KSAudioCapture.m
//  iOSProject
//
//  Created by 刘泽辰 on 2025/11/9.
//

#import "KSAudioCapture.h"
#import "mach/mach_time.h"
#import "AudioUnit/AudioComponent.h"
#import "AudioUnit/AudioUnit.h"
#import "CoreAudioTypes/CoreAudioTypes.h"
#import "AVFoundation/AVFoundation.h"
#import "memory.h"

#define kInputBus 1
#define kOutputBus 0

@interface KSAudioCapture ()

@property (nonatomic, assign) AudioComponentInstance audioCaptureInstace; // 音频采集的实例
@property (nonatomic, assign) AudioStreamBasicDescription audioFormat; // 音频采集参数
@property (nonatomic, strong) KSAudioConfig *config;
@property (nonatomic, strong) dispatch_queue_t captureQueue; // 队列
@property (nonatomic, assign) BOOL isError;

@property (nonatomic, assign) AudioBufferList *inputBufferList; // bufferList

@end


@implementation KSAudioCapture

- (instancetype)initWithConfig:(KSAudioConfig *)config {
    self = [super init];
    if (self) {
        self.config = config;
        self.captureQueue = dispatch_queue_create("com.qq.audioCapture", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    if (self.audioCaptureInstace) {
        AudioOutputUnitStop(self.audioCaptureInstace);
        AudioComponentInstanceDispose(self.audioCaptureInstace);
        self.audioCaptureInstace = nil;
    }
}

- (void)startCapturing {
    if (self.isError) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.captureQueue, ^{
        if (!weakSelf.audioCaptureInstace) {
            NSError *error = nil;
            [weakSelf setupAudioCaptureInstace:&error];
            if (error) {
                [weakSelf callBackError:error];
                NSLog(@"出错");
                return;
            }
        }
        
        // 开始采集
        OSStatus startStatus = AudioOutputUnitStart(weakSelf.audioCaptureInstace);
        if (startStatus != noErr) {
            [weakSelf callBackError:[NSError errorWithDomain:NSStringFromClass(self.class) code:startStatus userInfo:nil]];
            
        }
    });
}

- (void)stopCapturing {
    if (self.isError) {
        NSLog(@"stopCapturing error, 出错");
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(_captureQueue, ^{
        if (weakSelf.audioCaptureInstace) {
            // 停止采集
            OSStatus stopStatus = AudioOutputUnitStop(weakSelf.audioCaptureInstace);
            if (stopStatus != noErr) {
                [weakSelf callBackError:[NSError errorWithDomain:NSStringFromClass(self.class) code:stopStatus userInfo:nil]];
            }
        }
    });
}

- (void)callBackError:(NSError *)error {
    self.isError = YES;
    if (error && self.errorCallBack) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.errorCallBack(error);
        });
    }
}

#pragma mark - 工具类

- (void)setupAudioCaptureInstace:(NSError **)error {
    // 找对应的AudioUnit
    AudioComponentDescription ioUnitDescription;
    ioUnitDescription.componentType = kAudioUnitType_Output;
    ioUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    ioUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioUnitDescription.componentFlags = 0;
    ioUnitDescription.componentFlagsMask = 0;
    
    // 查找符合要求的音频组件
    AudioComponent component = AudioComponentFindNext(nil, &ioUnitDescription);
    OSStatus status = AudioComponentInstanceNew(component, &_audioCaptureInstace);
    if (status != noErr) {
        // 这里的dorman是什么意思
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        NSLog(@"查询符合要求的音频组件出错");
        return;
    }
    
    // 打开开关
    UInt32 flagOne = 1;
    status = AudioUnitSetProperty(_audioCaptureInstace,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  kInputBus,
                                  &flagOne,
                                  sizeof(flagOne));
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        NSLog(@"这里哈哈哈哈哈");
        return;
    }

    status = AudioUnitSetProperty(_audioCaptureInstace,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  kOutputBus,
                                  &flagOne,
                                  sizeof(flagOne));
    
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        NSLog(@"寄了");
        return;
    }

    AudioStreamBasicDescription asbd = {0};
    asbd.mFormatID = kAudioFormatLinearPCM; // 原始数据为PCM，采用声道交错格式
    asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    asbd.mChannelsPerFrame = (UInt32)self.config.channels;
    asbd.mFramesPerPacket = 1; // 每个数据包 帧数
    asbd.mBitsPerChannel = (UInt32)self.config.bitDepth;
    asbd.mBytesPerFrame = asbd.mChannelsPerFrame * asbd.mBitsPerChannel / 8;
    asbd.mBytesPerPacket = asbd.mFramesPerPacket * asbd.mBytesPerFrame; // 每个包字节数
    asbd.mSampleRate = self.config.sampleRate;
    self.audioFormat = asbd;

    
    // 设置扬声器，采集回来的数据的声音
    status = AudioUnitSetProperty(_audioCaptureInstace,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  1,
                                  &asbd,
                                  sizeof(asbd));

    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        NSLog(@"设置出错");
        return;
    }
    
    AURenderCallbackStruct callBack;
    callBack.inputProcRefCon = (__bridge void *)self;
    callBack.inputProc = audioBufferCallBack;
    
    
    // 设置callback
    status = AudioUnitSetProperty(_audioCaptureInstace,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &callBack,
                                  sizeof(callBack));
    
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        NSLog(@"不中");
        return;
    }
    
    
    // 设置输出回调
    AURenderCallbackStruct renderCallBack;
    renderCallBack.inputProc = audioRenderCallback;
    renderCallBack.inputProcRefCon = (__bridge void *)self;
    
    status = AudioUnitSetProperty(_audioCaptureInstace,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,    // 注意：Input scope for output bus
                                  kOutputBus,
                                  &renderCallBack,
                                  sizeof(renderCallBack));
    
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        NSLog(@"这里出错");
        return;
    }
    
    
    status = AudioUnitInitialize(_audioCaptureInstace);
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        NSLog(@"寄了");
        return;
    }
    
}

#pragma mark - Capture CallBack

static OSStatus audioBufferCallBack(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData) {
    @autoreleasepool {
        KSAudioCapture *capture = (__bridge KSAudioCapture *)inRefCon;
        if (!capture) {
            return -1;
        }
        
        AudioBuffer buffer;
        
        buffer.mNumberChannels = 1;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        
        UInt32 bufferSize = inNumberFrames * capture.audioFormat.mBytesPerFrame;
        void *data = malloc(bufferSize);
        
        AudioBufferList bufferList;
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0].mNumberChannels = capture.audioFormat.mChannelsPerFrame;
        bufferList.mBuffers[0].mData = data;
        bufferList.mBuffers[0].mDataByteSize = bufferSize;
        
        OSStatus stats = AudioUnitRender(capture.audioCaptureInstace,
                                         ioActionFlags,
                                         inTimeStamp,
                                         inBusNumber,
                                         inNumberFrames,
                                         &bufferList);
        if (stats == noErr) {
            
            NSLog(@"zechen 输入相关的 =%p", capture.inputBufferList);
            if (!capture.inputBufferList) {
                capture.inputBufferList = malloc(sizeof(AudioBufferList));
                capture.inputBufferList->mNumberBuffers = 1;
                capture.inputBufferList->mBuffers[0].mNumberChannels = capture.audioFormat.mChannelsPerFrame;
                capture.inputBufferList->mBuffers[0].mData = malloc(bufferSize);
                NSLog(@"mnumberBuffers =  %@", @(capture.inputBufferList->mNumberBuffers));
            }
            
            if (bufferList.mBuffers[0].mData) {
                NSLog(@"有数据");
            }
            memcpy(capture.inputBufferList->mBuffers[0].mData,
                          bufferList.mBuffers[0].mData,
                   bufferSize);
            
            CMSampleBufferRef sampleBuffer = [KSAudioCapture sampleBufferFromAudioBufferList:bufferList
                                                                                 inTimeStamp:inTimeStamp inNumberFrames:inNumberFrames description:capture.audioFormat];
            if (capture.sampleBufferOutputCallBack) {
                capture.sampleBufferOutputCallBack(sampleBuffer);
            }
            if (sampleBuffer) {
                CFRelease(sampleBuffer);
            }
        }
        
        return stats;
        
    }
    
}

static OSStatus audioRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData) {
    NSLog(@"inBusNumber = %@", @(inBusNumber));
    KSAudioCapture *capture = (__bridge KSAudioCapture *)inRefCon;
    if (!capture) {
        return -1;
    }
    
    if (!capture.inputBufferList || capture.inputBufferList->mBuffers[0].mDataByteSize == 0) {
        // 清空输出
        for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
            memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
            ioData->mBuffers[i].mDataByteSize = 0;
        }
        NSLog(@"寄了");
        return -1;
    }
    NSLog(@"RenderCallBack");
    UInt32 copyBytes = MIN(ioData->mBuffers[0].mDataByteSize, capture.inputBufferList->mBuffers[0].mDataByteSize);
    memcpy(ioData->mBuffers[0].mData, capture.inputBufferList->mBuffers[0].mData, copyBytes);;
    ioData->mBuffers[0].mDataByteSize = copyBytes;;
    
    capture.inputBufferList = nil;
    return noErr;
    
}


#pragma mark - 工具类

+ (CMSampleBufferRef)sampleBufferFromAudioBufferList:(AudioBufferList)buffers inTimeStamp:(const AudioTimeStamp *)inTimeStamp inNumberFrames:(UInt32)inNumberFrames description:(AudioStreamBasicDescription)description {
    CMSampleBufferRef sampleBuffer = NULL; // 待生成的 CMSampleBuffer 实例的引用。
       // 1、创建音频流的格式描述信息。
    CMFormatDescriptionRef format = NULL;
    OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &description, 0, NULL, 0, NULL, NULL, &format);
    if (status != noErr) {
        CFRelease(format);
        return nil;
    }
    
    mach_timebase_info_data_t info = {0, 0};
    mach_timebase_info(&info);
    uint64_t time = inTimeStamp->mHostTime;
    
    // 转换成纳秒 ？
    time *= info.numer;
    time /= info.denom;
    
    CMTime presentationTime = CMTimeMake(time, 1000000000.0f);
    CMSampleTimingInfo timing = {CMTimeMake(1, description.mSampleRate), presentationTime, presentationTime};
    
    // CMSampleBuffer实例
    status = CMSampleBufferCreate(kCFAllocatorDefault, NULL, false, NULL, NULL, format, (CMItemCount) inNumberFrames, 1, &timing, 0, NULL, &sampleBuffer);
    if (status != noErr) {
        CFRelease(format);
        return nil;
    }
    status = CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer, kCFAllocatorDefault, kCFAllocatorDefault, 0, &buffers);
    if (status != noErr) {
        CFRelease(format);
        return nil;
    }
    CFRelease(format);
    return sampleBuffer;
    
}



@end
