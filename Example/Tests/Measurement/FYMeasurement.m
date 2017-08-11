//
//  FYMeasurement.m
//  FYCameraKit_Example
//
//  Created by liangbai on 2017/8/10.
//  Copyright © 2017年 boilwater. All rights reserved.
//

#import "FYMeasurement.h"
#import <AVFoundation/AVFoundation.h>

@interface FYMeasurement ()

@property (strong, nonatomic) AVCaptureSession *session;

@end

@implementation FYMeasurement

- (void)configurationCaptureSessionWithCaptureConnection{
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
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

@end
