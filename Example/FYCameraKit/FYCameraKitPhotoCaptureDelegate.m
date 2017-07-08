//
//  FYCameraKitPhotoCaptureDelegate.m
//  FYCameraKit_Example
//
//  Created by liangbai on 2017/7/3.
//  Copyright © 2017年 boilwater. All rights reserved.
//

#import "FYCameraKitPhotoCaptureDelegate.h"
#import <Photos/Photos.h>

@interface FYCameraKitPhotoCaptureDelegate ()

@property(nonatomic, readwrite) AVCapturePhotoSettings *mRequestedPhotoSettings;
@property(nonatomic) void (^willsCapturePhotoAnimation)(void);
@property(nonatomic) void (^capturingLivePhoto)(BOOL capturing);
@property(nonatomic) void (^completionHandler)(FYCameraKitPhotoCaptureDelegate *photoCaptureDelegate);

@property(nonatomic) NSData *photoData;
@property(nonatomic) NSURL *livePhotoCompanionMovieURL;

@end

@implementation FYCameraKitPhotoCaptureDelegate

- (instancetype)initWithRequestedPhotoSetting:(AVCapturePhotoSettings *)requestedSettings
                    willCapturePhotoAnimation:(void (^)(void))willsCapturePhotoAnimation
                           capturingLivePhoto:(void (^)(BOOL))capturingLivePhoto
                                    completed:(void (^)(FYCameraKitPhotoCaptureDelegate *))completionHandler {
    self = [super init];
    if (self) {
        self.mRequestedPhotoSettings = requestedSettings;
        self.willsCapturePhotoAnimation = willsCapturePhotoAnimation;
        self.capturingLivePhoto = capturingLivePhoto;
        self.completionHandler = completionHandler;
    }
    return self;
}

- (void)didFinish {
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.livePhotoCompanionMovieURL.path]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:self.livePhotoCompanionMovieURL.path error: &error];
        if (nil == error) {
            NSLog(@"Error live photo Companion URL : %@",self.livePhotoCompanionMovieURL);
        }
    }
    self.completionHandler(self);
}

#pragma mark - AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)output willBeginCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings {
    if ((resolvedSettings.livePhotoMovieDimensions.height > 0) && (resolvedSettings.livePhotoMovieDimensions.width > 0)) {
        self.capturingLivePhoto(YES);
    }
}

- (void)captureOutput:(AVCapturePhotoOutput *)output willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings {
    self.willsCapturePhotoAnimation();
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    if (nil != error) {
        NSLog(@"Error processing photo :%@ ", error);
    }
#ifdef __IPHONE_11_0
    self.photoData = [photo fileDataRepresentation];
#else
    self.photoData = nil;
#endif
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishRecordingLivePhotoMovieForEventualFileAtURL:(nonnull NSURL *)outputFileURL
     resolvedSettings:(nonnull AVCaptureResolvedPhotoSettings *)resolvedSettings {
    self.capturingLivePhoto(NO);
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingLivePhotoToMovieFileAtURL:(NSURL *)outputFileURL
             duration:(CMTime)duration
     photoDisplayTime:(CMTime)photoDisplayTime
     resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
                error:(NSError *)error {
    if (nil == error) {
        NSLog(@"Error process live photo movie : %@", error);
    }
    self.livePhotoCompanionMovieURL = outputFileURL;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
                error:(NSError *)error {
    if (nil == error) {
        NSLog(@"Error capture resolvedSettig : %@", error);
        [self didFinish];
        return;
    }
    
    if (nil == self.photoData) {
        NSLog(@"Error finish process photo : %@", error);
        [self didFinish];
        return;
    }
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (PHAuthorizationStatusAuthorized == status) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                options.uniformTypeIdentifier = self.requestPhotoSettings.processedFileType;
                
                PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAsset];
                [creationRequest addResourceWithType:PHAssetResourceTypePhoto data:self.photoData options:options];
                if (nil == self.livePhotoCompanionMovieURL) {
                    PHAssetResourceCreationOptions *livePhotoCompanionCreationOptions = [[PHAssetResourceCreationOptions alloc] init];
                    livePhotoCompanionCreationOptions.shouldMoveFile = YES;
                    [creationRequest addResourceWithType:PHAssetResourceTypeVideo fileURL:self.livePhotoCompanionMovieURL options:livePhotoCompanionCreationOptions];
                }
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                if (!success) {
                    
                }
                [self didFinish];
            }];
        }else {
            
            [self didFinish];
        }
    }];
}

@end
