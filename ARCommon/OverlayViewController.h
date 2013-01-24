/*==============================================================================
 Copyright (c) 2012 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/


#import <UIKit/UIKit.h>

@class QCARutils;

// OverlayViewController class overrides one UIViewController method
@interface OverlayViewController : UIViewController <UIActionSheetDelegate> 
{
    UIView *optionsOverlayView; // the view for the options pop-up
    UIActionSheet *mainOptionsAS; // the first level options menu
    UIActionSheet *targetOptionsAS; // a sub options menu
    UIActionSheet *modelOptionsAS; // a sub options menu
    UIActionSheet *arModeOptionsAS; // a sub options menu
    
    NSInteger selectedModel; // remember the selected target so we can mark it
    NSInteger selectedTarget; // remember the selected target so we can mark it
    NSInteger selectTargetIx; // index of the option that is 'Select Target'
    NSInteger selectModelIx; // index of the option that is 'Select Model'
    NSInteger switchModeIx; // index of the option that is 'Switch AR Mode'
    
    NSInteger torchIx;          // index of camera torch mode button
    NSInteger autofocusContIx;  // index of camera continuous autofocus button
    NSInteger autofocusIx;      // index of camera trigger autofocus button
    
    struct tagCameraCapabilities {
        BOOL autofocus;
        BOOL autofocusContinuous;
        BOOL torch;
    } cameraCapabilities;
    
    QCARutils *qUtils;
}

- (void) handleViewRotation:(UIInterfaceOrientation)interfaceOrientation;
- (void) showOverlay;
+ (BOOL) doesOverlayHaveContent;
- (void) targetSelectInView:(UIView *)theView;
// The user chose to select a model
- (void) modelSelectInView:(UIView *)theView;
@end
