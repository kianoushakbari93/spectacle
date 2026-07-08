#import "SpectacleAccessibilityElement.h"

#import <AppKit/AppKit.h>

@implementation SpectacleAccessibilityElement
{
  AXUIElementRef _underlyingElement;
}

- (instancetype)init
{
  if (self = [super init]) {
    _underlyingElement = NULL;
  }

  return self;
}

+ (SpectacleAccessibilityElement *)frontmostApplicationElement
{
  NSRunningApplication *frontmostApplication = [NSWorkspace sharedWorkspace].frontmostApplication;
  if (!frontmostApplication) {
    return nil;
  }
  AXUIElementRef underlyingElement = AXUIElementCreateApplication(frontmostApplication.processIdentifier);
  if (underlyingElement == NULL) {
    return nil;
  }
  SpectacleAccessibilityElement *frontmostApplicationElement = [SpectacleAccessibilityElement new];
  frontmostApplicationElement.underlyingElement = underlyingElement;
  CFRelease(underlyingElement);
  return frontmostApplicationElement;
}

+ (SpectacleAccessibilityElement *)frontmostWindowElement
{
  SpectacleAccessibilityElement *frontmostApplicationElement = [SpectacleAccessibilityElement frontmostApplicationElement];
  SpectacleAccessibilityElement *frontmostWindowElement = nil;
  if (frontmostApplicationElement) {
    frontmostWindowElement = [frontmostApplicationElement elementWithAttribute:kAXFocusedWindowAttribute];
    if (!frontmostWindowElement) {
      NSLog(@"Invalid accessibility element provided, unable to determine the size and position of the window.");
    }
  } else {
    NSLog(@"Failed to find the application that currently has focus.");
  }
  return frontmostWindowElement;
}

- (SpectacleAccessibilityElement *)elementWithAttribute:(CFStringRef)attribute
{
  if (_underlyingElement == NULL) {
    return nil;
  }
  SpectacleAccessibilityElement *newElement = nil;
  AXUIElementRef underlyingElement;
  AXError result = AXUIElementCopyAttributeValue(_underlyingElement, attribute, (CFTypeRef *)&underlyingElement);
  if (result == kAXErrorSuccess) {
    newElement = [SpectacleAccessibilityElement new];
    newElement.underlyingElement = underlyingElement;
    CFRelease(underlyingElement);
  } else {
    NSLog(@"Unable to obtain the accessibility element with the specified attribute: %@ (error code %d)", attribute, result);
  }
  return newElement;
}

- (NSString *)stringValueOfAttribute:(CFStringRef)attribute
{
  if ((_underlyingElement != NULL) && (CFGetTypeID(_underlyingElement) == AXUIElementGetTypeID())) {
    CFTypeRef value;
    AXError result;
    result = AXUIElementCopyAttributeValue(_underlyingElement, attribute, &value);
    if (result == kAXErrorSuccess) {
      if (CFGetTypeID(value) == CFStringGetTypeID()) {
        return CFBridgingRelease(value);
      }
      CFRelease(value);
    } else {
      NSLog(@"There was a problem getting the string value of the specified attribute: %@ (error code %d)", attribute, result);
    }
  }
  return nil;
}

- (AXValueRef)valueOfAttribute:(CFStringRef)attribute type:(AXValueType)type
{
  if ((_underlyingElement != NULL) && (CFGetTypeID(_underlyingElement) == AXUIElementGetTypeID())) {
    CFTypeRef value;
    AXError result;
    result = AXUIElementCopyAttributeValue(_underlyingElement, attribute, (CFTypeRef *)&value);
    if (result == kAXErrorSuccess) {
      if (AXValueGetType(value) == type) {
        return value;
      }
      CFRelease(value);
    } else {
      NSLog(@"There was a problem getting the value of the specified attribute: %@ (error code %d)", attribute, result);
    }
  }
  return NULL;
}

- (void)setValue:(AXValueRef)value forAttribute:(CFStringRef)attribute
{
  if ((_underlyingElement == NULL) || (value == NULL)) {
    NSLog(@"Unable to set the value of the specified attribute: %@", attribute);
    return;
  }
  AXError result = AXUIElementSetAttributeValue(_underlyingElement, attribute, (CFTypeRef *)value);
  if (result != kAXErrorSuccess) {
    NSLog(@"There was a problem setting the value of the specified attribute: %@ (error code %d)", attribute, result);
  }
}

- (CGRect)rectOfElement
{
  CGRect result = CGRectNull;
  AXValueRef positionValue = [self valueOfAttribute:kAXPositionAttribute type:kAXValueCGPointType];
  AXValueRef sizeValue = [self valueOfAttribute:kAXSizeAttribute type:kAXValueCGSizeType];
  CGPoint position;
  CGSize size;
  if ((positionValue != NULL)
      && (sizeValue != NULL)
      && AXValueGetValue(positionValue, kAXValueCGPointType, (void *)&position)
      && AXValueGetValue(sizeValue, kAXValueCGSizeType, (void *)&size)) {
    result = CGRectMake(position.x, position.y, size.width, size.height);
  }
  if (positionValue != NULL) {
    CFRelease(positionValue);
  }
  if (sizeValue != NULL) {
    CFRelease(sizeValue);
  }
  return result;
}

- (void)setRectOfElement:(CGRect)rect
{
  AXValueRef positionRef = AXValueCreate(kAXValueCGPointType, (const void *)&rect.origin);
  AXValueRef sizeRef = AXValueCreate(kAXValueCGSizeType, (const void *)&rect.size);
  if ((positionRef != NULL) && (sizeRef != NULL)) {
    [self setValue:sizeRef forAttribute:kAXSizeAttribute];
    [self setValue:positionRef forAttribute:kAXPositionAttribute];
    [self setValue:sizeRef forAttribute:kAXSizeAttribute];
  }
  if (positionRef != NULL) {
    CFRelease(positionRef);
  }
  if (sizeRef != NULL) {
    CFRelease(sizeRef);
  }
}

+ (CGRect)normalizeCoordinatesOfRect:(CGRect)rect frameOfScreen:(CGRect)frameOfScreen
{
  CGRect frameOfScreenWithMenuBar = [[[NSScreen screens] firstObject] frame];
  rect.origin.y = frameOfScreen.size.height - NSMaxY(rect) + (frameOfScreenWithMenuBar.size.height - frameOfScreen.size.height);
  return rect;
}

- (BOOL)isSheet
{
  return [[self stringValueOfAttribute:kAXRoleAttribute] isEqualToString:(__bridge NSString *)kAXSheetRole];
}

- (BOOL)isSystemDialog
{
  return [[self stringValueOfAttribute:kAXSubroleAttribute] isEqualToString:(__bridge NSString *)kAXSystemDialogSubrole];
}

- (void)dealloc
{
  if (_underlyingElement != NULL) {
    CFRelease(_underlyingElement);
  }
}

- (void)setUnderlyingElement:(AXUIElementRef)underlyingElement
{
  if (underlyingElement != NULL) {
    CFRetain(underlyingElement);
  }
  if (_underlyingElement != NULL) {
    CFRelease(_underlyingElement);
  }
  _underlyingElement = underlyingElement;
}

@end
