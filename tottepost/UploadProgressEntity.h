//
//  UploadProgressEntity.h
//  tottepost
//
//  Created by ISHITOYA Kentaro on 11/12/18.
//  Copyright (c) 2011 cocotomo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PhotoSubmitterManager.h"

@interface UploadProgressEntity : NSObject
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, strong) PhotoSubmitterAccount *account;
@property (nonatomic, readonly) id<PhotoSubmitterProtocol> submitter;
@property (nonatomic, readonly) NSString *progressHash;
@property (strong, nonatomic) NSString *contentHash;

- (id)initWithAccount:(PhotoSubmitterAccount *)account contentHash:(NSString *)contentHash;
+ (NSString *) generateProgressHashWithAccount:(PhotoSubmitterAccount *)account hash:(NSString *)hash;
@end
