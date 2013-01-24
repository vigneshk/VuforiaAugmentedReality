#import <Foundation/Foundation.h>
#import "ARGLViewController.h"

@interface ARGeoViewController : ARGLViewController {
	CLLocation *centerLocation;
}

@property (nonatomic, retain) CLLocation *centerLocation;

@end
