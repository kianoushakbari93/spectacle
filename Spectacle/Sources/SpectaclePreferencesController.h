#import <Cocoa/Cocoa.h>

#import "SpectacleShortcutRecorderDelegate.h"

@class SpectacleShortcutManager;
@class SpectacleWindowPositionManager;

@protocol SpectacleShortcutStorage;

@interface SpectaclePreferencesController : NSWindowController <SpectacleShortcutRecorderDelegate>

- (instancetype)initWithShortcutManager:(SpectacleShortcutManager *)shortcutManager
                  windowPositionManager:(SpectacleWindowPositionManager *)windowPositionManager
                        shortcutStorage:(id<SpectacleShortcutStorage>)shortcutStorage;

- (void)loadRegisteredShortcuts;

@end
