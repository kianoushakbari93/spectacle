#import "SpectaclePreferencesSectionView.h"

static const CGFloat kSectionPadding = 16.0f;
static const CGFloat kSectionMinimumCornerRadius = 16.0f;

@implementation SpectaclePreferencesSectionView

- (instancetype)initWithTitle:(NSString *)title
                       labels:(NSArray<NSString *> *)labels
                     controls:(NSArray<NSView *> *)controls
{
  if (self = [super initWithFrame:NSZeroRect]) {
    NSTextField *titleField = [NSTextField labelWithString:title];
    titleField.font = [NSFont preferredFontForTextStyle:NSFontTextStyleHeadline options:@{}];
    titleField.textColor = NSColor.secondaryLabelColor;
    titleField.accessibilityRole = NSAccessibilityStaticTextRole;
    NSMutableArray<NSArray<NSView *> *> *rows = [NSMutableArray new];
    [labels enumerateObjectsUsingBlock:^(NSString *label, NSUInteger index, BOOL *stop) {
      NSTextField *labelField = [NSTextField labelWithString:label];
      labelField.lineBreakMode = NSLineBreakByTruncatingTail;
      controls[index].accessibilityLabel = label;
      [rows addObject:@[labelField, controls[index]]];
    }];
    NSGridView *gridView = [NSGridView gridViewWithViews:rows];
    gridView.rowSpacing = 8.0f;
    gridView.columnSpacing = 12.0f;
    gridView.rowAlignment = NSGridRowAlignmentNone;
    gridView.yPlacement = NSGridCellPlacementCenter;
    [gridView columnAtIndex:0].xPlacement = NSGridCellPlacementLeading;
    [gridView columnAtIndex:1].xPlacement = NSGridCellPlacementTrailing;
    NSStackView *stackView = [NSStackView stackViewWithViews:@[titleField, gridView]];
    stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    stackView.alignment = NSLayoutAttributeLeading;
    stackView.spacing = 10.0f;
    stackView.edgeInsets = NSEdgeInsetsMake(kSectionPadding - 2.0f, kSectionPadding, kSectionPadding, kSectionPadding);
    [gridView.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor constant:-kSectionPadding].active = YES;
    self.contentView = stackView;
    self.effectIsInteractive = YES;
    self.accessibilityElement = YES;
    self.accessibilityRole = NSAccessibilityGroupRole;
    self.accessibilityLabel = title;
  }
  return self;
}

- (NSViewCornerConfiguration *)cornerConfiguration
{
  return [NSViewCornerConfiguration configurationWithUniformRadius:
          [NSViewCornerRadius containerConcentricRadiusWithMinimum:kSectionMinimumCornerRadius]];
}

@end
