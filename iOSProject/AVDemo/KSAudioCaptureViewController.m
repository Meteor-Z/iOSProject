//
//  KSAudioCaptureViewController.m
//  iOSProject
//
//  Created by 刘泽辰 on 2025/11/11.
//

#import "KSAudioCaptureViewController.h"
#import "KSAudioCapture.h"
#import "AVFoundation/AVFoundation.h"

@interface KSAudioCaptureViewController ()

@property (nonatomic, strong) KSAudioConfig *audioConfig;
@property (nonatomic, strong) KSAudioCapture *audioCapture;
@property (nonatomic, strong) NSFileHandle *fileHandle;

@end

@implementation KSAudioCaptureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupAudioSession];
    [self setupUI];
}

- (void)setupUI {
    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.title = @"Audio Capture";
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIBarButtonItem *startButton = [[UIBarButtonItem alloc] initWithTitle:@"start" style:UIBarButtonItemStylePlain target:self action:@selector(startCapturing)];
    UIBarButtonItem *stopButton = [[UIBarButtonItem alloc] initWithTitle:@"end" style:UIBarButtonItemStylePlain target:self action:@selector(stopCapturing)];
    self.navigationItem.rightBarButtonItems = @[startButton, stopButton];
}

- (void)dealloc {
    if (_fileHandle) {
        [_fileHandle closeFile];
    }
}

#pragma mark - Private Method

- (void)setupAudioSession {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    if (error) {
        NSLog(@"AVAudioSession is error");
        return;
    }
    
    [session setMode:AVAudioSessionModeVideoRecording error:&error];
    if (error) {
        NSLog(@"SetMode出错");
        return;
    }
    
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"setActive 出错");
        return;
    }
    
}


#pragma mark - Action

- (void)startCapturing {
    NSLog(@"startCapturing");
    [self.audioCapture startCapturing];
}

- (void)stopCapturing {
    NSLog(@"endCapturing");
    [self.audioCapture stopCapturing];
    if (self.fileHandle) {
        [self.fileHandle closeFile];
    }
}



#pragma mark - Lazy Load

- (KSAudioConfig *)audioConfig {
    if (!_audioConfig) {
        _audioConfig = [KSAudioConfig defaultConfig];
    }
    return _audioConfig;
}

- (KSAudioCapture *)audioCapture {
    if (!_audioCapture) {
        __weak typeof(self) weakSelf = self;
        _audioCapture = [[KSAudioCapture alloc] initWithConfig:self.audioConfig];
        _audioCapture.errorCallBack = ^(NSError * _Nonnull error) {
            NSLog(@"KFAudioCapture error:%zi %@", error.code, error.localizedDescription);
        };
        _audioCapture.sampleBufferOutputCallBack = ^(CMSampleBufferRef  _Nonnull sample) {
            if (sample) {
                // 这里是干啥的
                NSLog(@"zechen 写入文件");
                CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sample);
                size_t lengthAtOffsetOutput, totoalLengthOutput;
                char *dataPointer;
                CMBlockBufferGetDataPointer(blockBuffer, 0, &lengthAtOffsetOutput, &totoalLengthOutput, &dataPointer);
                [weakSelf.fileHandle writeData:[NSData dataWithBytes:dataPointer length:totoalLengthOutput]];
                
            }
        };
    
    }
    return _audioCapture;
}

- (NSFileHandle *)fileHandle {
    if (!_fileHandle) {
        NSError *error = nil;
        NSString *audioPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"test.pcm"];
        NSLog(@"PCM file path = %@", audioPath);
        [[NSFileManager defaultManager] removeItemAtPath:audioPath error:&error];
        if (error) {
            NSLog(@"出错");
        }
        [[NSFileManager defaultManager] createFileAtPath:audioPath contents:nil attributes:nil];
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:audioPath];
    }
    return _fileHandle;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
