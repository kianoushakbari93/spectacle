#import <Cocoa/Cocoa.h>

#import "SpectacleMacros.h"

@interface SpectaclePreferencesSectionView : NSGlassEffectView

- (instancetype)initWithTitle:(NSString *)title
                       labels:(NSArray<NSString *> *)labels
                     controls:(NSArray<NSView *> *)controls NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(NSRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

SPECTACLE_INIT_AND_NEW_UNAVAILABLE

@end
