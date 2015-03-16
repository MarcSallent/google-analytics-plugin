//UniversalAnalyticsPlugin.m
//Created by Daniel Wilson 2013-09-19

#import "UniversalAnalyticsPlugin.h"
#import "GAI.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"

@implementation UniversalAnalyticsPlugin

- (void) pluginInitialize
{
    _debugMode = false;
    _customDimensions = nil;
    _trackers = nil;
}

- (void) startTrackerWithId: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* accountId = [command.arguments objectAtIndex:0];

    [GAI sharedInstance].dispatchInterval = 10;

    if (!_trackers) {
      _trackers = [[NSMutableDictionary alloc] init];
    }

    id newTracker = [[GAI sharedInstance] trackerWithTrackingId:accountId];
    [_trackers setObject:newTracker forKey:accountId];

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    /* NSLog(@"successfully started GAI tracker"); */
}

- (void) addCustomDimensionsToTrackerWithAccountId: (NSString*)accountId
{
    if (_customDimensions && _customDimensions[accountId]) {
        NSMutableDictionary *dimensionsForTracker = _customDimensions[accountId];

        for (NSString *key in dimensionsForTracker) {
            NSString *value = [dimensionsForTracker objectForKey:key];
            id<GAITracker> tracker = _trackers[accountId];

            /* NSLog(@"Setting tracker dimension slot %@: <%@>", key, value); */
            [tracker set:[GAIFields customDimensionForIndex:[key intValue]] value:value];
        }
    }
}

- (void) debugMode: (CDVInvokedUrlCommand*) command
{
  _debugMode = true;
  [[GAI sharedInstance].logger setLogLevel:kGAILogLevelVerbose];
}

- (void) setUserId: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* userId = [command.arguments objectAtIndex:0];

    if ([_trackers count] < 1) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Tracker not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    for (NSString *accountId in _trackers) {
        id<GAITracker> tracker = _trackers[accountId];
        [tracker set:@"&uid" value: userId];
    }

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) addCustomDimension: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* accountId = [command.arguments objectAtIndex:0];
    NSString* key       = [command.arguments objectAtIndex:1];
    NSString* value     = [command.arguments objectAtIndex:2];

    // _customDimensions is a two level dictionary of accountId -> key -> value
    if (!_customDimensions) {
        _customDimensions = [[NSMutableDictionary alloc] init];
    }

    if (![_customDimensions objectForKey:accountId]) {
        [_customDimensions setObject:[[NSMutableDictionary alloc] init] forKey:accountId];
    }

    _customDimensions[accountId][key] = value;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) trackEvent: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    if ([_trackers count] < 1) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Tracker not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    NSString *category = nil;
    NSString *action = nil;
    NSString *label = nil;
    NSNumber *value = nil;

    if ([command.arguments count] > 0)
        category = [command.arguments objectAtIndex:0];

    if ([command.arguments count] > 1)
        action = [command.arguments objectAtIndex:1];

    if ([command.arguments count] > 2)
        label = [command.arguments objectAtIndex:2];

    if ([command.arguments count] > 3)
        value = [command.arguments objectAtIndex:3];

    for (NSString *accountId in _trackers) {
        id<GAITracker> tracker = _trackers[accountId];

        [self addCustomDimensionsToTrackerWithAccountId:accountId];

        [tracker send:
            [[GAIDictionaryBuilder createEventWithCategory: category //required
                                   action: action //required
                                   label: label
                                   value: value]
            build]];

    }

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) trackException: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    if ([_trackers count] < 1) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Tracker not started"];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
      return;
    }

    NSString *description = nil;
    NSNumber *fatal = nil;

    if ([command.arguments count] > 0)
        description = [command.arguments objectAtIndex:0];

    if ([command.arguments count] > 1)
        fatal = [command.arguments objectAtIndex:1];

    for (NSString *accountId in _trackers) {
        id<GAITracker> tracker = _trackers[accountId];

        [self addCustomDimensionsToTrackerWithAccountId:accountId];

        [tracker send:[[GAIDictionaryBuilder
        createExceptionWithDescription: description
                                         withFatal: fatal] build]];
    }

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) trackView: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    if ([_trackers count] < 1) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Tracker not started"];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
      return;
    }

    NSString* screenName = [command.arguments objectAtIndex:0];

    for (NSString *accountId in _trackers) {
        id<GAITracker> tracker = _trackers[accountId];

        [self addCustomDimensionsToTrackerWithAccountId:accountId];

        NSString* deepLinkUrl = [command.arguments objectAtIndex:1];
        GAIDictionaryBuilder* openParams = [[GAIDictionaryBuilder alloc] init];

        if (![deepLinkUrl isKindOfClass:[NSNull class]]) {
            [[openParams setCampaignParametersFromUrl:deepLinkUrl] build];
        }

        [tracker set:kGAIScreenName value:screenName];
        [tracker send:[[[GAIDictionaryBuilder createScreenView] setAll:[openParams build]] build]];
    }

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) trackTiming: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    if ([_trackers count] < 1) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Tracker not started"];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
      return;
    }

    NSString *category = nil;
    NSNumber *intervalInMilliseconds = nil;
    NSString *name = nil;
    NSString *label = nil;

    if ([command.arguments count] > 0)
        category = [command.arguments objectAtIndex:0];

    if ([command.arguments count] > 1)
        intervalInMilliseconds = [command.arguments objectAtIndex:1];

    if ([command.arguments count] > 2)
        name = [command.arguments objectAtIndex:2];

    if ([command.arguments count] > 3)
        label = [command.arguments objectAtIndex:3];

    for (NSString *accountId in _trackers) {
        id<GAITracker> tracker = _trackers[accountId];

        [self addCustomDimensionsToTrackerWithAccountId:accountId];

        [tracker send:[[GAIDictionaryBuilder
        createTimingWithCategory: category //required
             interval: intervalInMilliseconds //required
               name: name
              label: label] build]];
    }

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) addTransaction: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    if ([_trackers count] < 1) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Tracker not started"];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
      return;
    }

    NSString *transactionId = nil;
    NSString *affiliation = nil;
    NSNumber *revenue = nil;
    NSNumber *tax = nil;
    NSNumber *shipping = nil;
    NSString *currencyCode = nil;


    if ([command.arguments count] > 0)
        transactionId = [command.arguments objectAtIndex:0];

    if ([command.arguments count] > 1)
        affiliation = [command.arguments objectAtIndex:1];

    if ([command.arguments count] > 2)
        revenue = [command.arguments objectAtIndex:2];

    if ([command.arguments count] > 3)
        tax = [command.arguments objectAtIndex:3];

    if ([command.arguments count] > 4)
        shipping = [command.arguments objectAtIndex:4];

    if ([command.arguments count] > 5)
        currencyCode = [command.arguments objectAtIndex:5];

    for (NSString *accountId in _trackers) {
        id<GAITracker> tracker = _trackers[accountId];

        [tracker send:[[GAIDictionaryBuilder createTransactionWithId:transactionId             // (NSString) Transaction ID
                                                         affiliation:affiliation         // (NSString) Affiliation
                                                             revenue:revenue                  // (NSNumber) Order revenue (including tax and shipping)
                                                                 tax:tax                  // (NSNumber) Tax
                                                            shipping:shipping                      // (NSNumber) Shipping
                                                        currencyCode:currencyCode] build]];        // (NSString) Currency code
    }

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}



- (void) addTransactionItem: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    if ([_trackers count] < 1) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Tracker not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    NSString *transactionId = nil;
    NSString *name = nil;
    NSString *sku = nil;
    NSString *category = nil;
    NSNumber *price = nil;
    NSNumber *quantity = nil;
    NSString *currencyCode = nil;


    if ([command.arguments count] > 0)
        transactionId = [command.arguments objectAtIndex:0];

    if ([command.arguments count] > 1)
        name = [command.arguments objectAtIndex:1];

    if ([command.arguments count] > 2)
        sku = [command.arguments objectAtIndex:2];

    if ([command.arguments count] > 3)
        category = [command.arguments objectAtIndex:3];

    if ([command.arguments count] > 4)
        price = [command.arguments objectAtIndex:4];

    if ([command.arguments count] > 5)
        quantity = [command.arguments objectAtIndex:5];

    if ([command.arguments count] > 6)
        currencyCode = [command.arguments objectAtIndex:6];

    for (NSString *accountId in _trackers) {
        id<GAITracker> tracker = _trackers[accountId];

        [tracker send:[[GAIDictionaryBuilder createItemWithTransactionId:transactionId         // (NSString) Transaction ID
                                                                    name:name  // (NSString) Product Name
                                                                     sku:sku           // (NSString) Product SKU
                                                                category:category  // (NSString) Product category
                                                                   price:price               // (NSNumber)  Product price
                                                                quantity:quantity                 // (NSNumber)  Product quantity
                                                            currencyCode:currencyCode] build]];    // (NSString) Currency code
    }

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
