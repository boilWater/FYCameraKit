//
//  FYPreviewView.h
//  FYCameraKit_Example
//
//  Created by liangbai on 2017/6/29.
//  Copyright © 2017年 boilwater. All rights reserved.
//

#import <UIKit/UIKit.h>

@class  AVCaptureSession;
@class  AVCaptureVideoPreviewLayer;

@interface FYPreviewView : UIView

@property(nonatomic, readonly) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property(nonatomic) AVCaptureSession *session;

@end
