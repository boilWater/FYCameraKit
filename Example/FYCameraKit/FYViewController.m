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
#import "FYCameraKitPhotoCaptureDelegate.h"
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, FYCameraCaptureSetupResult) {
    FYCameraCaptureSetupResultSuccess,
    FYCameraCaptureSetupResultNotAuthorized,
    FYCameraCaptureSetupResultSessionConfigurationFailed
};

typedef NS_ENUM(NSInteger, FYCameraLivePhotoMode) {
    FYCameraLivePhotoModeOn = 0,
    FYCameraLivePhotoModeOff = 1
};

typedef NS_ENUM(NSInteger, FYCameraCaptureMode) {
    FYCameraCaptureModePhoto = 0,
    FYCameraCaptureModeMovie = 1
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

@interface FYViewController ()

//session
@property(nonatomic) FYPreviewView *previewView;
@property(nonatomic, strong) UISegmentedControl *captureModeControl;
@property(nonatomic, assign) FYCameraCaptureMode captureMode;

@property(nonatomic) FYCameraCaptureSetupResult setupResult;
@property(nonatomic) dispatch_queue_t sessionQueue;
@property(nonatomic) AVCaptureSession *session;
@property(nonatomic, getter=isSessionRunning) BOOL sessionRunning;
@property(nonatomic) AVCaptureInput *videoDeviceInput;

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
                //[self addObserver];
                [self.session startRunning];
                self.sessionRunning = self.session.running;
                break;
            }
            case FYCameraCaptureSetupResultNotAuthorized:
            {
                
                break;
            }
            case FYCameraCaptureSetupResultSessionConfigurationFailed:
            {
                
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
            //[self removeObservers];
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
    
    NSArray<AVCaptureDeviceType> *deviceType = @[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDuoCamera];
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
    
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDuoCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
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
    
    NSLog(@"aaa->");
    if ([livePhotoButton.titleLabel.text isEqualToString:@"live photo on"]) {
        [livePhotoButton setTitle:@"live photo off" forState:UIControlStateNormal];
        livePhotoButton.alpha = 0.8;
        livePhotoButton.backgroundColor = [UIColor lightGrayColor];
        _capturingLivePhotoLabel.hidden = YES;
    }else {
        _capturingLivePhotoLabel.hidden = NO;
        [livePhotoButton setTitle:@"live photo on" forState:UIControlStateNormal];
        livePhotoButton.backgroundColor = [UIColor grayColor];
    }
}

- (void)segmentedClickInvocationWithSegmentedControl:(UISegmentedControl *)segmentedControl {
    switch (segmentedControl.selectedSegmentIndex) {
        case 0:
        {
            self.captureMode = FYCameraCaptureModePhoto;
            [self changeSegmentControlNeedsLayout];
            break;
        }
        case 1:
        {
            self.captureMode = FYCameraCaptureModeMovie;
            [self changeSegmentControlNeedsLayout];
            break;
        }
        default:
            break;
    }
}

- (void)recordClickEventWithButton:(UIButton *)recordButton {
    if (0 == _captureModeControl.selectedSegmentIndex) {
        return;
    }
    if ([recordButton.titleLabel.text isEqualToString:@"Record"] && _captureModeControl.selectedSegmentIndex == 1) {
        [recordButton setTitle:@"Stop" forState:UIControlStateNormal];
        [recordButton setBackgroundColor:[UIColor redColor]];
    }else{
        [recordButton setTitle:@"Record" forState:UIControlStateNormal];
        [recordButton setBackgroundColor:[UIColor grayColor]];
    }
}

- (void)photoClickEventWithButton:(UIButton *)photoButton {
    
}

- (void)cameraClickEventWithButton:(UIButton *)cameraButton {
    
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

- (void)changeSegmentControlNeedsLayout {
    if (FYCameraCaptureModePhoto == self.captureMode) {
        _livePhotoModeButton.hidden = NO;
        if (FYCameraLivePhotoModeOn == self.livePhotoMode) {
            _capturingLivePhotoLabel.hidden = NO;
            
        }else if (FYCameraLivePhotoModeOff == self.livePhotoMode) {
            _capturingLivePhotoLabel.hidden = YES;
        }
    }else if (FYCameraCaptureModeMovie == self.captureMode) {
        _livePhotoModeButton.hidden = YES;
        _capturingLivePhotoLabel.hidden = YES;
    }
    if (FYCameraCaptureModePhoto == self.captureMode) {
        if ([_recordButton.titleLabel.text isEqualToString:@"Stop"]) {
            [_recordButton setTitle:@"Record" forState:UIControlStateNormal];
            [_recordButton setBackgroundColor:[UIColor grayColor]];
        }
        CGFloat positionY = 72;
        CGFloat heightPreviewView = SCREEN_HEIGHT - positionY - 90;
        _previewView.frame = CGRectMake(MARGIN_ALL_BORDER, positionY, SCREEN_WIDTH - MARGIN_ALL_BORDER * 2, heightPreviewView);
        [self.previewView setNeedsLayout];
    }else if (FYCameraCaptureModeMovie == self.captureMode){
        CGRect rect = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
        _previewView.frame = rect;
        [self.previewView setNeedsLayout];
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

@end
