//
//  SettingViewController.h
//  tottepost
//
//  Created by ISHITOYA Kentaro on 11/12/11.
//  Copyright (c) 2011 cocotomo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FacebookSettingViewController.h"
#import "PhotoSubmitterManager.h"

/*!
 * setting view controller
 */
@interface SettingTableViewController : UITableViewController<PhotoSubmitterAuthenticationDelegate>{
@protected
    __strong FacebookSettingViewController *facebookSettingViewController_;
    __strong NSMutableDictionary *switches_;
    __strong NSArray *accountTypes_;
}
@end