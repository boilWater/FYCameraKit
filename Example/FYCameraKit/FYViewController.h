//
//  FYViewController.h
//  FYCameraKit
//
//  Created by boilwater on 06/23/2017.
//  Copyright (c) 2017 boilwater. All rights reserved.
//

@import UIKit;
#import <AVFoundation/AVCaptureSessionPreset.h>
#import <AVFoundation/AVCaptureDevice.h>

@interface FYViewController : UIViewController

@property(nonatomic, strong) AVCaptureSessionPreset kSessionPreset;
@property(nonatomic, assign) AVCaptureDevicePosition kDevicePosition;


@end
