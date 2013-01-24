/*==============================================================================
            Copyright (c) 2012 QUALCOMM Austria Research Center GmbH.
            All Rights Reserved.
            Qualcomm Confidential and Proprietary
==============================================================================*/
/*
 
 The QCAR sample apps are organised to work with standard iOS view
 controller life cycles.
 
 * QCARutils contains all the code that initialises and manages the QCAR
 lifecycle plus some useful functions for accessing targets etc. This is a
 singleton class that makes QCAR accessible from anywhere within the app.
 
 * AR_EAGLView is a superclass that contains the OpenGL setup for its
 sub-class, EAGLView.
 
 Other classes and view hierarchy exists to establish a robust view life
 cycle:
 
 * ARParentViewController provides a root view for inclusion in other view
 hierarchies  presentModalViewController can present this VC safely. All
 associated views are included within it; it also handles the auto-rotate
 and resizing of the sub-views.
 
 * ARViewController manages the lifecycle of the Camera and Augmentations,
 calling QCAR:createAR, QCAR:destroyAR, QCAR:pauseAR and QCAR:resumeAR
 where required. It also manages the data for the view, such as loading
 textures.
 
 This configuration has been shown to work for iOS Modal and Tabbed views.
 It provides a model for re-usability where you want to produce a
 number of applications sharing code.
 
 The BackgroundTextureAccess app creates subclasses of some of the ARCommon classes
 in the following manner:
 
 * BTAParentViewController extends ARParentViewController by handling touch events
 and passing them to the EAGLView class.
 
 --------------------------------------------------------------------------------*/


#import "BackgroundTextureAccessAppDelegate.h"
#import "BTAParentViewController.h"
#import "DomParentViewController.h"
#import "QCARutils.h"

#import "ARGeoCoordinate.h"

#define BOX_WIDTH 320
#define BOX_HEIGHT 480

namespace {
    BOOL firstTime = YES;
}

@implementation BackgroundTextureAccessAppDelegate
@synthesize window;

// test to see if the screen has hi-res mode
- (BOOL) isRetinaEnabled
{
    return ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)]
            &&
            ([UIScreen mainScreen].scale == 2.0));
}


// Setup a continuation of the splash screen until the camera is initialised
- (void) setupSplashContinuation
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    
    // first get the splash screen continuation in place
    NSString *splashImageName = @"Default.png";
    if (screenBounds.size.width == 768)
        splashImageName = @"Default-Portrait~ipad.png";
    else if ((screenBounds.size.width == 320) && [self isRetinaEnabled])
        splashImageName = @"Default@2x.png";
    
    UIImage *image = [UIImage imageNamed:splashImageName];
    splashV = [[UIImageView alloc] initWithImage:image];
    splashV.frame = screenBounds;
    [window addSubview:splashV];
    
    // poll to see if the camera video stream has started and if so remove the splash screen.
    [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(removeSplash:) userInfo:nil repeats:YES];
}


// this is the application entry point
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    window = [[UIWindow alloc] initWithFrame: screenBounds];
    
    [self setupSplashContinuation];
    
    // Provide a list of targets we're expecting - the first in the list is the default
    [[QCARutils getInstance] addTargetName:@"TRS2012" atPath:@"TRS2012.xml"];
    [[QCARutils getInstance] addTargetName:@"StonesAndChips" atPath:@"StonesAndChips.xml"];
    [[QCARutils getInstance] addTargetName:@"Flakes Box" atPath:@"FlakesBox.xml"];
    [[QCARutils getInstance] addTargetName:@"Tarmac" atPath:@"Tarmac.xml"];
    
    // Add the EAGLView and the overlay view to the window
    [self setDefaultARMode];
//    [self addARGeoView];
    [window makeKeyAndVisible];
    
    return YES;
}

-(void) setDefaultARMode
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    // Add the EAGLView and the overlay view to the window
    arParentViewController = [[BTAParentViewController alloc] init];
    arParentViewController.arViewRect = screenBounds;
    if ([[window subviews] count] >0)
        [[[window subviews] objectAtIndex:0] removeFromSuperview];
    [window insertSubview:arParentViewController.view atIndex:0];

}

-(void) setDominoARMode
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    if ([[window subviews] count] >0)
        [[[window subviews] objectAtIndex:0] removeFromSuperview];

    // Add the DominoEAGLView and the overlay view to the window
    arParentViewController = [[DomParentViewController alloc] init];
    arParentViewController.arViewRect = screenBounds;
    [window insertSubview:arParentViewController.view atIndex:0];
    
}

-(void) setFlakesARMode
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    // Add the EAGLView and the overlay view to the window
    if ([[window subviews] count] >0)
        [[[window subviews] objectAtIndex:0] removeFromSuperview];
    
    arParentViewController = [[ARParentViewController alloc] init];
    arParentViewController.arViewRect = screenBounds;
    [window insertSubview:arParentViewController.view atIndex:0];
    
}

- (void) removeSplash:(NSTimer *)theTimer
{
    // poll to see if the camera video stream has started and if so remove the splash screen.
    if ([QCARutils getInstance].videoStreamStarted == YES)
    {
        [splashV removeFromSuperview];
        [theTimer invalidate];
    }
}


- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // don't do this straight after startup - the view controller will do it
    if (firstTime == NO)
    {
        // do the same as when the view is shown
        [arParentViewController viewDidAppear:NO];
    }
    
    firstTime = NO;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // do the same as when the view has dissappeared
    [arParentViewController viewDidDisappear:NO];
}


- (void)applicationWillTerminate:(UIApplication *)application
{
    // AR-specific actions
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Handle any background procedures not related to animation here.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Handle any foreground procedures not related to animation here.
}

- (void)dealloc
{
    [arParentViewController release];
    [window release];
    
    [super dealloc];
}

- (UIView *)viewForCoordinate:(ARCoordinate *)coordinate
{
	CGRect theFrame = CGRectMake(0, 0, BOX_WIDTH, BOX_HEIGHT);
	UIImageView *tempView= [[UIImageView alloc]
							initWithFrame:theFrame];
	
	UILabel *titleLabel = [[UILabel alloc]
						   initWithFrame:CGRectMake(0, 0, BOX_WIDTH, 20.0)];
	titleLabel.backgroundColor = [UIColor
								  colorWithWhite:.3
								  alpha:.8];
	titleLabel.textColor = [UIColor whiteColor];
	titleLabel.textAlignment = UITextAlignmentCenter;
	titleLabel.text = coordinate.title;
	[titleLabel sizeToFit];
	
	titleLabel.frame = CGRectMake(BOX_WIDTH / 2.0 - titleLabel.frame.size.width / 2.0 - 4.0, 0, titleLabel.frame.size.width + 8.0, titleLabel.frame.size.height + 8.0);
	
	
	[tempView addSubview:titleLabel];
	
	[titleLabel release];
	
	return [tempView autorelease];
}

-(void) addARGeoView
{
	ARGeoViewController *viewController = [[ARGeoViewController alloc] init];
    
	viewController.debugMode = YES;
	
	viewController.delegate = self;
	
	viewController.scaleViewsBasedOnDistance = YES;
	viewController.minimumScaleFactor = .5;
	
	viewController.rotateViewsBasedOnPerspective = YES;
	
	// Add some default touch locations to show on the screen
	NSMutableArray *tempLocationArray = [[NSMutableArray alloc]
										 initWithCapacity:10];
	
	CLLocation *tempLocation;
	ARGeoCoordinate *tempCoordinate;
	
	CLLocationCoordinate2D location;
	location.latitude = 39.550051;
	location.longitude = -105.782067;
	
	tempLocation = [[CLLocation alloc]
					initWithCoordinate:location
					altitude:1609.0
					horizontalAccuracy:1.0
					verticalAccuracy:1.0
					timestamp:[NSDate date]];
	tempCoordinate = [ARGeoCoordinate coordinateWithLocation:tempLocation];
//	tempCoordinate.title = @"Touch somewhere bud:)";
	[tempLocationArray addObject:tempCoordinate];
	[tempLocation release];
    
	
	// Add all locations for viewing on the default view
	[viewController addCoordinates:tempLocationArray];
	[tempLocationArray release];
	
	// Define a new center as the reference point for rest of the calculations
	CLLocation *newCenter = [[CLLocation alloc]
							 initWithLatitude:37.41711
							 longitude:-122.02528];
	
	viewController.centerLocation = newCenter;
	[newCenter release];
	
	[viewController startListening];
	
	[window addSubview:viewController.view];
	[window bringSubviewToFront:viewController.view];

}
@end
