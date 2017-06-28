//
//  FYViewController.m
//  FYCameraKit
//
//  Created by boilwater on 06/23/2017.
//  Copyright (c) 2017 boilwater. All rights reserved.
//

#import "FYViewController.h"
#import "FYCameraKit-PrefixHeader.pch"
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>
#import <AVFoundation/AVCaptureOutput.h>
#import <AVFoundation/AVCaptureSession.h>
#import <AVFoundation/AVCaptureVideoPreviewLayer.h>

typedef void(^FYChangeCamreaConfiguration)(AVCaptureDevice *device);

@interface FYViewController ()

@property(nonatomic, strong) UIView *mVideoPreview; //image to preview
@property(nonatomic, strong) UIView *mStickerView; //view of taking photo
@property(nonatomic, strong) UIButton *mTakePhotoButton; //take photo
@property(nonatomic, strong) UIView *mFocusView; //point of camera

@property(nonatomic, strong) AVCaptureDevice *mCaptureDevice; //
@property(nonatomic, strong) AVCaptureSession *mCaptureSession; //translation between input and output
@property(nonatomic, strong) AVCaptureDeviceInput *mCaptureDeviceInput; //data to input
@property(nonatomic, strong) AVCaptureStillImageOutput *mCaptureStillImageOutput; //data to output
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *mCaptureVideoPreviewLayer; //layer of photo to preview 
//@property(nonatomic, strong) AVCaptureConnection *mCaptureConnection;

@end

@implementation FYViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initHierarchy];
    [self initParameters];
    
    [self addTapGestureRecognizer];
    [self addNotifacationWithCaptureDevice:self.mCaptureDevice];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.mCaptureSession startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.mCaptureSession stopRunning];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.mCaptureDevice];
    NSLog(@"dealloc : %p", __func__);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - initHierarchy(privated Method)

- (void)initHierarchy {
    self.view.backgroundColor = [UIColor purpleColor];
    [self.view addSubview:self.mVideoPreview];
    [self.mVideoPreview.layer insertSublayer:self.mCaptureVideoPreviewLayer atIndex:0];
    [self.mVideoPreview addSubview:self.mFocusView];
    [self.view addSubview:self.mStickerView];
    [self.view addSubview:self.mTakePhotoButton];
}

#pragma mark - initParameters(privated Method)

- (void)initParameters {
//    考虑是否需要执行 beginConfiguration 来对 CaptureSession 进行刷新
    [_mCaptureSession beginConfiguration];
    if ([self.mCaptureSession canAddInput:self.mCaptureDeviceInput]) {
        [_mCaptureSession addInput:_mCaptureDeviceInput];
    }

    if ([self.mCaptureSession canAddOutput:self.mCaptureStillImageOutput]) {
        [_mCaptureSession addOutput:_mCaptureStillImageOutput];
    }
    [_mCaptureSession commitConfiguration];
}

- (void)addTapGestureRecognizer {
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureScreen:)];
    [self.view addGestureRecognizer:tapGestureRecognizer];
}

- (void)addNotifacationWithCaptureDevice:(AVCaptureDevice *)captureDevice {
    [self setCameraConfigurationWithChangedCameraConfiguration:^(AVCaptureDevice *device) {
        device.subjectAreaChangeMonitoringEnabled = YES;
    }];
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(setAutoFocusCenterByChangingCaptureDevice:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}

- (void)tapGestureScreen:(UITapGestureRecognizer *)gestureRecognizer {
    CGPoint point = [gestureRecognizer locationInView:self.mVideoPreview];
    CGPoint cameraPoint = [self.mCaptureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setCameraFocusWithPoint:point];
    [self changeFocusWithMode:AVCaptureFocusModeAutoFocus captureExposureMode: AVCaptureExposureModeAutoExpose atCurrentPoint:cameraPoint];
}

#pragma mark - privatedMethods(privated Method)

- (AVCaptureDevice *)getCameraWithCaptureDevicePosition:(AVCaptureDevicePosition)position {
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if (position == [camera position]) {
            return camera;
        }
    }
    return nil;
}

- (void)clickTakePhotoButton:(UIButton *)sender {
    AVCaptureConnection *captureConnection = [self.mCaptureStillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    [self.mCaptureStillImageOutput captureStillImageAsynchronouslyFromConnection:captureConnection completionHandler:^(CMSampleBufferRef  _Nullable imageDataSampleBuffer, NSError * _Nullable error) {
        NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *takePhotoImage = [UIImage imageWithData:data];
        UIImageWriteToSavedPhotosAlbum(takePhotoImage, nil, nil, nil);
    }];
}

- (void)setCameraFocusWithPoint:(CGPoint)point {
    self.mFocusView.center = point;
    self.mFocusView.transform = CGAffineTransformMakeScale(1.5, 1.5);
    self.mFocusView.alpha = 1.0f;
    NSTimeInterval timeInterval = 1.0f;
    [UIView animateWithDuration:timeInterval animations:^{
        self.mFocusView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.mFocusView.alpha = 0.0f;
    }];
}

- (void)changeFocusWithMode:(AVCaptureFocusMode)focusMode
        captureExposureMode:(AVCaptureExposureMode)exposureMode
             atCurrentPoint:(CGPoint)point {
    [self setCameraConfigurationWithChangedCameraConfiguration:^(AVCaptureDevice *device) {
        if ([device isFocusModeSupported:focusMode]) {
            [device setFocusMode:focusMode];
        }
        if ([device isFocusPointOfInterestSupported]) {
            [device setFocusPointOfInterest:point];
        }
        
        if ([device isExposureModeSupported:exposureMode]) {
            [device setExposureMode:exposureMode];
        }
        if ([device isExposurePointOfInterestSupported]) {
            [device setExposurePointOfInterest:point];
        }
    }];
}

- (void)setCameraConfigurationWithChangedCameraConfiguration:(FYChangeCamreaConfiguration)changeCameraConfiguration {
    AVCaptureDevice *captureDevice = [self.mCaptureDeviceInput device];
    NSError *error = nil;
    if ([captureDevice lockForConfiguration:&error]) {
        changeCameraConfiguration(captureDevice);
        [captureDevice unlockForConfiguration];
    }else {
        NSError *errorLog = [self getErrorWithMessage:[NSString stringWithFormat:@"%@", error] method:NSStringFromSelector(_cmd)];
        NSLog(@"error: %@", errorLog);
        return;
    }
}

- (void)setAutoFocusCenterByChangingCaptureDevice:(AVCaptureDevice *)device {
    CGPoint point = self.mVideoPreview.center;
    CGPoint cameraPoint = [self.mCaptureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setCameraFocusWithPoint:point];
    [self changeFocusWithMode:AVCaptureFocusModeAutoFocus captureExposureMode:AVCaptureExposureModeAutoExpose atCurrentPoint:cameraPoint];
}

- (NSError *)getErrorWithMessage:(NSString *)message method:(NSString *)method {
    NSErrorDomain errorDomain = [NSString stringWithFormat:@"error : %@", message];
    NSInteger errorCode = 101;
    NSDictionary *errorDic = nil;
    NSError *error = [NSError errorWithDomain:errorDomain code:errorCode userInfo:errorDic];
    return error;
}

#pragma mark - override (System Settings)

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - setter & getter (Lazy loading)

- (AVCaptureDevice *)mCaptureDevice {
    if (!_mCaptureDevice) {
        _mCaptureDevice = [self getCameraWithCaptureDevicePosition:AVCaptureDevicePositionBack];
//        NSString *localizedName = _mCaptureDevice.localizedName;
    }
    return _mCaptureDevice;
}

- (AVCaptureSession *)mCaptureSession {
    if (!_mCaptureSession) {
        _mCaptureSession = [[AVCaptureSession alloc] init];
        if ([_mCaptureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
            _mCaptureSession.sessionPreset = AVCaptureSessionPreset640x480;
//            接口测试
            BOOL isInterrupted = _mCaptureSession.interrupted;
            
        }
    }
    return _mCaptureSession;
}

- (AVCaptureDeviceInput *)mCaptureDeviceInput {
    NSError *error = nil;
    if (!_mCaptureDeviceInput) {
//        AVCaptureDevice *backGroundCamera = [self getCameraWithCaptureDevicePosition:AVCaptureDevicePositionBack];
        _mCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.mCaptureDevice error:&error];
        if (!error) {
            NSLog(@"get camera of backgroud failure in class:%p", self);
        }
    }
    return _mCaptureDeviceInput;
}

- (AVCaptureStillImageOutput *)mCaptureStillImageOutput {
    if (!_mCaptureStillImageOutput) {
        _mCaptureStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *mStillImageOutputSetting = @{AVVideoCodecKey:AVVideoCodecJPEG};
        [_mCaptureStillImageOutput setOutputSettings:mStillImageOutputSetting];
    }
    return _mCaptureStillImageOutput;
}

- (AVCaptureVideoPreviewLayer *)mCaptureVideoPreviewLayer {
    if (!_mCaptureVideoPreviewLayer) {
        _mCaptureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.mCaptureSession];
        CALayer *layer = self.mVideoPreview.layer;
//        layer.masksToBounds = YES;
        _mCaptureVideoPreviewLayer.frame = layer.bounds;
        _mCaptureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return _mCaptureVideoPreviewLayer;
}

- (UIView *)mVideoPreview {
    if (!_mVideoPreview) {
        CGFloat positionY = [UIApplication sharedApplication].statusBarFrame.size.height;
        _mVideoPreview = [[UIView alloc] initWithFrame:CGRectMake(MARGIN_ALL_BORDER, positionY + MARGIN_ALL_BORDER, SCREEN_WIDTH - MARGIN_ALL_BORDER*2, SCREEN_HEIGHT - positionY - 140 - MARGIN_ALL_BORDER)];
        _mVideoPreview.backgroundColor = [UIColor orangeColor];
    }
    return _mVideoPreview;
}

- (UIView *)mFocusView {
    if (!_mFocusView) {
        CGFloat positionX = _mVideoPreview.frame.size.width/2;
        CGFloat positionY = _mVideoPreview.frame.origin.y + _mVideoPreview.bounds.size.height/2;
        CGFloat widthFocusView = 40;
        CGFloat heidthFocusView = 40;
        _mFocusView = [[UIView alloc] initWithFrame:CGRectMake(positionX, positionY, widthFocusView, heidthFocusView)];
        _mFocusView.backgroundColor = [UIColor clearColor];
        CALayer *calyer = [[CALayer alloc] init];
        calyer.frame = _mFocusView.bounds;
        calyer.borderColor = [UIColor yellowColor].CGColor;
        calyer.borderWidth = 0.7f;
        calyer.backgroundColor = [UIColor clearColor].CGColor;
        [_mFocusView.layer insertSublayer:calyer atIndex:0];
        _mFocusView.alpha = 0.0f;
    }
    return _mFocusView;
}

- (UIView *)mStickerView {
    if (!_mStickerView) {
        CGFloat positionY = _mVideoPreview.frame.origin.y + _mVideoPreview.bounds.size.height + MARGIN_ALL_BORDER;
        _mStickerView = [[UIView alloc] initWithFrame:CGRectMake(MARGIN_ALL_BORDER, positionY, SCREEN_WIDTH - MARGIN_ALL_BORDER*2, SCREEN_HEIGHT - positionY - MARGIN_ALL_BORDER*2)];
        _mStickerView.backgroundColor = [UIColor yellowColor];
    }
    return _mStickerView;
}

- (UIButton *)mTakePhotoButton {
    if (!_mTakePhotoButton) {
        CGFloat heightBt = 40;
        CGFloat widthBt = 120;
        CGFloat positionY = _mStickerView.frame.origin.y + _mStickerView.bounds.size.height/2 - heightBt/2 + 15;
        CGFloat positionX = (SCREEN_WIDTH - widthBt)/2;
        _mTakePhotoButton = [[UIButton alloc] initWithFrame:CGRectMake(positionX, positionY, widthBt, heightBt)];
        [_mTakePhotoButton setTitle:@"拍照" forState:UIControlStateNormal];
        [_mTakePhotoButton setBackgroundColor:[UIColor blueColor]];
        [_mTakePhotoButton addTarget:self action:@selector(clickTakePhotoButton:) forControlEvents:UIControlEventTouchDown];
    }
    return _mTakePhotoButton;
}

@end
