//
//  TottePostSettings.m
//  tottepost
//
//  Created by ISHITOYA Kentaro on 11/12/21.
//  Copyright (c) 2011 cocotomo. All rights reserved.
//

#import "TottePostSettings.h"

/*!
 * singleton instance
 */
static TottePostSettings* TottePostSettingsSingletonInstance;

#define TPS_KEY_IMMEDIATE_POST_ENABLED @"immediatePostEnabled"

//-----------------------------------------------------------------------------
//Private Implementations
//-----------------------------------------------------------------------------
@interface TottePostSettings(PrivateImplementation)
- (void) writeSetting:(NSString *)key value:(NSValue *)value;
- (NSValue *)readSetting:(NSString *)key;
@end

@implementation TottePostSettings(PrivateImplementation)
/*!
 * write settings to user defaults
 */
- (void)writeSetting:(NSString *)key value:(NSValue *)value{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:value forKey:key];
    [defaults synchronize];
}

/*!
 * read settings from user defaults
 */
- (NSValue *)readSetting:(NSString *)key{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults valueForKey:key];
}
@end

//-----------------------------------------------------------------------------
//Public Implementations
//----------------------------------------------------------------------------
@implementation TottePostSettings
#pragma mark -
#pragma mark values
/*!
 * get immediate post enabled
 */
- (BOOL)immediatePostEnabled{
    NSNumber *value = (NSNumber *)[self readSetting:TPS_KEY_IMMEDIATE_POST_ENABLED];
    if(value == nil){
        return NO;
    }
    return [value boolValue];
}

/*!
 * set immediate post enabled
 */
- (void)setImmediatePostEnabled:(BOOL)immediatePostEnabled{
    [self writeSetting:TPS_KEY_IMMEDIATE_POST_ENABLED value:[NSNumber numberWithBool:immediatePostEnabled]];
}

#pragma mark -
#pragma mark static methods
/*!
 * singleton method
 */
+ (TottePostSettings *)getInstance{
    if(TottePostSettingsSingletonInstance == nil){
        TottePostSettingsSingletonInstance = [[TottePostSettings alloc] init];
    }
    return TottePostSettingsSingletonInstance;
}
@end