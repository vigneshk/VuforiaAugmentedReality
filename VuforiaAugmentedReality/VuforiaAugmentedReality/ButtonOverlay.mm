/*==============================================================================
Copyright (c) 2012 QUALCOMM Austria Research Center GmbH .
All Rights Reserved.
Qualcomm Confidential and Proprietary
==============================================================================*/

#import <QuartzCore/QuartzCore.h>

#import "ButtonOverlay.h"
#import "Dominoes.h"
#import "OverlayViewController.h"


@implementation ButtonOverlay

@synthesize buttonView, menuButton, resetButton, runButton, clearButton, deleteButton, messageLabel;

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return YES;
}

- (void) setMenuCallBack:(SEL)callback forTarget:(id)target
{
    menuId = target;
    menuSel = callback;
}

- (void) updateButtonStatus
{
    bool notRunning = !dominoesIsSimulating();
    clearButton.hidden = !(notRunning && dominoesHasDominoes());
    runButton.hidden = !(notRunning && dominoesHasDominoes() && !dominoesHasRun());
    resetButton.hidden = !(notRunning && dominoesHasDominoes() && dominoesHasRun());
}

- (void) viewDidLoad
{
    [self updateButtonStatus];
    menuButton.hidden = ![OverlayViewController doesOverlayHaveContent];
}

- (void) viewDidAppear:(BOOL)animated
{
    [self updateButtonStatus];
}

- (IBAction) pressMenuButton
{
    if ((menuId != nil) && [menuId respondsToSelector:menuSel])
    {
        [menuId performSelector:menuSel];
    }
}

- (IBAction) pressResetButton
{
    dominoesReset();
    [self updateButtonStatus];
}


- (IBAction) pressRunButton
{
    if (dominoesHasDominoes())
        dominoesStart();   
    [self updateButtonStatus];
}


- (IBAction) pressClearButton
{
    dominoesClear();
    [self updateButtonStatus];
}


- (IBAction) pressDeleteButton
{
    dominoesDelete();
    [self updateButtonStatus];
}


- (void) showDeleteButton
{
    deleteButton.hidden = NO;
}


- (void) hideDeleteButton
{
    deleteButton.hidden = YES;
}

#define FADE_DURATION 0.5
#define SHOW_DURATION 5.0

- (void) showMessage:(NSString *)theMessage
{
    messageLabel.layer.borderColor = [UIColor whiteColor].CGColor;
    messageLabel.layer.borderWidth = 2.0;
    messageLabel.layer.cornerRadius = 4.0;
    messageLabel.clipsToBounds = YES;
    
    messageLabel.text = theMessage;
    messageLabel.alpha = 0.0;
    messageLabel.hidden = NO;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:FADE_DURATION];
    messageLabel.alpha = 1.0;
    [UIView commitAnimations];
    
    messageTimer = [NSTimer scheduledTimerWithTimeInterval:FADE_DURATION + SHOW_DURATION target:self selector:@selector(hideMessageOnTimeout:) userInfo:nil repeats:NO];
}

- (void) hideMessage
{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:FADE_DURATION];
    [UIView  setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(messageFadedOut:finished:context:)];
    messageLabel.alpha = 0.0;
    [UIView commitAnimations];    
}

- (void) messageFadedOut:(NSString *)animationID finished:(BOOL)finished context:(void *)context
{
    messageLabel.hidden = YES;
}

- (void) hideMessageOnTimeout:(NSTimer *)theTimer
{
    messageTimer = nil;
    [self hideMessage];
}

- (void)dealloc {
    [buttonView release];
    [menuButton release];
    [resetButton release];
    [runButton release];
    [clearButton release];
    [deleteButton release];
    messageLabel = nil;
    if (messageTimer != nil)
    {
        [messageTimer invalidate];
        messageTimer = nil;
    }
    
    [super dealloc];
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
}

@end
