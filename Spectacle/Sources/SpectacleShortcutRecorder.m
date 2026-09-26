#import "SpectacleShortcutRecorder.h"

#import <Carbon/Carbon.h>

#import "SpectacleShortcut.h"
#import "SpectacleShortcutRecorderDelegate.h"
#import "SpectacleShortcutTranslations.h"
#import "SpectacleShortcutValidation.h"

static const NSTrackingAreaOptions kTrackingAreaOptions = (NSTrackingMouseEnteredAndExited
                                                           | NSTrackingActiveWhenFirstResponder
                                                           | NSTrackingEnabledDuringMouseDrag);

static const NSEventModifierFlags kCocoaModifierFlagsMask = (NSEventModifierFlagControl
                                                             | NSEventModifierFlagOption
                                                             | NSEventModifierFlagShift
                                                             | NSEventModifierFlagCommand);

static const CGFloat kBadgeSize = 16.0f;
static const CGFloat kBadgeInset = 4.0f;

@implementation SpectacleShortcutRecorder
{
  BOOL _isRecording;
  BOOL _isMouseDown;
  BOOL _isMouseAboveBadge;
  NSTrackingArea *_badgeButtonTrackingArea;
  NSTextField *_labelField;
  NSImageView *_badgeImageView;
  void *_shortcutMode;
}

- (instancetype)initWithFrame:(NSRect)frame
{
  if (self = [super initWithFrame:frame]) {
    self.wantsLayer = YES;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    _labelField = [NSTextField labelWithString:@""];
    _labelField.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
    _labelField.alignment = NSTextAlignmentCenter;
    _labelField.lineBreakMode = NSLineBreakByTruncatingTail;
    _labelField.accessibilityElement = NO;
    _labelField.translatesAutoresizingMaskIntoConstraints = NO;
    [_labelField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                          forOrientation:NSLayoutConstraintOrientationHorizontal];
    _badgeImageView = [NSImageView new];
    _badgeImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    _badgeImageView.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:kBadgeSize
                                                                                         weight:NSFontWeightRegular
                                                                                          scale:NSImageSymbolScaleMedium];
    _badgeImageView.accessibilityElement = NO;
    _badgeImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_labelField];
    [self addSubview:_badgeImageView];
    // The label is inset by the badge's footprint on both sides so it stays
    // optically centred in the capsule whether or not the badge is visible.
    CGFloat labelInset = kBadgeSize + kBadgeInset * 2.0f;
    [NSLayoutConstraint activateConstraints:@[
      [_labelField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:labelInset],
      [_labelField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-labelInset],
      [_labelField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [_badgeImageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-kBadgeInset],
      [_badgeImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [_badgeImageView.widthAnchor constraintEqualToConstant:kBadgeSize],
      [_badgeImageView.heightAnchor constraintEqualToConstant:kBadgeSize],
    ]];
    [self _updateAppearance];
  }
  return self;
}

- (NSViewCornerConfiguration *)cornerConfiguration
{
  return NSViewCornerConfiguration.capsuleCornerConfiguration;
}

- (void)viewDidChangeEffectiveCornerRadii
{
  [super viewDidChangeEffectiveCornerRadii];
  self.layer.cornerRadius = self.effectiveCornerRadii.topLeft;
}

- (BOOL)wantsUpdateLayer
{
  return YES;
}

- (void)updateLayer
{
  // Recorders sit on glass cards, so they are drawn as solid capsule wells
  // rather than as nested glass, which would blur into the card behind it.
  NSColor *fillColor = nil;
  if (_isRecording) {
    fillColor = NSColor.controlAccentColor;
  } else if (_isMouseDown && !_isMouseAboveBadge) {
    fillColor = NSColor.secondarySystemFillColor;
  } else {
    fillColor = NSColor.tertiarySystemFillColor;
  }
  self.layer.backgroundColor = fillColor.CGColor;
}

- (void)setShortcut:(SpectacleShortcut *)shortcut
{
  _shortcut = shortcut;
  [self updateTrackingAreas];
  [self _updateAppearance];
}

- (NSView *)hitTest:(NSPoint)point
{
  // Route every click inside the capsule to the recorder itself rather than to
  // its label or badge, which are purely presentational.
  return [self mouse:[self convertPoint:point fromView:self.superview] inRect:self.bounds] ? self : nil;
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)resignFirstResponder
{
  [self _stopRecording];
  return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
  return YES;
}

- (void)mouseDown:(NSEvent *)event
{
  _isMouseDown = YES;
  [self _updateAppearance];
}

- (void)mouseUp:(NSEvent *)event
{
  NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
  _isMouseDown = NO;
  if (_badgeButtonTrackingArea && [self mouse:locationInView inRect:badgeRectInBounds(self.bounds)]) {
    if (_isRecording) {
      [self _stopRecording];
    } else {
      [self _clearShortcut];
    }
  } else if ([self mouse:locationInView inRect:self.bounds]) {
    [self _startRecording];
  } else {
    [self _updateAppearance];
  }
}

- (void)mouseEntered:(NSEvent *)event
{
  _isMouseAboveBadge = event.trackingArea == _badgeButtonTrackingArea;
  [self _updateAppearance];
}

- (void)mouseExited:(NSEvent *)event
{
  _isMouseAboveBadge = event.trackingArea != _badgeButtonTrackingArea;
  [self _updateAppearance];
}

- (void)keyDown:(NSEvent *)event
{
  if (![self performKeyEquivalent:event]) {
    [super keyDown:event];
  }
}

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
  if (self.window.firstResponder != self) {
    return NO;
  }
  NSEventModifierFlags modifierFlags = event.modifierFlags & kCocoaModifierFlagsMask;
  if (event.keyCode == kVK_Escape && modifierFlags == 0) {
    [self _stopRecording];
    return YES;
  }
  NSInteger keyCode = event.keyCode;
  BOOL functionKey = ((keyCode == kVK_F1)  || (keyCode == kVK_F2)  || (keyCode == kVK_F3)  || (keyCode == kVK_F4)  ||
                      (keyCode == kVK_F5)  || (keyCode == kVK_F6)  || (keyCode == kVK_F7)  || (keyCode == kVK_F8)  ||
                      (keyCode == kVK_F9)  || (keyCode == kVK_F10) || (keyCode == kVK_F11) || (keyCode == kVK_F12) ||
                      (keyCode == kVK_F13) || (keyCode == kVK_F14) || (keyCode == kVK_F15) || (keyCode == kVK_F16) ||
                      (keyCode == kVK_F17) || (keyCode == kVK_F18) || (keyCode == kVK_F19) || (keyCode == kVK_F20));
  if (_isRecording && (functionKey || [SpectacleShortcut validCocoaModifiers:modifierFlags])) {
    SpectacleShortcut *shortcut = [[SpectacleShortcut alloc] initWithShortcutName:_shortcutName
                                                                  shortcutKeyCode:keyCode
                                                                shortcutModifiers:modifierFlags];
    NSError *error = nil;
    if ([_shortcutValidation isShortcutValid:shortcut error:&error]) {
      _shortcut = shortcut;
      [_delegate shortcutRecorder:self didReceiveNewShortcut:shortcut];
    } else {
      [[NSAlert alertWithError:error] runModal];
    }
    [self _stopRecording];
    return YES;
  }
  return NO;
}

- (void)flagsChanged:(NSEvent *)event
{
  if (!_isRecording) {
    return;
  }
  [self _updateAppearance];
}

- (void)updateTrackingAreas
{
  [super updateTrackingAreas];
  if (_badgeButtonTrackingArea) {
    [self removeTrackingArea:_badgeButtonTrackingArea];
    _badgeButtonTrackingArea = nil;
  }
  if (_isRecording || _shortcut) {
    _badgeButtonTrackingArea = [[NSTrackingArea alloc] initWithRect:badgeRectInBounds(self.bounds)
                                                            options:kTrackingAreaOptions
                                                              owner:self
                                                           userInfo:nil];
    [self addTrackingArea:_badgeButtonTrackingArea];
  }
}

#pragma mark - Accessibility

- (BOOL)isAccessibilityElement
{
  return YES;
}

- (NSAccessibilityRole)accessibilityRole
{
  return NSAccessibilityButtonRole;
}

- (id)accessibilityValue
{
  return _labelField.stringValue;
}

- (BOOL)accessibilityPerformPress
{
  [self.window makeFirstResponder:self];
  [self _startRecording];
  return YES;
}

#pragma mark - Private

- (void)_startRecording
{
  if (_isRecording) {
    return;
  }
  _isRecording = YES;
  _shortcutMode = PushSymbolicHotKeyMode(kHIHotKeyModeAllDisabled);
  [self updateTrackingAreas];
  [self _updateAppearance];
}

- (void)_stopRecording
{
  if (!_isRecording) {
    return;
  }
  PopSymbolicHotKeyMode(_shortcutMode);
  _isRecording = NO;
  _isMouseAboveBadge = NO;
  [self updateTrackingAreas];
  [self _updateAppearance];
}

- (void)_clearShortcut
{
  [_delegate shortcutRecorder:self didClearExistingShortcut:_shortcut];
  _shortcut = nil;
  _isMouseAboveBadge = NO;
  [self updateTrackingAreas];
  [self _updateAppearance];
}

- (void)_updateAppearance
{
  // While recording, the capsule fills with the accent colour so the active
  // recorder is unmistakable, and its contents switch to the matching white.
  self.needsDisplay = YES;
  _labelField.stringValue = [self _label];
  _labelField.textColor = _isRecording ? NSColor.alternateSelectedControlTextColor : NSColor.labelColor;
  _badgeImageView.image = [self _badgeImage];
  if (_isRecording) {
    _badgeImageView.contentTintColor = [NSColor.alternateSelectedControlTextColor colorWithAlphaComponent:0.8f];
  } else if (_isMouseAboveBadge && _isMouseDown) {
    _badgeImageView.contentTintColor = NSColor.labelColor;
  } else {
    _badgeImageView.contentTintColor = NSColor.tertiaryLabelColor;
  }
}

- (NSImage *)_badgeImage
{
  NSString *symbolName = nil;
  NSString *description = nil;
  if ((_isRecording && !_shortcut) || (!_isRecording && _shortcut)) {
    symbolName = @"xmark.circle.fill";
    description = NSLocalizedString(@"ShortcutRecorderLabelStopRecording", @"The shortcut recorder label displayed when the shorcut recorder is recording a shortcut and the shortcut recorder does not have a previously recorded shortcut");
  } else if (_isRecording) {
    symbolName = @"arrow.uturn.backward.circle.fill";
    description = NSLocalizedString(@"ShortcutRecorderLabelUseExisting", "The shortcut recorder label displayed when the shorcut recorder is recording a shortcut and the shortcut recorder does have a previously recorded shortcut");
  }
  return symbolName ? [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:description] : nil;
}

- (NSString *)_label
{
  NSEventModifierFlags modifierFlags = [NSEvent modifierFlags] & kCocoaModifierFlagsMask;
  if (_isRecording && modifierFlags) {
    return SpectacleTranslateModifiers(modifierFlags);
  }
  if (_isRecording && !_isMouseAboveBadge) {
    return NSLocalizedString(@"ShortcutRecorderLabelEnterShortcut", @"The shortcut recorder label displayed when the shorcut recorder is recording a shortcut");
  } else if (_isRecording && _isMouseAboveBadge && !_shortcut) {
    return NSLocalizedString(@"ShortcutRecorderLabelStopRecording", @"The shortcut recorder label displayed when the shorcut recorder is recording a shortcut and the shortcut recorder does not have a previously recorded shortcut");
  } else if (_isRecording && _isMouseAboveBadge) {
    return NSLocalizedString(@"ShortcutRecorderLabelUseExisting", "The shortcut recorder label displayed when the shorcut recorder is recording a shortcut and the shortcut recorder does have a previously recorded shortcut");
  } else if (_shortcut) {
    return _shortcut.displayString;
  }
  return NSLocalizedString(@"ShortcutRecorderLabelClickToRecord", @"The shortcut recorder label displayed when the shorcut recorder is cleared and ready to record a new shortcut");
}

static NSRect badgeRectInBounds(NSRect bounds)
{
  return NSMakeRect(NSMaxX(bounds) - kBadgeSize - kBadgeInset,
                    floor(NSMidY(bounds) - kBadgeSize / 2.0f),
                    kBadgeSize,
                    kBadgeSize);
}

@end
