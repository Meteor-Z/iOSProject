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
                                  1,
                                  &flagOne,
                                  sizeof(flagOne));
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        NSLog(@"打开音频输入");
        return;
    }

    status = AudioUnitSetProperty(_audioCaptureInstace,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  0,
                                  &flagOne,
                                  sizeof(flagOne));
    
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        NSLog(@"打开音频输入");
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
    
    UInt32 maxFrams = 2048;
    self.inputBufferList = [self createAudioBufferListWithFrameCount:maxFrams];
    
    // 设置callback
    status = AudioUnitSetProperty(_audioCaptureInstace,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global, 1,
                                  &callBack,
                                  sizeof(callBack));
    
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        return;
    }
    status = AudioUnitInitialize(_audioCaptureInstace);
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
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
            return - 1;
        }
        if (ioData == NULL) {
            return -1;
        }
        UInt32 neededBytes = inNumberFrames * capture.audioFormat.mBytesPerFrame;
        if (capture.inputBufferList->mBuffers[0].mDataByteSize < neededBytes) {
            [capture freeAudioBufferList:capture.inputBufferList];
            capture.inputBufferList = [capture createAudioBufferListWithFrameCount:inNumberFrames];
        }
        // 从麦克风中获取数据
        OSStatus status = AudioUnitRender(capture.audioCaptureInstace,
                                          ioActionFlags,
                                          inTimeStamp,
                                          1, // 从麦克风输入 bus 1 取数据
                                          inNumberFrames,
                                          capture.inputBufferList);
        if (status != noErr) {
            for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
                memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
            }
            return status;
        }

            // 2. 做耳返（input → output）
        UInt32 inBufs  = capture.inputBufferList->mNumberBuffers;
        UInt32 outBufs = ioData->mNumberBuffers;

        UInt32 copyBufs = MIN(inBufs, outBufs);

        for (UInt32 i = 0; i < copyBufs; i++) {
            
            void *inPtr = capture.inputBufferList->mBuffers[i].mData;
            void *outPtr = ioData->mBuffers[i].mData;
            
            UInt32 inSize  = capture.inputBufferList->mBuffers[i].mDataByteSize;
            UInt32 outSize = ioData->mBuffers[i].mDataByteSize;
            
            if (!inPtr || !outPtr || inSize == 0 || outSize == 0) {
                continue;
            }
            
            UInt32 copySize = MIN(inSize, outSize);
            memcpy(outPtr, inPtr, copySize);
        }
        
        if (capture.sampleBufferOutputCallBack) {
            CMSampleBufferRef sampleBuffer = [KSAudioCapture sampleBufferFromAudioBufferList:*capture.inputBufferList
                                                                                 inTimeStamp:inTimeStamp
                                                                              inNumberFrames:inNumberFrames
                                                                                 description:capture.audioFormat];
            if (sampleBuffer) {
                capture.sampleBufferOutputCallBack(sampleBuffer);
                CFRelease(sampleBuffer);
            }
        }
    }
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

- (AudioBufferList *)createAudioBufferListWithFrameCount:(UInt32)inNumberFrames {
    UInt32 bytesPerFrame = (self.audioFormat.mBitsPerChannel / 8) * self.audioFormat.mChannelsPerFrame;
    UInt32 bufferBytesSize = inNumberFrames * bytesPerFrame;
    
    AudioBufferList *abl = (AudioBufferList *)malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer) * (1 - 1));
    abl->mNumberBuffers = 1;
    abl->mBuffers[0].mNumberChannels = self.audioFormat.mChannelsPerFrame;
    abl->mBuffers[0].mDataByteSize = bufferBytesSize;
    abl->mBuffers[0].mData = malloc(bufferBytesSize);
    return abl;
}

- (void)freeAudioBufferList:(AudioBufferList *)abl {
    if (!abl) {
        return;
    }
    if (abl->mNumberBuffers >0 && abl->mBuffers[0].mData) {
        free(abl->mBuffers[0].mData);
    }
    free(abl);
    
    
}

@end
