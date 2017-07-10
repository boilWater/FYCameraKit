//
//  FYViewController.m
//  FYCameraKit
//
//  Created by boilwater on 06/23/2017.
//  Copyright (c) 2017 boilwater. All rights reserved.
//

#import "FYViewController.h"
#import "FYCameraKit-PrefixHeader.pch"
#import "FYPreviewView.h"
#import "FYAlertController.h"
#import "FYCameraKitPhotoCaptureDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

static void * SessionRunningContext = &SessionRunningContext;

typedef NS_ENUM(NSInteger, FYCameraCaptureSetupResult) {
    FYCameraCaptureSetupResultSuccess,
    FYCameraCaptureSetupResultNotAuthorized,
    FYCameraCaptureSetupResultSessionConfigurationFailed
};

typedef NS_ENUM(NSInteger, FYCameraLivePhotoMode) {
    FYCameraLivePhotoModeOff = 0,
    FYCameraLivePhotoModeOn = 1
};

typedef NS_ENUM(NSInteger, FYCameraCaptureMode) {
    FYCameraCaptureModePhoto = 0,
    FYCameraCaptureModeMovie = 1
};

typedef NS_ENUM(NSInteger, FYCameraRecordMode) {
    FYCameraRecordModeNot,
    FYCameraRecordModeStarted,
    FYCameraRecordModeStoped
};

@interface AVCaptureDeviceDiscoverySession (Utilities)

- (NSInteger)uniqueDevicePositionsCount;

@end

@implementation AVCaptureDeviceDiscoverySession (Utilities)

- (NSInteger)uniqueDevicePositionsCount {
    NSMutableArray<NSNumber *> *uniqueDevicePositions = [NSMutableArray array];
    for (AVCaptureDevice *device in self.devices) {
        if (![uniqueDevicePositions containsObject:@(device.position)]) {
            [uniqueDevicePositions addObject:@(device.position)];
        }
    }
    return uniqueDevicePositions.count;
}

@end

@interface FYViewController ()<AVCaptureFileOutputRecordingDelegate>

//session
@property(nonatomic) FYPreviewView *previewView;
@property(nonatomic, strong) UISegmentedControl *captureModeControl;
@property(nonatomic, assign) FYCameraCaptureMode captureMode;

@property(nonatomic) FYCameraCaptureSetupResult setupResult;
@property(nonatomic) dispatch_queue_t sessionQueue;
@property(nonatomic) AVCaptureSession *session;
@property(nonatomic, getter=isSessionRunning) BOOL sessionRunning;
@property(nonatomic) AVCaptureDeviceInput *videoDeviceInput;

//device
@property(nonatomic, strong) UIButton *cameraButton;
@property(nonatomic, strong) UILabel *cameraUnavailableLabel;
@property(nonatomic) AVCaptureDeviceDiscoverySession *videoDeviceDiscoverySession;

//capturing photos
@property(nonatomic, strong) UIButton *photoButton; //take photo
@property(nonatomic, strong) UIButton *livePhotoModeButton;
@property(nonatomic, strong) UIView *focusView; //point of camera
@property(nonatomic, strong) UILabel *capturingLivePhotoLabel;
@property(nonatomic) FYCameraLivePhotoMode livePhotoMode;
@property(nonatomic) FYCameraRecordMode recordMode;

@property(nonatomic) AVCapturePhotoOutput *photoOutput;
@property(nonatomic) NSMutableDictionary<NSNumber *, FYCameraKitPhotoCaptureDelegate *> *inProgressPhotoCaptureDelegate;
@property(nonatomic) NSInteger inProgressPhotoCaptureCount;

//recoding movies
@property(nonatomic, strong) UIButton *recordButton;
@property(nonatomic, strong) UIButton *resumeButton;

@property(nonatomic) AVCaptureMovieFileOutput *moviceFileOutput;
@property(nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;

@end

@implementation FYViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initHierarchy];
    [self initParameters];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    dispatch_async(self.sessionQueue, ^{
        switch (self.setupResult) {
            case FYCameraCaptureSetupResultSuccess:
            {
                [self addObserver];
                [self.session startRunning];
                self.sessionRunning = self.session.running;
                break;
            }
            case FYCameraCaptureSetupResultNotAuthorized:
            {
                FYAlertController *alertController = [FYAlertController alertControllerWithTitle:@"Error" message:@"Session Not Authorized" preferredStyle:UIAlertControllerStyleAlert cancelActionTitle:@"cancel"];
                [self presentViewController:alertController animated:YES completion:nil];
                break;
            }
            case FYCameraCaptureSetupResultSessionConfigurationFailed:
            {
                FYAlertController *alertController = [FYAlertController alertControllerWithTitle:@"Error" message:@"Session Not Authorized" preferredStyle:UIAlertControllerStyleAlert cancleActionTitle:@"cancel" settingActionTitle:@"setting"];
                [self presentViewController:alertController animated:YES completion:nil];
                break;
            }
            default:
                break;
        }
        
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    dispatch_async(self.sessionQueue, ^{
        if (FYCameraCaptureSetupResultSuccess == self.setupResult) {
            [self.session stopRunning];
            [self removeObservers];
        }
    });
    [super viewDidDisappear:animated];
}

- (void)dealloc {
    NSLog(@"dealloc : %p", __func__);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - privated Method
#pragma mark -initHierarchy

- (void)initHierarchy {
    self.view.backgroundColor = [UIColor yellowColor];
    [self.view addSubview:self.previewView];
    [self.view addSubview:self.livePhotoModeButton];
    [self.view addSubview:self.capturingLivePhotoLabel];
    [self.view addSubview:self.captureModeControl];
    [self.view addSubview:self.recordButton];
    [self.view addSubview:self.photoButton];
    [self.view addSubview:self.cameraButton];
}

#pragma mark -initParameters

- (void)initParameters {
    self.livePhotoModeButton.enabled = NO;
    self.recordButton.enabled = NO;
    self.photoButton.enabled = NO;
    self.cameraButton.enabled = NO;
    
    self.session = [[AVCaptureSession alloc] init];
    
    NSArray<AVCaptureDeviceType> *deviceType = @[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDualCamera];
    self.videoDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceType mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
    
    self.previewView.session = self.session;
    NSString *charStr = [NSString stringWithFormat:@"FYCameraKitQueue.isSolutionIn%@Class",NSStringFromClass([self class])];
    self.sessionQueue = dispatch_queue_create([charStr UTF8String], DISPATCH_QUEUE_SERIAL);
    
    self.setupResult = FYCameraCaptureSetupResultSuccess;
    
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized:
        {
            
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            dispatch_suspend(self.sessionQueue);
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (!granted) {
                    self.setupResult = FYCameraCaptureSetupResultNotAuthorized;
                }
                dispatch_resume(self.sessionQueue);
            }];
            break;
        }
        default:
        {
            self.setupResult = FYCameraCaptureSetupResultNotAuthorized;
            break;
        }
    }
    //在线程中初始化 AVCaptureSession 中的 Call Blocks 会花费时间
    dispatch_async(self.sessionQueue, ^{
        [self configurationSession];
    });
}

- (void)configurationSession {
    if (FYCameraCaptureSetupResultSuccess != self.setupResult) {
        return;
    }
    
    [self.session beginConfiguration];
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;
    
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDualCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    if (!videoDevice) {
        videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
        
        if (!videoDevice) {
            videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        }
    }
    
    NSError *error = nil;
    
    //add video device input
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (!videoDeviceInput) {
        NSLog(@"error : ");
        self.setupResult = FYCameraCaptureSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    
    if ([self.session canAddInput:videoDeviceInput]) {
        [self.session addInput: videoDeviceInput];
        self.videoDeviceInput = videoDeviceInput;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIInterfaceOrientation statusBarOrientaion = [UIApplication sharedApplication].statusBarOrientation;
            AVCaptureVideoOrientation videoOrientation = AVCaptureVideoOrientationPortrait;
            if (UIInterfaceOrientationUnknown != statusBarOrientaion) {
                videoOrientation = (AVCaptureVideoOrientation)statusBarOrientaion;
            }
            self.previewView.videoPreviewLayer.connection.videoOrientation = videoOrientation;
        });
    }else {
        NSLog(@"error : ");
        self.setupResult = FYCameraCaptureSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    
    //add audio device input
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (!audioDeviceInput) {
        NSLog(@"error : ");
    }
    if ([self.session canAddInput:audioDeviceInput]) {
        [self.session addInput:audioDeviceInput];
    }
    
    //add photo output
    AVCapturePhotoOutput *photoOutput = [[AVCapturePhotoOutput alloc] init];
    if ([self.session canAddOutput:photoOutput]) {
        [self.session addOutput:photoOutput];
        self.photoOutput = photoOutput;
        
        self.photoOutput.highResolutionCaptureEnabled = YES;
        self.photoOutput.livePhotoCaptureEnabled = self.photoOutput.livePhotoCaptureSupported;
        self.livePhotoMode = self.photoOutput.livePhotoCaptureSupported ? FYCameraLivePhotoModeOn : FYCameraLivePhotoModeOff;
        
        self.inProgressPhotoCaptureDelegate = [NSMutableDictionary dictionary];
        self.inProgressPhotoCaptureCount = 0;
    }else {
        NSLog(@"error : ");
        self.setupResult = FYCameraCaptureSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    
    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    
    [self.session commitConfiguration];
}

#pragma mark - system Setting
#pragma mark -overrided

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    return !self.moviceFileOutput.isRecording;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (UIDeviceOrientationIsPortrait(deviceOrientation) || UIDeviceOrientationIsLandscape(deviceOrientation)) {
        self.previewView.videoPreviewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)deviceOrientation;
    }
}

#pragma mark - ClickEventInvocation

- (void)livePhotoClickEventWithButton:(UIButton *)livePhotoButton {
    dispatch_async(self.sessionQueue, ^{
        self.livePhotoMode = (FYCameraLivePhotoModeOn == self.livePhotoMode) ? FYCameraLivePhotoModeOff : FYCameraLivePhotoModeOn;
        FYCameraLivePhotoMode livePhotoMode = self.livePhotoMode;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (FYCameraLivePhotoModeOn == livePhotoMode) {
                [livePhotoButton setTitle:NSLocalizedString(@"live photo off", nil) forState:UIControlStateNormal];
                livePhotoButton.alpha = 0.8;
                livePhotoButton.backgroundColor = [UIColor lightGrayColor];
                _capturingLivePhotoLabel.hidden = FYCameraLivePhotoModeOff;
            }else {
                [livePhotoButton setTitle:NSLocalizedString(@"live photo on", nil) forState:UIControlStateNormal];
                livePhotoButton.backgroundColor = [UIColor grayColor];
                _capturingLivePhotoLabel.hidden = FYCameraLivePhotoModeOn;
            }
        });
    });
}

- (void)segmentedClickInvocationWithSegmentedControl:(UISegmentedControl *)segmentedControl {
    switch (segmentedControl.selectedSegmentIndex) {
        case 0:
        {
            [self changeSegmentControlNeedsLayoutAndEventInvocation];
            break;
        }
        case 1:
        {
            [self changeSegmentControlNeedsLayoutAndEventInvocation];
            break;
        }
        default:
            break;
    }
}

- (void)recordClickEventWithButton:(UIButton *)recordButton {
    if (FYCameraCaptureModePhoto == self.captureMode) {
        return;
    }
    self.recordMode = (FYCameraRecordModeStarted == self.recordMode) ? FYCameraRecordModeStoped : FYCameraRecordModeStarted;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (FYCameraRecordModeStarted == self.recordMode) {
            [recordButton setTitle:NSLocalizedString(@"Stop", nil) forState:UIControlStateNormal];
            [recordButton setBackgroundColor:[UIColor redColor]];
        }else if (FYCameraRecordModeStoped == self.recordMode){
            [recordButton setTitle:NSLocalizedString(@"Record", nil) forState:UIControlStateNormal];
            [recordButton setBackgroundColor:[UIColor grayColor]];
        }else {
            
        }
    });
    
    self.recordButton.enabled = NO;
    self.cameraButton.enabled = NO;
    self.captureModeControl.enabled = NO;
    
    AVCaptureVideoOrientation videoPreviewLayerVideoOrientation =  self.previewView.videoPreviewLayer.connection.videoOrientation;
    
    dispatch_async(self.sessionQueue, ^{
        if (!self.moviceFileOutput.isRecording) {
            if ([UIDevice currentDevice].isMultitaskingSupported) {
                self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
            }
            AVCaptureConnection *movieFileOutputConnection = [self.moviceFileOutput connectionWithMediaType:AVMediaTypeVideo];
            movieFileOutputConnection.videoOrientation = videoPreviewLayerVideoOrientation;
            
            if (@available(iOS 11.0, *)) {
                if ([self.moviceFileOutput.availableVideoCodecTypes containsObject:AVVideoCodecTypeHEVC]) {
                    NSDictionary<NSString *, id> *videOutputCodecType = @{AVVideoCodecKey : AVVideoCodecTypeHEVC};
                    [self.moviceFileOutput setOutputSettings:videOutputCodecType forConnection:movieFileOutputConnection];
                }
                
                NSString *outputFileName = [NSUUID UUID].UUIDString;
                NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[outputFileName stringByAppendingPathExtension:@"mov"]];
                [self.moviceFileOutput startRecordingToOutputFileURL:[NSURL URLWithString:outputFilePath] recordingDelegate:self];
            } else {
                // Fallback on earlier versions
            }
        }else {
            [self.moviceFileOutput stopRecording];
        }
    });
}

- (void)photoClickEventWithButton:(UIButton *)photoButton {
    AVCaptureVideoOrientation videoPreviewLayerVideoOrientation = self.previewView.videoPreviewLayer.connection.videoOrientation;
    
    dispatch_async(self.sessionQueue, ^{
        AVCaptureConnection *photoOutputConnection = [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
        photoOutputConnection.videoOrientation = videoPreviewLayerVideoOrientation;
        
        AVCapturePhotoSettings *photoSetting = [AVCapturePhotoSettings photoSettings];
        photoSetting.flashMode = AVCaptureFlashModeAuto;
        photoSetting.highResolutionPhotoEnabled = YES;
        if (photoSetting.availablePreviewPhotoPixelFormatTypes.count > 0) {
            photoSetting.previewPhotoFormat = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : photoSetting.availablePreviewPhotoPixelFormatTypes.firstObject};
        }
        if (self.livePhotoMode == FYCameraLivePhotoModeOn && self.photoOutput.livePhotoCaptureSupported) {
            NSString *livePhotoMoviceFileName = [NSUUID UUID].UUIDString;
            NSString *livePhotoMoviceFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[livePhotoMoviceFileName stringByAppendingPathExtension:@"mov"]];
            photoSetting.livePhotoMovieFileURL = [NSURL URLWithString:livePhotoMoviceFilePath];
        }
        FYCameraKitPhotoCaptureDelegate *photoCaptureDelegate = [[FYCameraKitPhotoCaptureDelegate alloc] initWithRequestedPhotoSetting:photoSetting willCapturePhotoAnimation:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                self.previewView.videoPreviewLayer.opacity = 0.0f;
                NSTimeInterval duration = 0.30f;
                [UIView animateWithDuration:duration animations:^{
                    self.previewView.videoPreviewLayer.opacity = 1.0f;
                }];
            });
            
        } capturingLivePhoto:^(BOOL capturing) {
            dispatch_async(self.sessionQueue, ^{
                if (capturing) {
                    self.inProgressPhotoCaptureCount++;
                }else {
                    self.inProgressPhotoCaptureCount--;
                }
                NSInteger inProgressPhotoCaptureCount = self.inProgressPhotoCaptureCount;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (inProgressPhotoCaptureCount > 0) {
                        self.capturingLivePhotoLabel.hidden = NO;
                    }else if(inProgressPhotoCaptureCount == 0) {
                        self.capturingLivePhotoLabel.hidden = YES;
                    }else {
                        NSLog(@"Error ");
                    }
                });
            });
        } completed:^(FYCameraKitPhotoCaptureDelegate *photoCaptureDelegate) {
            dispatch_async(self.sessionQueue, ^{
                self.inProgressPhotoCaptureDelegate[@(photoCaptureDelegate.requestPhotoSettings.uniqueID)] = nil;
            });
        }];
    self.inProgressPhotoCaptureDelegate[@(photoCaptureDelegate.requestPhotoSettings.uniqueID)] = photoCaptureDelegate;
        [self.photoOutput capturePhotoWithSettings:photoSetting delegate:photoCaptureDelegate];
    });
}

- (void)cameraClickEventWithButton:(UIButton *)cameraButton {
    self.photoButton.enabled = NO;
    self.cameraButton.enabled = NO;
    self.recordButton.enabled = NO;
    self.livePhotoModeButton.enabled = NO;
    self.captureModeControl.enabled = NO;
    
    dispatch_async(self.sessionQueue, ^{
        AVCaptureDevice *currentVideoDevice = self.videoDeviceInput.device;
        AVCaptureDevicePosition currentVideoPosition = currentVideoDevice.position;
        
        AVCaptureDevicePosition preferredPosition;;
        AVCaptureDeviceType preferredDeviceType;
        
        switch (currentVideoPosition) {
            case AVCaptureDevicePositionUnspecified:
            case AVCaptureDevicePositionFront:
            {
                preferredPosition = AVCaptureDevicePositionBack;
                preferredDeviceType = AVCaptureDeviceTypeBuiltInDualCamera;
                break;
            }
            case AVCaptureDevicePositionBack:
            {
                preferredPosition = AVCaptureDevicePositionFront;
                preferredDeviceType = AVCaptureDeviceTypeBuiltInWideAngleCamera;
                break;
            }
        }
        
        NSArray<AVCaptureDevice *> *devices = self.videoDeviceDiscoverySession.devices;
        AVCaptureDevice *newVideoDevice = nil;
        
        for (AVCaptureDevice *device in devices) {
            if (device.position == preferredPosition && device.deviceType == preferredDeviceType) {
                newVideoDevice = device;
            }
        }
        if (!newVideoDevice) {
            for (AVCaptureDevice *device in devices) {
                if (device.position == preferredPosition) {
                    newVideoDevice = device;
                }
            }
        }
        
        if (newVideoDevice) {
            AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:newVideoDevice error:NULL];
            
            [self.session beginConfiguration];
            [self.session removeInput:self.videoDeviceInput];
            
            if ([self.session canAddInput:videoDeviceInput]) {
                [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentVideoDevice];
                
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChangeWithNotification:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:newVideoDevice];
                
                [self.session addInput:videoDeviceInput];
                self.videoDeviceInput = videoDeviceInput;
            }else {
                [self.session addInput:self.videoDeviceInput];
            }
            
            AVCaptureConnection *movieFileOutputconnection = [self.moviceFileOutput connectionWithMediaType:AVMediaTypeVideo];
            if (movieFileOutputconnection.isVideoStabilizationSupported) {
                movieFileOutputconnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
            }
            
            self.photoOutput.livePhotoCaptureEnabled = self.photoOutput.livePhotoCaptureSupported;
            
            [self.session commitConfiguration];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cameraButton.enabled = YES;
            self.recordButton.enabled = self.captureModeControl.selectedSegmentIndex == FYCameraCaptureModeMovie;
            self.photoButton.enabled = YES;
            
            self.livePhotoModeButton.enabled = YES;
            self.captureModeControl.enabled = YES;
        });
    });
}

#pragma mark - lazy loaded
#pragma mark -composeControls

- (UIButton *)livePhotoModeButton {
    if (!_livePhotoModeButton) {
        CGFloat heightLivePhotoModeButton = 30;
        CGFloat widthLivePhotoModeButton = 175;
        CGFloat positionY = 20;
        CGFloat positionX = (SCREEN_WIDTH - widthLivePhotoModeButton)/2;
        CGRect rect = CGRectMake(positionX, positionY, widthLivePhotoModeButton, heightLivePhotoModeButton);
        _livePhotoModeButton = [self configureButtonWithRect:rect title:@"live photo on"];
        [_livePhotoModeButton addTarget:self action:@selector(livePhotoClickEventWithButton:) forControlEvents:UIControlEventTouchDown];
        [_livePhotoModeButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    }
    return _livePhotoModeButton;
}

- (UILabel *)capturingLivePhotoLabel {
    if (!_capturingLivePhotoLabel) {
        CGFloat widthCaptureingLivePhotoLabel = 70.f;
        CGFloat heightCaptureingLivePhotoLabel = 25.f;
        CGFloat positionX = (SCREEN_WIDTH - widthCaptureingLivePhotoLabel)/2;
        CGFloat positionY = _previewView.frame.origin.y + 2;
        _capturingLivePhotoLabel = [[UILabel alloc] initWithFrame:CGRectMake(positionX, positionY, widthCaptureingLivePhotoLabel, heightCaptureingLivePhotoLabel)];
        _capturingLivePhotoLabel.text = @"Live";
        _capturingLivePhotoLabel.backgroundColor = [UIColor yellowColor];
        //        _capturingLivePhotoLabel.hidden = YES;
        _capturingLivePhotoLabel.textAlignment = NSTextAlignmentCenter;
        _capturingLivePhotoLabel.layer.cornerRadius = 3.0f;
        _capturingLivePhotoLabel.clipsToBounds = YES;
        _capturingLivePhotoLabel.enabled = NO;
    }
    return _capturingLivePhotoLabel;
}

- (FYPreviewView *)previewView {
    if (!_previewView) {
        CGFloat positionY = 72;
        CGFloat heightPreviewView = SCREEN_HEIGHT - positionY - 90;
        _previewView = [[FYPreviewView alloc] initWithFrame:CGRectMake(MARGIN_ALL_BORDER, positionY, SCREEN_WIDTH - MARGIN_ALL_BORDER * 2, heightPreviewView)];
        _previewView.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _previewView.backgroundColor = [UIColor lightGrayColor];
    }
    return _previewView;
}

- (UISegmentedControl *)captureModeControl {
    if (!_captureModeControl) {
        CGFloat heightCaptureModeControl = 30.f;
        CGFloat widthCaptureModeControl = 85.f;
        CGFloat positionY = _previewView.frame.origin.y + _previewView.bounds.size.height - heightCaptureModeControl - MARGIN_ALL_BORDER;
        CGFloat positionX = (SCREEN_WIDTH - widthCaptureModeControl)/2;
        NSArray *titleCaptureModeControlItems = @[@"photo",@"movie"];
        _captureModeControl = [[UISegmentedControl alloc] initWithItems:titleCaptureModeControlItems];
        _captureModeControl.frame = CGRectMake(positionX, positionY, widthCaptureModeControl, heightCaptureModeControl);
        _captureModeControl.selectedSegmentIndex = 0;
        _captureModeControl.tintColor = [UIColor yellowColor];
        [_captureModeControl addTarget:self action:@selector(segmentedClickInvocationWithSegmentedControl:) forControlEvents:UIControlEventValueChanged];
    }
    return _captureModeControl;
}

- (UIButton *)recordButton {
    if (!_recordButton) {
        CGFloat heightRecordButton = 40;
        CGFloat widthRecordButton = (SCREEN_WIDTH - 30 * 4)/3;
        CGFloat positionX = 40;
        CGFloat positionY = _previewView.frame.origin.y + _previewView.bounds.size.height + 25;
        CGRect rect = CGRectMake(positionX, positionY, widthRecordButton, heightRecordButton);
        _recordButton = [self configureButtonWithRect:rect title:@"Record"];
        [_recordButton addTarget:self action:@selector(recordClickEventWithButton:) forControlEvents:UIControlEventTouchDown];
    }
    return _recordButton;
}

- (UIButton *)photoButton {
    if (!_photoButton) {
        CGFloat heightRecordButton = 40;
        CGFloat widthRecordButton = (SCREEN_WIDTH - 30 * 4)/3;
        CGFloat positionX = _recordButton.frame.origin.x + widthRecordButton + 30;
        CGFloat positionY = _previewView.frame.origin.y + _previewView.bounds.size.height + 25;
        CGRect rect = CGRectMake(positionX, positionY, widthRecordButton, heightRecordButton);
        _photoButton = [self configureButtonWithRect:rect title:@"Photo"];
        [_photoButton addTarget:self action:@selector(photoClickEventWithButton:) forControlEvents:UIControlEventTouchDown];
    }
    return _photoButton;
}

- (UIButton *)cameraButton {
    if (!_cameraButton) {
        CGFloat heightRecordButton = 40;
        CGFloat widthRecordButton = (SCREEN_WIDTH - 30 * 4)/3;
        CGFloat positionX = SCREEN_WIDTH - widthRecordButton - 30;
        CGFloat positionY = _previewView.frame.origin.y + _previewView.bounds.size.height + 25;
        CGRect rect = CGRectMake(positionX, positionY, widthRecordButton, heightRecordButton);
        _cameraButton = [self configureButtonWithRect:rect title:@"Cramera"];
        [_cameraButton addTarget:self action:@selector(cameraClickEventWithButton:) forControlEvents:UIControlEventTouchDown];
    }
    return _cameraButton;
}

- (UIButton *)configureButtonWithRect:(CGRect)rect title:(NSString *)title {
    UIButton *button = [[UIButton alloc] initWithFrame:rect];
    [button setTitle:title forState:UIControlStateNormal];
    button.layer.cornerRadius = 6.0f;
    button.clipsToBounds = YES;
    button.backgroundColor = [UIColor grayColor];
    //    [button addTarget:self action:@selector(selector) forControlEvents:UIControlEventTouchDown];
    return button;
}

#pragma mark - privated Method (ClickEventInvocation)

- (void)changeSegmentControlNeedsLayoutAndEventInvocation {
    dispatch_async(self.sessionQueue, ^{
        self.captureMode = (FYCameraCaptureModePhoto == self.captureMode) ? FYCameraCaptureModeMovie : FYCameraCaptureModePhoto;
        FYCameraCaptureMode captureMode = self.captureMode;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (FYCameraCaptureModePhoto == captureMode) {
                _livePhotoModeButton.hidden = NO;
                if (FYCameraLivePhotoModeOn == self.livePhotoMode) {
                    _capturingLivePhotoLabel.hidden = NO;
                    
                }else if (FYCameraLivePhotoModeOff == self.livePhotoMode) {
                    _capturingLivePhotoLabel.hidden = YES;
                }
                
                CGFloat positionY = 72;
                CGFloat heightPreviewView = SCREEN_HEIGHT - positionY - 90;
                _previewView.frame = CGRectMake(MARGIN_ALL_BORDER, positionY, SCREEN_WIDTH - MARGIN_ALL_BORDER * 2, heightPreviewView);
                [self.view setNeedsLayout];
            }else if (FYCameraCaptureModeMovie == captureMode) {
                _livePhotoModeButton.hidden = YES;
                _capturingLivePhotoLabel.hidden = YES;
                CGRect rect = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
                _previewView.frame = rect;
                [self.view setNeedsLayout];
            }
        });
    });
    [self changeCaptureOutput];
}

- (void)changeCaptureOutput {
    if (FYCameraCaptureModePhoto == self.captureMode) {
        self.recordButton.enabled = NO;
        
        dispatch_async(self.sessionQueue, ^{
            [self.session beginConfiguration];
            [self.session removeOutput:self.moviceFileOutput];
            self.session.sessionPreset = AVCaptureSessionPresetPhoto;
            [self.session commitConfiguration];
            
            self.moviceFileOutput = nil;
            
            if (self.photoOutput.livePhotoCaptureSupported) {
                self.photoOutput.livePhotoCaptureEnabled = YES;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.photoButton.enabled = YES;
                });
            }
        });
        
    }else if (FYCameraCaptureModeMovie == self.captureMode) {
        dispatch_async(self.sessionQueue, ^{
            AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
            if ([self.session canAddOutput:movieFileOutput]) {
                [self.session beginConfiguration];
                [self.session addOutput:movieFileOutput];
                self.session.sessionPreset = AVCaptureSessionPresetHigh;
                AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
                if (connection.isVideoMirroringSupported) {
                    connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
                }
                [self.session commitConfiguration];
                self.moviceFileOutput = movieFileOutput;
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.recordButton.enabled = YES;
                });
            }
        });
    }
}

#pragma mark - privated Method (configuration error)

- (NSError *)configurationErrorWithMessage:(NSString *)msg userInfo:(NSDictionary *)userDic {
    NSErrorDomain errorDomain = [NSString stringWithFormat:@"error : %@ in %@ method of %@ class", msg, NSStringFromSelector(_cmd), NSStringFromClass([self class])];
    NSInteger errorCode = 101;
    NSDictionary *errorDic = nil;
    NSError *error = [NSError errorWithDomain:errorDomain code:errorCode userInfo:errorDic];
    return error;
}

#pragma mark - KVO and Notifications

- (void)addObserver {
    [self.session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChangeWithNotification:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.videoDeviceInput.device];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeErrorWithNotification:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterruptedWithNotification:) name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEndedWithNotification:) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.session removeObserver:self forKeyPath:@"running" context:SessionRunningContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (SessionRunningContext == context) {
        BOOL isSessionRunning =[change[NSKeyValueChangeNewKey] boolValue];
        BOOL livePhotoCaptureEnable = self.photoOutput.livePhotoCaptureEnabled;
        BOOL livePhotoCaptureSupported = self.photoOutput.livePhotoCaptureSupported;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.livePhotoModeButton.enabled = isSessionRunning && livePhotoCaptureEnable;
            self.livePhotoModeButton.hidden =  !(isSessionRunning && livePhotoCaptureSupported);
            self.captureModeControl.enabled = isSessionRunning;
            self.recordButton.enabled = isSessionRunning && (FYCameraCaptureModeMovie == self.captureMode);
            self.photoButton.enabled = isSessionRunning;
            self.cameraButton.enabled = isSessionRunning && (self.videoDeviceDiscoverySession.uniqueDevicePositionsCount >  1);
        });
        
    }else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)subjectAreaDidChangeWithNotification:(NSNotification *)notification {
    //    [self ];
}

- (void)sessionRuntimeErrorWithNotification:(NSNotification *)notification {
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    if (AVErrorMediaServicesWereReset == error.code) {
        dispatch_async(self.sessionQueue, ^{
            if (self.isSessionRunning) {
                [self.session startRunning];
                self.sessionRunning = self.session.running;
            }else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.resumeButton.hidden = NO;
                });
            }
        });
    }else {
        self.resumeButton.hidden = NO;
    }
}

- (void)sessionWasInterruptedWithNotification:(NSNotification *)notification {
    
    BOOL isShowResumeButton = NO;
    AVCaptureSessionInterruptionReason interruptionReason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
    if (AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient == interruptionReason || AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient == interruptionReason) {
        isShowResumeButton = YES;
    }else if (AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps == interruptionReason){
        self.cameraUnavailableLabel.alpha = 0.0f;
        self.cameraUnavailableLabel.hidden = NO;
        NSTimeInterval duration = 0.35;
        [UIView animateWithDuration:duration animations:^{
            self.cameraUnavailableLabel.alpha = 1.0;
        }];
    }
    
    if (isShowResumeButton) {
        self.resumeButton.alpha = 0.0f;
        self.resumeButton.hidden = NO;
        NSTimeInterval duration = 0.35;
        [UIView animateWithDuration:duration animations:^{
            self.resumeButton.alpha = 1.0f;
        }];
    }
}

- (void)sessionInterruptionEndedWithNotification:(NSNotification *)notification {
    if (!self.resumeButton.hidden) {
        NSTimeInterval duration = 0.25;
        [UIView animateWithDuration:duration animations:^{
            self.resumeButton.alpha = 0.0f;
        } completion:^(BOOL finished) {
            self.resumeButton.hidden = YES;
        }];
    }
    if (!self.cameraUnavailableLabel.hidden) {
        NSTimeInterval duration = 0.25;
        [UIView animateWithDuration:duration animations:^{
            self.cameraUnavailableLabel.alpha = 0.0f;
        } completion:^(BOOL finished) {
            self.cameraUnavailableLabel.hidden = YES;
        }];
    }
}

#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)output didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recordButton.enabled = YES;
        [self.recordButton setTitle:NSLocalizedString(@"Stop", nil) forState:UIControlStateNormal];
    });
}

- (void)captureOutput:(nonnull AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(nonnull NSURL *)outputFileURL fromConnections:(nonnull NSArray<AVCaptureConnection *> *)connections error:(nullable NSError *)error {
    UIBackgroundTaskIdentifier currentBackgroundRecordingID = self.backgroundTaskIdentifier;
    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    
    dispatch_block_t cleanUp = ^{
        if ([[NSFileManager defaultManager] fileExistsAtPath:outputFileURL.path]) {
            [[NSFileManager defaultManager] removeItemAtPath:outputFileURL.path error:NULL];
            
            if (currentBackgroundRecordingID != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:currentBackgroundRecordingID];
            }
        }
    };
    
    BOOL success = YES;
    
    if (error) {
        NSLog(@"Error movie file finishing : %@", error);
       success = [error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue];
    }
    
    if (success) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (PHAuthorizationStatusAuthorized == status) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                    options.shouldMoveFile = YES;
                    
                    PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAsset];
                    [creationRequest addResourceWithType:PHAssetResourceTypeVideo fileURL:outputFileURL options:options];
                } completionHandler:^(BOOL success, NSError * _Nullable error) {
                    if (!success) {
                        NSLog(@"Error: ");
                    }
                    cleanUp();
                }];
            }else {
                cleanUp();
            }
        }];
    }else {
        cleanUp();
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.cameraButton.enabled = (self.videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1);
        self.recordButton.enabled = YES;
        self.captureModeControl.enabled = YES;
        [self.recordButton setTitle:NSLocalizedString(@"Record", nil) forState:UIControlStateNormal];
    });
}

@end
    
