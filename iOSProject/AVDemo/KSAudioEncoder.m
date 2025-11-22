//
//  KSAudioEncoder.m
//  iOSProject
//
//  Created by 刘泽辰 on 2025/11/18.
//

#import "KSAudioEncoder.h"
#import "AudioToolbox/AudioToolbox.h"

@interface KSAudioEncoder () {
    char *_leftBuffer; // 待编码缓冲区
    NSInteger _leftLength; // 长度，动态
    char *_accBuffer; // 编码缓冲区
    NSInteger _bufferLength; // 每次送给编码器的数据商都
}

@property (nonatomic, assign) AudioConverterRef audioEncoderInstance; // 音频编码器的实例
@property (nonatomic, assign) CMFormatDescriptionRef accFormat; // 编码参数
@property (nonatomic, assign, readwrite) NSInteger audioBirate; // 音频编码码率
@property (nonatomic, assign) BOOL isError;
@property (nonatomic, strong) dispatch_queue_t encoderQueue; // 编码队列

@end

@implementation KSAudioEncoder

- (instancetype)initWithAudioBirate:(NSInteger)audioBirrate {
    self = [super init];
    if (self) {
        _audioBirate = audioBirrate;
        _encoderQueue = dispatch_queue_create("com.lzc.audioEncoder", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    if (_audioEncoderInstance) {
        AudioConverterDispose(_audioEncoderInstance);
        _audioEncoderInstance = nil;
    }
    if (_accFormat) {
        CFRelease(_accFormat);
        _accFormat = NULL;
    }
    
    if (_accBuffer) {
        free(_accBuffer);
        _accBuffer = NULL;
    }
    
    if (_leftBuffer) {
        free(_leftBuffer);
        _leftBuffer = NULL;
    }
    
}

- (void)encodeSampleBuffer:(CMSampleBufferRef)buffer {
    if (!buffer || !CMSampleBufferGetDataBuffer(buffer) || self.isError) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    CFRetain(buffer);
    dispatch_async(_encoderQueue, ^{
//        [weakSelf ]
    });
}

- (void)encodeSampleBufferInternal:(CMSampleBufferRef)buffer {
    CMAudioFormatDescriptionRef audioFormatRef = CMSampleBufferGetFormatDescription(buffer);
    if (audioFormatRef) {
        return;
    }
    AudioStreamBasicDescription audioFormat = *CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatRef);
    
    NSError *error = nil;
    if (!_audioEncoderInstance) {
        [self setupAudioEncoderInstanceWithInputAudioFormat:audioFormat error:&error];
        if (error) {
            [self errorCallBack];
        }
    }
    
    
}
 
#pragma mark - Utility

- (void)setupAudioEncoderInstanceWithInputAudioFormat:(AudioStreamBasicDescription)inputFormat error:(NSError **)error {
    AudioStreamBasicDescription outputFormat = {};
    outputFormat.mSampleRate = inputFormat.mSampleRate; // 输出采样率与输入一致
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;
    outputFormat.mChannelsPerFrame = inputFormat.mChannelsPerFrame;
    outputFormat.mFramesPerPacket = 1024; // 每个包的帧数，ACC固定是1024 ？
    outputFormat.mBytesPerPacket = 0; // 每个包的大小。动态大小设置为 0。
    outputFormat.mBytesPerFrame = 0; // 每帧的大小。压缩格式设置为 0。
    outputFormat.mBitsPerChannel = 0; // 压缩格式设置为 0。
    
    // 常见音频编码器,将左边转换成右边
    OSStatus result = AudioConverterNew(&inputFormat, &outputFormat, &_audioEncoderInstance);
    if (result != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:result userInfo:nil];
        return;
    }
    
    // 常见编码格式信息
    result = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &outputFormat, 0, NULL, 0, NULL, nil, &_accFormat);
    if (result != noErr) {
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:result userInfo:nil];
        return;
    }
    _bufferLength = 1024 * 2 * inputFormat.mChannelsPerFrame;
    if (!_leftBuffer) {
        _leftBuffer = malloc(_bufferLength * sizeof(char));
    }
    if (!_accBuffer) {
        _accBuffer = malloc(_bufferLength);
    }
    
}



@end
