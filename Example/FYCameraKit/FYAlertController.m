//
//  FYAlertController.m
//  FYCameraKit_Example
//
//  Created by liangbai on 2017/7/6.
//  Copyright © 2017年 boilwater. All rights reserved.
//

#import "FYAlertController.h"

@interface FYAlertController ()

@property(nonatomic) UIAlertActionStyle mStyle;
@property(nonatomic) UIAlertAction *cancelAction;
@property(nonatomic) UIAlertAction *settingAction;

@end

@implementation FYAlertController

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle cancelActionTitle:(NSString *)cancleTitle {
    FYAlertController *alertController = [super alertControllerWithTitle:title message:message preferredStyle:preferredStyle];
    if (alertController) {
        alertController.mStyle = alertController.style;
        [alertController addAction:[alertController cancelAction]];
    }
    return alertController;
}

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle cancleActionTitle:(NSString *)cancleTitle settingActionTitle:(NSString *)settingTitle {
    FYAlertController *alertController = [super alertControllerWithTitle:title message:message preferredStyle:preferredStyle];
    if (alertController) {
        alertController.mStyle = alertController.style;
        [alertController addAction:[alertController cancelAction]];
        [alertController addAction:[alertController settingAction]];
    }
    return alertController;
}

- (UIAlertAction *)cancelAction {
    if (!_cancelAction) {
        _cancelAction = [UIAlertAction actionWithTitle:@"cancel" style:_mStyle handler:^(UIAlertAction * _Nonnull action) {
            
        }];
    }
    return _cancelAction;
}

- (UIAlertAction *)settingAction {
    if (!_settingAction) {
        _settingAction = [UIAlertAction actionWithTitle:@"setting" style:_mStyle handler:^(UIAlertAction * _Nonnull action) {
            
        }];
    }
    return _settingAction;
}


@end
