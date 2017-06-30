//
//  FYPreviewView.m
//  FYCameraKit_Example
//
//  Created by liangbai on 2017/6/29.
//  Copyright © 2017年 boilwater. All rights reserved.
//

#import "FYPreviewView.h"
#import <AVFoundation/AVCaptureVideoPreviewLayer.h>

@implementation FYPreviewView

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer *)videoPreviewLayer {
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (AVCaptureSession *)session {
    return self.videoPreviewLayer.session;
}

- (void)setSession:(AVCaptureSession *)session {
    self.videoPreviewLayer.session = session;
}

@end

