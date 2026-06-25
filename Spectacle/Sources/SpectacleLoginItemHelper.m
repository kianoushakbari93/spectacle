#import "SpectacleLoginItemHelper.h"

#import <ServiceManagement/ServiceManagement.h>

@implementation SpectacleLoginItemHelper

+ (BOOL)isLoginItemEnabledForBundle:(NSBundle *)bundle
{
  return SMAppService.mainAppService.status == SMAppServiceStatusEnabled;
}

+ (void)enableLoginItemForBundle:(NSBundle *)bundle
{
  NSError *error = nil;
  if (![SMAppService.mainAppService registerAndReturnError:&error]) {
    NSLog(@"Unable to enable the login item: %@", error.localizedDescription);
  }
}

+ (void)disableLoginItemForBundle:(NSBundle *)bundle
{
  NSError *error = nil;
  if (![SMAppService.mainAppService unregisterAndReturnError:&error]) {
    NSLog(@"Unable to disable the login item: %@", error.localizedDescription);
  }
}

@end
