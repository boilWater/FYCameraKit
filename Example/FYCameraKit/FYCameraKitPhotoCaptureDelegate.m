//
//  FYCameraKitPhotoCaptureDelegate.m
//  FYCameraKit_Example
//
//  Created by liangbai on 2017/7/3.
//  Copyright © 2017年 boilwater. All rights reserved.
//

#import "FYCameraKitPhotoCaptureDelegate.h"

@interface FYCameraKitPhotoCaptureDelegate ()

@property(nonatomic, readwrite) AVCapturePhotoSettings *mRequestedPhotoSettings;
@property(nonatomic) void (^willsCapturePhotoAnimation)(void);
@property(nonatomic) void (^capturingLivePhoto)(BOOL capturing);
@property(nonatomic) void (^completed)(FYCameraKitPhotoCaptureDelegate *photoCaptureDelegate);

@property(nonatomic) NSData *photoData;
@property(nonatomic) NSURL *livePhotoCompanionMovieURL;

@end

@implementation FYCameraKitPhotoCaptureDelegate

- (instancetype)initWithRequestedPhotoSetting:(AVCapturePhotoSettings *)requestedSettings
                    willCapturePhotoAnimation:(void (^)(void))willsCapturePhotoAnimation
                           capturingLivePhoto:(void (^)(BOOL))capturingLivePhoto
                                    completed:(void (^)(FYCameraKitPhotoCaptureDelegate *))complete {
    self = [super init];
    if (self) {
        self.mRequestedPhotoSettings = requestedSettings;
        self.willsCapturePhotoAnimation = willsCapturePhotoAnimation;
        self.capturingLivePhoto = capturingLivePhoto;
        self.completed = complete;
    }
    return self;
}



@end
