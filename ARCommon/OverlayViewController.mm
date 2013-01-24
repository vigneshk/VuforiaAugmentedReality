/*==============================================================================
Copyright (c) 2012 QUALCOMM Austria Research Center GmbH.
All Rights Reserved.
Qualcomm Confidential and Proprietary
==============================================================================*/

#import <AVFoundation/AVFoundation.h>
#import <QCAR/QCAR.h>
#import <QCAR/CameraDevice.h>
#import "OverlayViewController.h"
#import "OverlayView.h"
#import "QCARutils.h"
#import "EAGLView.h"

@interface OverlayViewController (PrivateMethods)
+ (void) determineCameraCapabilities:(struct tagCameraCapabilities *) pCapabilities;
@end

@implementation OverlayViewController

- (id) init
{
    if ((self = [super init]) != nil)
    {
        selectedTarget = 0;
        selectedModel =0;
        qUtils = [QCARutils getInstance];
    }
        
    return self;
}


- (void)dealloc {
    [optionsOverlayView release];
    [super dealloc];
}


- (void) loadView
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    optionsOverlayView = [[OverlayView alloc] initWithFrame: screenBounds];
    self.view = optionsOverlayView;
    
    // We're going to let the parent VC handle all interactions so disable any UI
    // Further on, we'll also implement a touch pass-through
    self.view.userInteractionEnabled = NO;
    
    // Get the camera capabilities
    [OverlayViewController determineCameraCapabilities:&cameraCapabilities];
}


- (void) handleViewRotation:(UIInterfaceOrientation)interfaceOrientation
{
    // adjust the size according to the rotation
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGRect overlayRect = screenRect;
    
    if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        overlayRect.size.width = screenRect.size.height;
        overlayRect.size.height = screenRect.size.width;
    }
    
    optionsOverlayView.frame = overlayRect;
}


// The user touched the screen - pass through
- (void) touchesBegan: (NSSet*) touches withEvent: (UIEvent*) event
{
    // pass events down to parent VC
    [super touchesBegan:touches withEvent:event];
}


// pop-up is invoked by parent VC
- (void) showOverlay
{
    // Show camera control action sheet
    mainOptionsAS = [[[UIActionSheet alloc] initWithTitle:nil
                                                  delegate:self
                                         cancelButtonTitle:nil
                                    destructiveButtonTitle:nil
                                         otherButtonTitles:nil] autorelease];
    
    // add torch and focus control buttons if supported by the device
    torchIx = -1;
    autofocusIx = -1;
    autofocusContIx = -1;
    int count = 0;
    
    if (YES == cameraCapabilities.torch)
    {
        // set button text according to the current mode (toggle)
        BOOL torchMode = [qUtils cameraTorchOn];
        NSString *text = YES == torchMode ? @"Torch off" : @"Torch on";
        torchIx = [mainOptionsAS addButtonWithTitle:text];
        ++count;
    }
    
    if (YES == cameraCapabilities.autofocus)
    {
        autofocusIx = [mainOptionsAS addButtonWithTitle:@"Autofocus"];
        ++count;
    }
    
    if (YES == cameraCapabilities.autofocusContinuous)
    {
        // set button text according to the current mode (toggle)
        BOOL contAFMode = [qUtils cameraContinuousAFOn];
        NSString *text = YES == contAFMode ? @"Continuous autofocus off" : @"Continuous autofocus on";
        autofocusContIx = [mainOptionsAS addButtonWithTitle:text];
        ++count;
    }
    
    if (qUtils.arMode== AR_MODE_DEFAULT || qUtils.arMode== AR_MODE_DOMINO)
    {
        // add 'select target' if there is more than one target
        selectTargetIx = -1;
        if (qUtils.targetsList && [qUtils.targetsList count] > 1)
        {
            selectTargetIx = [mainOptionsAS addButtonWithTitle:@"Select Target"];
            ++count;
        }
        
        if (qUtils.arMode== AR_MODE_DEFAULT)
        {
            // add 'select model' if there is more than one model
            selectModelIx = -1;
            if (qUtils.modelsList && [qUtils.modelsList count] > 1)
            {
                selectModelIx = [mainOptionsAS addButtonWithTitle:@"Select Model"];
                ++count;
            }
        }
    }
    
    switchModeIx = [mainOptionsAS addButtonWithTitle:@"Switch AR Mode"];
    ++count;

    NSInteger cancelIx = [mainOptionsAS addButtonWithTitle:@"Cancel"];
    [mainOptionsAS setCancelButtonIndex:cancelIx];
    
    if (0 < count)
    {
        self.view.userInteractionEnabled = YES;
        [mainOptionsAS showInView:self.view];
    }
}

// check to see if any content would be shown in showOverlay
+ (BOOL) doesOverlayHaveContent
{
    int count = 0;
    
    struct tagCameraCapabilities capabilities;
    [OverlayViewController determineCameraCapabilities:&capabilities];
    
    if (YES == capabilities.torch)
        ++count;
    
    if (YES == capabilities.autofocus)
        ++count;
    
    if (YES == capabilities.autofocusContinuous)
        ++count;
    
    if ([QCARutils getInstance].targetsList && [[QCARutils getInstance].targetsList count] > 1)
        ++count;
    
    return (count > 0);
}


// The user chose to select a target
- (void) targetSelectInView:(UIView *)theView
{
    targetOptionsAS = [[[UIActionSheet alloc] initWithTitle:@"Select Target"
                                                  delegate:self
                                         cancelButtonTitle:nil
                                    destructiveButtonTitle:nil
                                         otherButtonTitles:nil] autorelease];
    
    for (int i=0;i<[qUtils.targetsList count];i++)
    {
        DataSetItem *targetEntry = [qUtils.targetsList objectAtIndex:i];
        NSString *text = [(selectedTarget == i) ? @"* " : @"" stringByAppendingString:targetEntry.name];
        [targetOptionsAS addButtonWithTitle:text];
    }
    
    NSInteger cancelIx = [targetOptionsAS addButtonWithTitle:@"Cancel"];
    [targetOptionsAS setCancelButtonIndex:cancelIx];
        
    [targetOptionsAS showInView:theView];
}

// The user chose to select a model
- (void) modelSelectInView:(UIView *)theView
{
    modelOptionsAS = [[[UIActionSheet alloc] initWithTitle:@"Select Model"
                                                   delegate:self
                                          cancelButtonTitle:nil
                                     destructiveButtonTitle:nil
                                          otherButtonTitles:nil] autorelease];
    
    for (int i=0;i<[qUtils.modelsList count];i++)
    {
        Object3D *targetEntry = [qUtils.modelsList objectAtIndex:i];
        NSString *text = [(selectedModel == i) ? @"* " : @"" stringByAppendingString:targetEntry.modelName];
        [modelOptionsAS addButtonWithTitle:text];
    }
    
    NSInteger cancelIx = [modelOptionsAS addButtonWithTitle:@"Cancel"];
    [modelOptionsAS setCancelButtonIndex:cancelIx];
    
    [modelOptionsAS showInView:theView];
}

// The user chose to select a model
- (void) arModesSelectInView:(UIView *)theView
{
    arModeOptionsAS = [[[UIActionSheet alloc] initWithTitle:@"Select AR Mode"
                                                  delegate:self
                                         cancelButtonTitle:nil
                                    destructiveButtonTitle:nil
                                         otherButtonTitles:nil] autorelease];
    
    for (int i=0;i< 4;i++)
    {
        NSString *arModeName =@"";
        switch (i) {
            case AR_MODE_DEFAULT:
                arModeName =@"Default";
                break;
                
            case AR_MODE_DOMINO:
                arModeName =@"Dominoes";
                break;
                
            case AR_MODE_FLAKES:
                arModeName =@"Flakes";
                break;
                
            default:
                arModeName =@"Frames";
                break;
        }
        NSString *text = [(qUtils.arMode == i) ? @"* " : @"" stringByAppendingString:arModeName];
        [arModeOptionsAS addButtonWithTitle:text];
    }
    
    NSInteger cancelIx = [arModeOptionsAS addButtonWithTitle:@"Cancel"];
    [arModeOptionsAS setCancelButtonIndex:cancelIx];
    
    [arModeOptionsAS showInView:theView];
}


// UIActionSheetDelegate event handlers

- (void) mainOptionClickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == selectTargetIx)
    {
        // Select targets from here
        [self targetSelectInView:self.view];
    }
    else if (buttonIndex == selectModelIx)
    {
        // Select models from here
        [self modelSelectInView:self.view];
    }
    else if (buttonIndex == switchModeIx)
    {
        // Select AR modes from here
        [self arModesSelectInView:self.view];
    }
    else
    {
        if (torchIx == buttonIndex)
        {
            // toggle camera torch mode
            BOOL newTorchMode = ![qUtils cameraTorchOn];
            [qUtils cameraSetTorchMode:newTorchMode];
        }
        else if (autofocusContIx == buttonIndex)
        {
            // toggle camera continuous autofocus mode
            BOOL newContAFMode = ![qUtils cameraContinuousAFOn];
            [qUtils cameraSetContinuousAFMode:newContAFMode];
        }
        else if (autofocusIx == buttonIndex)
        {
            // trigger camera autofocus
            [qUtils cameraTriggerAF];
        }
        
        self.view.userInteractionEnabled = NO;
    }
}

- (void) targetOptionClickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ((buttonIndex < [qUtils.targetsList count]) && (buttonIndex != selectedTarget))
    {
        selectedTarget = buttonIndex;
        
        DataSetItem *targetEntry = [qUtils.targetsList objectAtIndex:selectedTarget];
        [qUtils activateDataSet:targetEntry.dataSet];
    }
    
    self.view.userInteractionEnabled = NO;
}

- (void) modelOptionClickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ((buttonIndex < [qUtils.modelsList count]) && (buttonIndex != selectedModel))
    {
        selectedModel = buttonIndex;
        
        Object3D *targetEntry = [qUtils.modelsList objectAtIndex:selectedModel];
        NSLog(@"Current model selected:%@",targetEntry.modelName);
        [qUtils setSelectedModel:selectedModel];
    }
    
    self.view.userInteractionEnabled = NO;
}

- (void) arModeOptionClickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ((buttonIndex < 4) && (buttonIndex != qUtils.arMode))
    {
        switch (buttonIndex) {
            case AR_MODE_DEFAULT:
                qUtils.arMode = AR_MODE_DEFAULT;
                [self targetOptionClickedButtonAtIndex:0]; // set the target to TRS2012 box by default                
                [[[UIApplication sharedApplication] delegate] performSelector:@selector(setDefaultARMode)];
                break;
            
            case AR_MODE_DOMINO:
                qUtils.arMode = AR_MODE_DOMINO;
                [self targetOptionClickedButtonAtIndex:0]; // set the target to TRS2012 box by default
                [[[UIApplication sharedApplication] delegate] performSelector:@selector(setDominoARMode)];
                break;
            
            case AR_MODE_FLAKES:
                qUtils.arMode = AR_MODE_FLAKES;
                [self targetOptionClickedButtonAtIndex:2]; // set the target to flakes box by default
                [[[UIApplication sharedApplication] delegate] performSelector:@selector(setFlakesARMode)];
                break;
                
            default:
                qUtils.arMode = AR_MODE_FRAMES;
                [self targetOptionClickedButtonAtIndex:0]; // set the target to TRS2012 box by default                
                [[[UIApplication sharedApplication] delegate] performSelector:@selector(setDefaultARMode)];
                break;
        }
    }
    
    self.view.userInteractionEnabled = NO;
}


- (void) actionSheet:(UIActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (actionSheet == mainOptionsAS)
        [self mainOptionClickedButtonAtIndex:buttonIndex];
    else if (actionSheet == targetOptionsAS)
        [self targetOptionClickedButtonAtIndex:buttonIndex];
    else if (actionSheet == modelOptionsAS)
        [self modelOptionClickedButtonAtIndex:buttonIndex];
    else if (actionSheet == arModeOptionsAS)
        [self arModeOptionClickedButtonAtIndex:buttonIndex];
}


+ (void) determineCameraCapabilities:(struct tagCameraCapabilities *) pCapabilities
{
    // Determine whether the back camera supports torch and autofocus
    NSArray* cameraArray = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice* camera in cameraArray)
    {
        if (AVCaptureDevicePositionBack == [camera position])
        {
            pCapabilities->autofocus = [camera isFocusModeSupported:AVCaptureFocusModeAutoFocus];
            pCapabilities->autofocusContinuous = [camera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus];
            pCapabilities->torch = [camera isTorchModeSupported:AVCaptureTorchModeOn];
            NSLog(@"autofocus: %d, autofocusContinuous: %d, torch %d", pCapabilities->autofocus, pCapabilities->autofocusContinuous, pCapabilities->torch);
        }
    }
}


@end
