/*==============================================================================
Copyright (c) 2012 QUALCOMM Austria Research Center GmbH .
All Rights Reserved.
Qualcomm Confidential and Proprietary
==============================================================================*/


#import <UIKit/UIKit.h>
#import "EAGLView.h"


@interface ButtonOverlay : UIViewController {
    UIView *buttonView;
    UIButton* menuButton;
    UIButton* resetButton;
    UIButton* runButton;
    UIButton* clearButton;
    UIButton* deleteButton;
    UILabel* messageLabel;
    
    NSTimer* messageTimer;    
    id menuId;
    SEL menuSel;
}

@property (nonatomic, retain) IBOutlet UIView *buttonView;
@property (nonatomic, retain) IBOutlet UIButton* menuButton;
@property (nonatomic, retain) IBOutlet UIButton* resetButton;
@property (nonatomic, retain) IBOutlet UIButton* runButton;
@property (nonatomic, retain) IBOutlet UIButton* clearButton;
@property (nonatomic, retain) IBOutlet UIButton* deleteButton;
@property (nonatomic, retain) IBOutlet UILabel* messageLabel;

- (void) setMenuCallBack:(SEL)callback forTarget:(id)target;

- (IBAction) pressMenuButton;
- (IBAction) pressResetButton;
- (IBAction) pressRunButton;
- (IBAction) pressClearButton;
- (IBAction) pressDeleteButton;

- (void) showDeleteButton;
- (void) hideDeleteButton;
- (void) showMessage:(NSString *)theMessage;
- (void) hideMessage;

@end
