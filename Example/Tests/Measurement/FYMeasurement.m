//
//  FYMeasurement.m
//  FYCameraKit_Example
//
//  Created by liangbai on 2017/8/10.
//  Copyright © 2017年 boilwater. All rights reserved.
//

#import "FYMeasurement.h"
#import <AVFoundation/AVFoundation.h>

#define VALUE_AVAILABLE_WHITEBALANCEGAIN(currentValue, maxValue) ((currentValue) > (maxValue) ? (maxValue) : (currentValue))

@interface FYMeasurement ()

@property (strong, nonatomic) AVCaptureSession *session;

@end

@implementation FYMeasurement

- (void)configurationCaptureSessionWithCaptureConnection{
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    AVCaptureDevice *audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    NSError *error = nil;
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioCaptureDevice error:&error];
    [session beginConfiguration];
    session.sessionPreset = AVCaptureSessionPresetPhoto;
    if (audioInput) {
        
    }else {
        //// Handle the failure.
        [session commitConfiguration];
    }
    if ([session canAddInput:audioInput]) {
        [session addInput:audioInput];
    }else {
        // Handle the failure.
        [session commitConfiguration];
    }
    
    
//    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    [session beginConfiguration];
    NSError *error = nil;
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (!videoInput) {
        //handle configuration video device
    }
    AVCaptureInputPort *videoPort = videoInput.ports[0];
    
    error = nil;
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (!videoInput) {
        //handle configuration audio device
    }
    AVCaptureInputPort *audioPort = audioInput.ports[0];
    
    NSArray<AVCaptureInputPort *> *inputPorts = @[videoPort, audioPort];
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    AVCaptureConnection *connection = [AVCaptureConnection connectionWithInputPorts:inputPorts output:videoDataOutput];
    if ([session canAddConnection:connection]) {
        [session addConnection:connection];
    }else {
        //handle session can not add AVCaptureConnection
        
        [session commitConfiguration];
        return;
    }
    [session commitConfiguration];
}

- (void)initCaptureDevices {
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
//    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDuoCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    audioDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInMicrophone mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
    
}

//配置闪光灯
- (void)configurationFlash {
    //Flash
    AVCaptureDevice *device = nil;
    NSArray *inputs = self.session.inputs;
    for (AVCaptureDeviceInput *input in inputs) {
        if ([device.deviceType isEqual:AVMediaTypeVideo]) {
            device = input.device;
        }
    }
    NSError *errorProperty = nil;
    if ([device hasFlash]) {
        if ([device isFlashAvailable]) {
            if ([device isFlashModeSupported:AVCaptureFlashModeOn]) {
                BOOL result = NO;
                result = [device lockForConfiguration:&errorProperty];
                if (result) {
                    [device setFlashMode:AVCaptureFlashModeOn];
                }else {
                    NSLog(@"ERROR : CONFIGURATION CAPTURE DEVICE FLASH FAILURE, ERROR CODE:%ld", (long)errorProperty.code);
                }
                [device unlockForConfiguration];
            }else{
                NSLog(@"ERROR : FLASH IS UNAVAILABLE BECAUSE THE DEVCICE OVERHEATS");
            }
        }else {
            NSLog(@"ERROR : SOFTWARE DEVICE HAVE NO FLASH");
        }
    }
    
    
    //第二种方法 iOS 10_0
    NSArray *outputs = self.session.outputs;
    for (AVCaptureOutput *output in outputs) {
        if ([output isMemberOfClass:[AVCapturePhotoOutput class]]) {
            AVCapturePhotoOutput *photoOutput = (AVCapturePhotoOutput *)output;
            BOOL flashSupported = [[photoOutput supportedFlashModes] containsObject:@(AVCaptureFlashModeAuto)];
            if (flashSupported) {
                AVCapturePhotoSettings *photoSettings = photoOutput.photoSettingsForSceneMonitoring;
                photoSettings.flashMode = AVCaptureFlashModeAuto;
            }else {
                NSLog(@"ERROR : PHOTOOUTPUT CAN NOT SUPPORT AVCAPTUREMODE TYPE");
            }
        }
    }
}

//配置手电筒
- (void)configurationTorch {
    AVCaptureDevice *device = nil;
    NSArray *inputs = self.session.inputs;
    for (AVCaptureDeviceInput *input in inputs) {
        if ([device.deviceType isEqual:AVMediaTypeVideo]) {
            device = input.device;
        }
    }
    NSError *error = nil;
    if ([device hasTorch]) {
        if ([device isFlashAvailable]) {
            if ([device isTorchModeSupported:AVCaptureTorchModeOn]) {
                BOOL result = NO;
                result = [device lockForConfiguration:&error];
                if (result) {
                    [device setTorchMode:AVCaptureTorchModeOn];
                }else {
                    NSLog(@"ERROR : CONFIGURATION DEVICE TORCH FAIL AND ERROR CODE %ld", (long)error.code);
                }
                error = nil;
                // Torch light
                result = [device setTorchModeOnWithLevel:0.5 error:&error];
                if (!result) {
                    NSLog(@"ERROR : DEVICE SET TORCH FAILURE AND ERROR CODE %ld", error.code);
                }
                [device unlockForConfiguration];
            }else {
                NSLog(@"ERROR : DEVICE CAN NO SUPPORT TORCH");
            }
        }else {
            NSLog(@"ERROR : SOFTHARE DEVICE TORCH IS UNAVAILABLE BECAUSE OVERHEATS");
        }
    }else {
        NSLog(@"ERROR : SOFFHARE DEVICE HAS NO TORCH");
    }
}

//聚焦配置
- (void)configurationFocus {
    AVCaptureDevice *device = nil;
    NSArray *inputs = self.session.inputs;
    for (AVCaptureDeviceInput *input in inputs) {
        if ([device.deviceType isEqual:AVMediaTypeVideo]) {
            device = input.device;
        }
    }
    if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            //设置聚焦在设备坐标的中点
            if (device.focusPointOfInterestSupported) {
                device.focusPointOfInterest = CGPointMake(0.5, 0.5);
            }
        }
        [device unlockForConfiguration];
    }
}

//曝光配置
- (void)configurationExpose {
    AVCaptureDevice *device = nil;
    NSArray *inputs = self.session.inputs;
    for (AVCaptureDeviceInput *input in inputs) {
        if ([device.deviceType isEqual:AVMediaTypeVideo]) {
            device = input.device;
        }
    }
    if ([device isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        [device unlockForConfiguration];
    }
}

//白平衡配置，调整拍摄过程中的 红、绿和蓝之间的占比
- (void)configurationBalance {
    //设置自动白平衡
    AVCaptureDevice *device = nil;
    NSArray *inputs = self.session.inputs;
    for (AVCaptureDeviceInput *input in inputs) {
        if ([device.deviceType isEqual:AVMediaTypeVideo]) {
            device = input.device;
        }
    }
    if ([device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
        }
        [device unlockForConfiguration];
    }
    
    //AVCaptureWhiteBalanceGains设置
//    AVCaptureDevice *device = nil;
//    NSArray *inputs = self.session.inputs;
//    for (AVCaptureDeviceInput *input in inputs) {
//        if ([device.deviceType isEqual:AVMediaTypeVideo]) {
//            device = input.device;
//        }
//    }
    float maxWhiteBalance = device.maxWhiteBalanceGain;
    float redGain =  MIN(2.0, maxWhiteBalance);
    float greenGain = MIN(2.0, maxWhiteBalance);
    float blueGain = MIN(2.0, maxWhiteBalance);
    AVCaptureWhiteBalanceGains whiteBalanceGains = {
        redGain,
        greenGain,
        blueGain
    };
    
    [device setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:whiteBalanceGains completionHandler:nil];
    
}

@end
