//
//  FYAlertController.h
//  FYCameraKit_Example
//
//  Created by liangbai on 2017/7/6.
//  Copyright © 2017年 boilwater. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FYAlertController : UIAlertController

@property(nonatomic) UIAlertActionStyle style;

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle cancelActionTitle:(NSString *)cancleTitle;

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle cancleActionTitle:(NSString *)cancleTitle settingActionTitle:(NSString *)settingTitle;

@end
