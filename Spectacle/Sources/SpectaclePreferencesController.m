#import "SpectaclePreferencesController.h"

#import "SpectacleAccessibilityElement.h"
#import "SpectacleDefaultShortcutHelpers.h"
#import "SpectacleLoginItemHelper.h"
#import "SpectaclePreferencesSectionView.h"
#import "SpectacleRegisteredShortcutValidator.h"
#import "SpectacleShortcut.h"
#import "SpectacleShortcutManager.h"
#import "SpectacleShortcutRecorder.h"
#import "SpectacleShortcutStorage.h"
#import "SpectacleShortcutValidation.h"
#import "SpectacleUtilities.h"
#import "SpectacleWindowPositionManager.h"

static const CGFloat kWindowMargin = 20.0f;
static const CGFloat kFooterPadding = 8.0f;
static const CGFloat kSectionSpacing = 16.0f;
static const CGFloat kShortcutRecorderWidth = 156.0f;
static const CGFloat kShortcutRecorderHeight = 24.0f;

typedef NS_ENUM(NSInteger, SpectacleRunMode) {
  SpectacleRunModeStatusMenu = 0,
  SpectacleRunModeBackground = 1,
};

@interface SpectaclePreferencesSection : NSObject

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSArray<NSString *> *shortcutNames;
@property (nonatomic, copy, readonly) NSArray<NSString *> *labels;

@end

@implementation SpectaclePreferencesSection

+ (instancetype)sectionWithTitle:(NSString *)title shortcuts:(NSArray<NSArray<NSString *> *> *)shortcuts
{
  SpectaclePreferencesSection *section = [SpectaclePreferencesSection new];
  NSMutableArray<NSString *> *shortcutNames = [NSMutableArray new];
  NSMutableArray<NSString *> *labels = [NSMutableArray new];
  for (NSArray<NSString *> *shortcut in shortcuts) {
    [shortcutNames addObject:shortcut.firstObject];
    [labels addObject:shortcut.lastObject];
  }
  section->_title = [title copy];
  section->_shortcutNames = shortcutNames;
  section->_labels = labels;
  return section;
}

@end

// A floating capsule of glass that holds the window's general options.
@interface SpectaclePreferencesFooterView : NSGlassEffectView

@end

@implementation SpectaclePreferencesFooterView

- (NSViewCornerConfiguration *)cornerConfiguration
{
  return NSViewCornerConfiguration.capsuleCornerConfiguration;
}

@end

// The preferences window lays its sections out in two columns.
static NSArray<NSArray<SpectaclePreferencesSection *> *> *SpectaclePreferencesSectionColumns(void)
{
  return @[
    @[
      [SpectaclePreferencesSection sectionWithTitle:NSLocalizedString(@"PreferencesSectionTitleBasics", @"The preferences window title of the Basics section of shortcuts")
                                          shortcuts:@[
                                            @[@"MoveToCenter", NSLocalizedString(@"PreferencesShortcutLabelMoveToCenter", @"The preferences window label for the Center shortcut recorder")],
                                            @[@"MoveToFullscreen", NSLocalizedString(@"PreferencesShortcutLabelMoveToFullscreen", @"The preferences window label for the Fullscreen shortcut recorder")],
                                          ]],
      [SpectaclePreferencesSection sectionWithTitle:NSLocalizedString(@"PreferencesSectionTitleHalves", @"The preferences window title of the Halves section of shortcuts")
                                          shortcuts:@[
                                            @[@"MoveToLeftHalf", NSLocalizedString(@"PreferencesShortcutLabelMoveToLeftHalf", @"The preferences window label for the Left Half shortcut recorder")],
                                            @[@"MoveToRightHalf", NSLocalizedString(@"PreferencesShortcutLabelMoveToRightHalf", @"The preferences window label for the Right Half shortcut recorder")],
                                            @[@"MoveToTopHalf", NSLocalizedString(@"PreferencesShortcutLabelMoveToTopHalf", @"The preferences window label for the Top Half shortcut recorder")],
                                            @[@"MoveToBottomHalf", NSLocalizedString(@"PreferencesShortcutLabelMoveToBottomHalf", @"The preferences window label for the Bottom Half shortcut recorder")],
                                          ]],
      [SpectaclePreferencesSection sectionWithTitle:NSLocalizedString(@"PreferencesSectionTitleCorners", @"The preferences window title of the Corners section of shortcuts")
                                          shortcuts:@[
                                            @[@"MoveToUpperLeft", NSLocalizedString(@"PreferencesShortcutLabelMoveToUpperLeft", @"The preferences window label for the Upper Left shortcut recorder")],
                                            @[@"MoveToLowerLeft", NSLocalizedString(@"PreferencesShortcutLabelMoveToLowerLeft", @"The preferences window label for the Lower Left shortcut recorder")],
                                            @[@"MoveToUpperRight", NSLocalizedString(@"PreferencesShortcutLabelMoveToUpperRight", @"The preferences window label for the Upper Right shortcut recorder")],
                                            @[@"MoveToLowerRight", NSLocalizedString(@"PreferencesShortcutLabelMoveToLowerRight", @"The preferences window label for the Lower Right shortcut recorder")],
                                          ]],
    ],
    @[
      [SpectaclePreferencesSection sectionWithTitle:NSLocalizedString(@"PreferencesSectionTitleDisplaysAndThirds", @"The preferences window title of the Displays & Thirds section of shortcuts")
                                          shortcuts:@[
                                            @[@"MoveToNextDisplay", NSLocalizedString(@"PreferencesShortcutLabelMoveToNextDisplay", @"The preferences window label for the Next Display shortcut recorder")],
                                            @[@"MoveToPreviousDisplay", NSLocalizedString(@"PreferencesShortcutLabelMoveToPreviousDisplay", @"The preferences window label for the Previous Display shortcut recorder")],
                                            @[@"MoveToNextThird", NSLocalizedString(@"PreferencesShortcutLabelMoveToNextThird", @"The preferences window label for the Next Third shortcut recorder")],
                                            @[@"MoveToPreviousThird", NSLocalizedString(@"PreferencesShortcutLabelMoveToPreviousThird", @"The preferences window label for the Previous Third shortcut recorder")],
                                          ]],
      [SpectaclePreferencesSection sectionWithTitle:NSLocalizedString(@"PreferencesSectionTitleResize", @"The preferences window title of the Resize section of shortcuts")
                                          shortcuts:@[
                                            @[@"MakeLarger", NSLocalizedString(@"PreferencesShortcutLabelMakeLarger", @"The preferences window label for the Make Larger shortcut recorder")],
                                            @[@"MakeSmaller", NSLocalizedString(@"PreferencesShortcutLabelMakeSmaller", @"The preferences window label for the Make Smaller shortcut recorder")],
                                          ]],
      [SpectaclePreferencesSection sectionWithTitle:NSLocalizedString(@"PreferencesSectionTitleHistory", @"The preferences window title of the History section of shortcuts")
                                          shortcuts:@[
                                            @[@"UndoLastMove", NSLocalizedString(@"PreferencesShortcutLabelUndoLastMove", @"The preferences window label for the Undo shortcut recorder")],
                                            @[@"RedoLastMove", NSLocalizedString(@"PreferencesShortcutLabelRedoLastMove", @"The preferences window label for the Redo shortcut recorder")],
                                          ]],
    ],
  ];
}

@implementation SpectaclePreferencesController
{
  SpectacleShortcutManager *_shortcutManager;
  SpectacleWindowPositionManager *_windowPositionManager;
  id<SpectacleShortcutStorage> _shortcutStorage;
  NSDictionary<NSString *, SpectacleShortcutRecorder *> *_shortcutRecorders;
  NSButton *_loginItemCheckbox;
  NSPopUpButton *_runModePopUpButton;
}

- (instancetype)initWithShortcutManager:(SpectacleShortcutManager *)shortcutManager
                  windowPositionManager:(SpectacleWindowPositionManager *)windowPositionManager
                        shortcutStorage:(id<SpectacleShortcutStorage>)shortcutStorage
{
  if (self = [super initWithWindow:nil]) {
    _shortcutManager = shortcutManager;
    _windowPositionManager = windowPositionManager;
    _shortcutStorage = shortcutStorage;
    self.window = [self _makeWindow];
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(loadRegisteredShortcuts)
                               name:@"SpectacleShortcutChangedNotification"
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(loadRegisteredShortcuts)
                               name:@"SpectacleRestoreDefaultShortcutsNotification"
                             object:nil];
  }
  return self;
}

- (void)showWindow:(id)sender
{
  // Shortcuts are registered after this controller is created, and login item
  // state can change in System Settings while the window is closed.
  [self loadRegisteredShortcuts];
  BOOL isLoginItemEnabled = [SpectacleLoginItemHelper isLoginItemEnabledForBundle:NSBundle.mainBundle];
  _loginItemCheckbox.state = isLoginItemEnabled ? NSControlStateValueOn : NSControlStateValueOff;
  [super showWindow:sender];
}

- (void)shortcutRecorder:(SpectacleShortcutRecorder *)shortcutRecorder
   didReceiveNewShortcut:(SpectacleShortcut *)shortcut
{
  [_shortcutManager updateShortcut:[shortcut copyWithShortcutAction:^(SpectacleShortcut *shortcut) {
    [self->_windowPositionManager moveFrontmostWindowElement:[SpectacleAccessibilityElement frontmostWindowElement]
                                                      action:shortcut.windowAction];
  }]];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SpectacleShortcutChangedNotification" object:self];
}

- (void)shortcutRecorder:(SpectacleShortcutRecorder *)shortcutRecorder
didClearExistingShortcut:(SpectacleShortcut *)shortcut
{
  [_shortcutManager clearShortcut:shortcut];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"SpectacleShortcutChangedNotification" object:self];
}

- (void)loadRegisteredShortcuts
{
  for (NSString *shortcutName in _shortcutRecorders.allKeys) {
    SpectacleShortcutRecorder *shortcutRecorder = _shortcutRecorders[shortcutName];
    SpectacleShortcut *shortcut = [_shortcutManager shortcutForShortcutName:shortcutName];
    shortcutRecorder.shortcutName = shortcutName;
    shortcutRecorder.shortcut = shortcut;
    shortcutRecorder.delegate = self;
    shortcutRecorder.shortcutValidation =
    [[SpectacleShortcutValidation alloc] initWithShortcutManager:_shortcutManager
                                                      validators:@[
                                                                   [SpectacleRegisteredShortcutValidator new],
                                                                   ]];
  }
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Actions

- (void)_restoreDefaults:(id)sender
{
  [SpectacleUtilities displayRestoreDefaultsAlertWithConfirmationCallback:^() {
    NSArray<SpectacleShortcut *> *shortcuts = SpectacleDefaultShortcutsWithAction(^(SpectacleShortcut *shortcut) {
      [self->_windowPositionManager moveFrontmostWindowElement:[SpectacleAccessibilityElement frontmostWindowElement]
                                                        action:shortcut.windowAction];
    });
    [self->_shortcutManager updateShortcuts:shortcuts];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SpectacleRestoreDefaultShortcutsNotification"
                                                        object:self];
  }];
}

- (void)_toggleLoginItem:(id)sender
{
  NSBundle *applicationBundle = NSBundle.mainBundle;
  if (_loginItemCheckbox.state == NSControlStateValueOn) {
    [SpectacleLoginItemHelper enableLoginItemForBundle:applicationBundle];
  } else {
    [SpectacleLoginItemHelper disableLoginItemForBundle:applicationBundle];
  }
}

- (void)_toggleStatusItem:(id)sender
{
  NSString *notificationName = @"SpectacleStatusItemEnabledNotification";
  BOOL isStatusItemEnabled = YES;
  __block BOOL statusItemStateChanged = YES;
  NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;
  if ([userDefaults boolForKey:@"StatusItemEnabled"] == ([[sender selectedItem] tag] == SpectacleRunModeStatusMenu)) {
    return;
  }
  if ([sender selectedItem].tag != SpectacleRunModeStatusMenu) {
    notificationName = @"SpectacleStatusItemDisabledNotification";
    isStatusItemEnabled = NO;
    if (![userDefaults boolForKey:@"BackgroundAlertSuppressed"]) {
      [SpectacleUtilities displayRunningInBackgroundAlertWithCallback:^(BOOL isConfirmed, BOOL isSuppressed) {
        if (!isConfirmed) {
          statusItemStateChanged = NO;
          [sender selectItemWithTag:SpectacleRunModeStatusMenu];
        }
        [userDefaults setBool:isSuppressed forKey:@"BackgroundAlertSuppressed"];
      }];
    }
  }
  if (statusItemStateChanged) {
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self];
    [userDefaults setBool:isStatusItemEnabled forKey:@"StatusItemEnabled"];
  }
}

#pragma mark - Window construction

- (NSWindow *)_makeWindow
{
  NSMutableDictionary<NSString *, SpectacleShortcutRecorder *> *shortcutRecorders = [NSMutableDictionary new];
  NSMutableArray<NSStackView *> *columns = [NSMutableArray new];
  for (NSArray<SpectaclePreferencesSection *> *sections in SpectaclePreferencesSectionColumns()) {
    NSMutableArray<SpectaclePreferencesSectionView *> *sectionViews = [NSMutableArray new];
    for (SpectaclePreferencesSection *section in sections) {
      NSMutableArray<SpectacleShortcutRecorder *> *recorders = [NSMutableArray new];
      for (NSString *shortcutName in section.shortcutNames) {
        SpectacleShortcutRecorder *recorder = [self _makeShortcutRecorder];
        shortcutRecorders[shortcutName] = recorder;
        [recorders addObject:recorder];
      }
      [sectionViews addObject:[[SpectaclePreferencesSectionView alloc] initWithTitle:section.title
                                                                              labels:section.labels
                                                                            controls:recorders]];
    }
    NSStackView *column = [NSStackView stackViewWithViews:sectionViews];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.spacing = kSectionSpacing;
    for (SpectaclePreferencesSectionView *sectionView in sectionViews) {
      [sectionView.widthAnchor constraintEqualToAnchor:column.widthAnchor].active = YES;
    }
    [columns addObject:column];
  }
  _shortcutRecorders = shortcutRecorders;

  NSStackView *columnsView = [NSStackView stackViewWithViews:columns];
  columnsView.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  columnsView.alignment = NSLayoutAttributeTop;
  columnsView.distribution = NSStackViewDistributionFillEqually;
  columnsView.spacing = kSectionSpacing;

  NSView *modifierLegendView = [self _makeModifierLegendView];
  NSView *footerView = [self _makeFooterView];

  NSView *containerContentView = [NSView new];
  for (NSView *view in @[columnsView, modifierLegendView, footerView]) {
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [containerContentView addSubview:view];
  }
  // A single glass container batches every glass surface in the window into
  // one rendering pass. Its zero spacing keeps neighbouring cards from merging.
  NSGlassEffectContainerView *glassContainerView = [NSGlassEffectContainerView new];
  glassContainerView.contentView = containerContentView;

  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSZeroRect
                                                 styleMask:(NSWindowStyleMaskTitled
                                                            | NSWindowStyleMaskClosable
                                                            | NSWindowStyleMaskMiniaturizable
                                                            | NSWindowStyleMaskFullSizeContentView)
                                                   backing:NSBackingStoreBuffered
                                                     defer:YES];
  window.releasedWhenClosed = NO;
  window.titlebarAppearsTransparent = YES;
  window.title = [@"Spectacle " stringByAppendingString:SpectacleUtilities.applicationVersion];
  window.contentView = glassContainerView;
  NSLayoutGuide *safeArea = glassContainerView.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [columnsView.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:kFooterPadding],
    [columnsView.leadingAnchor constraintEqualToAnchor:containerContentView.leadingAnchor constant:kWindowMargin],
    [columnsView.trailingAnchor constraintEqualToAnchor:containerContentView.trailingAnchor constant:-kWindowMargin],
    [modifierLegendView.topAnchor constraintEqualToAnchor:columnsView.bottomAnchor constant:kWindowMargin],
    [modifierLegendView.centerXAnchor constraintEqualToAnchor:containerContentView.centerXAnchor],
    [footerView.topAnchor constraintEqualToAnchor:modifierLegendView.bottomAnchor constant:kWindowMargin],
    [footerView.leadingAnchor constraintEqualToAnchor:containerContentView.leadingAnchor constant:kWindowMargin],
    [footerView.trailingAnchor constraintEqualToAnchor:containerContentView.trailingAnchor constant:-kWindowMargin],
    [footerView.bottomAnchor constraintEqualToAnchor:containerContentView.bottomAnchor constant:-kWindowMargin],
  ]];
  [window setContentSize:glassContainerView.fittingSize];
  [window center];
  return window;
}

- (SpectacleShortcutRecorder *)_makeShortcutRecorder
{
  SpectacleShortcutRecorder *recorder = [SpectacleShortcutRecorder new];
  recorder.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [recorder.widthAnchor constraintEqualToConstant:kShortcutRecorderWidth],
    [recorder.heightAnchor constraintEqualToConstant:kShortcutRecorderHeight],
  ]];
  return recorder;
}

- (NSView *)_makeModifierLegendView
{
  NSArray<NSArray<NSString *> *> *modifiers = @[
    @[@"control", NSLocalizedString(@"PreferencesModifierLabelControl", @"The preferences window modifier key legend label for the Control key")],
    @[@"option", NSLocalizedString(@"PreferencesModifierLabelOption", @"The preferences window modifier key legend label for the Option key")],
    @[@"shift", NSLocalizedString(@"PreferencesModifierLabelShift", @"The preferences window modifier key legend label for the Shift key")],
    @[@"command", NSLocalizedString(@"PreferencesModifierLabelCommand", @"The preferences window modifier key legend label for the Command key")],
  ];
  NSFont *font = [NSFont systemFontOfSize:NSFont.systemFontSize];
  NSMutableArray<NSView *> *items = [NSMutableArray new];
  for (NSArray<NSString *> *modifier in modifiers) {
    NSImageView *symbolView = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:modifier.firstObject
                                                                        accessibilityDescription:nil]];
    symbolView.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:font.pointSize
                                                                                    weight:NSFontWeightMedium];
    symbolView.contentTintColor = NSColor.secondaryLabelColor;
    NSTextField *nameField = [NSTextField labelWithString:modifier.lastObject];
    nameField.font = font;
    nameField.textColor = NSColor.secondaryLabelColor;
    NSStackView *item = [NSStackView stackViewWithViews:@[symbolView, nameField]];
    item.spacing = 5.0f;
    [items addObject:item];
  }
  NSStackView *legendView = [NSStackView stackViewWithViews:items];
  legendView.spacing = 24.0f;
  return legendView;
}

- (NSView *)_makeFooterView
{
  _loginItemCheckbox = [NSButton checkboxWithTitle:NSLocalizedString(@"PreferencesCheckboxTitleLaunchAtLogin", @"The preferences window checkbox that launches Spectacle at login")
                                            target:self
                                            action:@selector(_toggleLoginItem:)];

  NSTextField *runModeLabel = [NSTextField labelWithString:NSLocalizedString(@"PreferencesLabelRunMode", @"The preferences window label preceding the run mode pop up button, e.g. \"Run\" \"in the status menu\"")];
  _runModePopUpButton = [NSPopUpButton new];
  _runModePopUpButton.borderShape = NSControlBorderShapeCapsule;
  [_runModePopUpButton addItemWithTitle:NSLocalizedString(@"PreferencesMenuItemTitleRunInStatusMenu", @"The preferences window run mode option that shows Spectacle in the status menu")];
  _runModePopUpButton.lastItem.tag = SpectacleRunModeStatusMenu;
  [_runModePopUpButton addItemWithTitle:NSLocalizedString(@"PreferencesMenuItemTitleRunInBackground", @"The preferences window run mode option that runs Spectacle as a background application")];
  _runModePopUpButton.lastItem.tag = SpectacleRunModeBackground;
  _runModePopUpButton.target = self;
  _runModePopUpButton.action = @selector(_toggleStatusItem:);
  _runModePopUpButton.accessibilityLabel = runModeLabel.stringValue;
  BOOL isStatusItemEnabled = [NSUserDefaults.standardUserDefaults boolForKey:@"StatusItemEnabled"];
  [_runModePopUpButton selectItemWithTag:isStatusItemEnabled ? SpectacleRunModeStatusMenu : SpectacleRunModeBackground];

  NSButton *restoreDefaultsButton = [NSButton buttonWithTitle:NSLocalizedString(@"PreferencesButtonTitleRestoreDefaults", @"The preferences window button that restores the default shortcuts")
                                                       target:self
                                                       action:@selector(_restoreDefaults:)];
  restoreDefaultsButton.bezelStyle = NSBezelStyleGlass;
  restoreDefaultsButton.borderShape = NSControlBorderShapeCapsule;

  NSStackView *runModeView = [NSStackView stackViewWithViews:@[runModeLabel, _runModePopUpButton]];
  runModeView.spacing = 6.0f;
  runModeView.alignment = NSLayoutAttributeFirstBaseline;

  NSStackView *footerStackView = [NSStackView new];
  [footerStackView addView:_loginItemCheckbox inGravity:NSStackViewGravityLeading];
  [footerStackView addView:runModeView inGravity:NSStackViewGravityLeading];
  [footerStackView addView:restoreDefaultsButton inGravity:NSStackViewGravityTrailing];
  [footerStackView setCustomSpacing:kWindowMargin afterView:_loginItemCheckbox];
  footerStackView.alignment = NSLayoutAttributeCenterY;
  footerStackView.spacing = kSectionSpacing;
  // Controls sit an even distance from the capsule's edge so their own capsule
  // shapes stay concentric with it.
  footerStackView.edgeInsets = NSEdgeInsetsMake(kFooterPadding, kFooterPadding * 2.0f, kFooterPadding, kFooterPadding);

  NSGlassEffectView *footerView = [SpectaclePreferencesFooterView new];
  footerView.contentView = footerStackView;
  footerView.effectIsInteractive = YES;
  return footerView;
}

@end
