/*==============================================================================
            Copyright (c) 2012 QUALCOMM Austria Research Center GmbH.
            All Rights Reserved.
            Qualcomm Confidential and Proprietary
==============================================================================*/


#import <UIKit/UIKit.h>
#import "ARGeoViewController.h"

@class ARParentViewController;


@interface BackgroundTextureAccessAppDelegate : NSObject <UIApplicationDelegate, ARViewDelegate> {
    UIWindow* window;
    ARParentViewController* arParentViewController;
    UIImageView *splashV;
}

@property (nonatomic, retain)UIWindow* window;

-(void) setDefaultARMode;
-(void) setDominoARMode;
- (UIView *)viewForCoordinate:(ARCoordinate *)coordinate;;
@end
