//
//  FYCameraKitPhotoCaptureDelegate.h
//  FYCameraKit_Example
//
//  Created by liangbai on 2017/7/3.
//  Copyright © 2017年 boilwater. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface FYCameraKitPhotoCaptureDelegate : NSObject<AVCapturePhotoCaptureDelegate>

- (instancetype)initWithRequestedPhotoSetting:(AVCapturePhotoSettings *)requestedSettings
                    willCapturePhotoAnimation:(void (^)(void))willsCapturePhotoAnimation
                           capturingLivePhoto:(void (^)(BOOL capturing))capturingLivePhoto
                                    completed:(void (^)(FYCameraKitPhotoCaptureDelegate *photoCaptureDelegate))completionHandler;

@property(nonatomic, readonly) AVCapturePhotoSettings *requestPhotoSettings;

@end
