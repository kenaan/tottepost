//
//  PhotoSubmitter.m
//  tottepost
//
//  Created by ISHITOYA Kentaro on 11/12/13.
//  Copyright (c) 2011 cocotomo. All rights reserved.
//

#import "PhotoSubmitterManager.h"
#import "UIImage+EXIF.h"

/*!
 * singleton instance
 */
static PhotoSubmitterManager* TottePostPhotoSubmitterSingletonInstance;

//-----------------------------------------------------------------------------
//Private Implementations
//-----------------------------------------------------------------------------
@interface PhotoSubmitterManager(PrivateImplementation)
- (void) setupInitialState;
@end

@implementation PhotoSubmitterManager(PrivateImplementation)
-(void)setupInitialState{
    submitters_ = [[NSMutableDictionary alloc] init];
    supportedTypes_ = [NSMutableArray arrayWithObjects:
                       [NSNumber numberWithInt: PhotoSubmitterTypeFacebook],
                       [NSNumber numberWithInt: PhotoSubmitterTypeTwitter],
                       [NSNumber numberWithInt: PhotoSubmitterTypeFlickr],
                       [NSNumber numberWithInt: PhotoSubmitterTypeDropbox],
                       [NSNumber numberWithInt: PhotoSubmitterTypeFile], nil];
    operationQueue_ = [[NSOperationQueue alloc] init];
    operationQueue_.maxConcurrentOperationCount = 6;
    self.submitPhotoWithOperations = NO;
    [self loadSubmitters];
}
@end

//-----------------------------------------------------------------------------
//Public Implementations
//-----------------------------------------------------------------------------

@implementation PhotoSubmitterManager
@synthesize supportedTypes = supportedTypes_;
@synthesize submitPhotoWithOperations;
@synthesize location = location_;

/*!
 * initializer
 */
- (id)init{
    self = [super init];
    if(self){
        [self setupInitialState];
    }
    return self;
}

/*!
 * get submitter
 */
- (id<PhotoSubmitterProtocol>)submitterForType:(PhotoSubmitterType)type{
    id <PhotoSubmitterProtocol> submitter = [submitters_ objectForKey:[NSNumber numberWithInt:type]];
    if(submitter){
        return submitter;
    }
    switch (type) {
        case PhotoSubmitterTypeFacebook:
            submitter = [[FacebookPhotoSubmitter alloc] init];
            break;
        case PhotoSubmitterTypeTwitter:
            submitter = [[TwitterPhotoSubmitter alloc] init];
            break;
        case PhotoSubmitterTypeFlickr:
            submitter = [[FlickrPhotoSubmitter alloc] init];
            break;
        case PhotoSubmitterTypeDropbox:
            submitter = [[DropboxPhotoSubmitter alloc] init];
            break;
        case PhotoSubmitterTypeFile:
            submitter = [[FilePhotoSubmitter alloc] init];
            break;
        default:
            break;
    }
    if(submitter){
        [submitters_ setObject:submitter forKey:[NSNumber numberWithInt:type]];
    }
    [submitter addPhotoDelegate:self];
    return submitter;
}

/*!
 * submit photo to social app
 */
- (void)submitPhoto:(PhotoSubmitterImageEntity *)photo{
    if(self.enableGeoTagging){
        photo.location = self.location;
    }
    [photo applyMetadata];
    for(NSNumber *key in submitters_){
        id<PhotoSubmitterProtocol> submitter = [submitters_ objectForKey:key];
        if([submitter isLogined]){
            if(self.submitPhotoWithOperations && submitter.isConcurrent){
                PhotoSubmitterOperation *operation = [[PhotoSubmitterOperation alloc] initWithSubmitter:submitter photo:photo];
                [operationQueue_ addOperation:operation];
            }else{
                [submitter submitPhoto:photo andOperationDelegate:nil];
            }
        }
    }
}

/*!
 * submit photo with filepath and comment
 */
/*- (void)submitPhotoWithFilePath:(NSString *)path comment:(NSString *)comment{
    NSData *data = [NSData dataWithContentsOfFile:path];
    if(self.enableGeoTagging){
        data = [UIImage geoTaggedData:data withLocation:location_ andComment:comment];
    }
    NSDictionary *metadata = [UIImage extractMetadata:data];
    [self submitPhotoWithData:data metadata:metadata comment:comment];
}*/

/*!
 * set authentication delegate to submitters
 */
- (void)setAuthenticationDelegate:(id<PhotoSubmitterAuthenticationDelegate>)delegate{
    for(NSNumber *key in submitters_){
        id<PhotoSubmitterProtocol> submitter = [submitters_ objectForKey:key];
        submitter.authDelegate = delegate;
    }
}

/*!
 * set photo delegate to submitters
 */
- (void)setPhotoDelegate:(id<PhotoSubmitterPhotoDelegate>)delegate{
    for(NSNumber *key in submitters_){
        id<PhotoSubmitterProtocol> submitter = [submitters_ objectForKey:key];
        [submitter addPhotoDelegate: delegate];
    }
}

/*!
 * load selected submitters
 */
- (void)loadSubmitters{
    for (NSNumber *t in supportedTypes_){
        PhotoSubmitterType type = (PhotoSubmitterType)[t intValue];
        [self submitterForType:type];
    }
}

/*!
 * on url loaded
 */
- (BOOL)didOpenURL:(NSURL *)url{
    for(NSNumber *key in submitters_){
        id<PhotoSubmitterProtocol> submitter = [submitters_ objectForKey:key];
        if([submitter isProcessableURL:url]){
            return [submitter didOpenURL:url];
        }
    }
    return NO; 
}

/*!
 * get uploadOperationCount
 */
- (int)uploadOperationCount{
    return uploadOperationCount_;
}

/*!
 * get number of enabled Submitters
 */
- (int)enabledSubmitterCount{
    int i = 0;
    for(NSNumber *key in submitters_){
        id<PhotoSubmitterProtocol> submitter = [submitters_ objectForKey:key];
        if(submitter.isEnabled){
            i++;
        }
    }
    return i;
}

/*!
 * geo tagging enabled
 */
- (BOOL)enableGeoTagging{
    return geoTaggingEnabled_; 
}

/*!
 * set enable geo tagging
 */
- (void)setEnableGeoTagging:(BOOL)enableGeoTagging{
    if(locationManager_ == nil){
        locationManager_ = [[CLLocationManager alloc] init];
        locationManager_.delegate = self;
        locationManager_.desiredAccuracy = kCLLocationAccuracyBest;
        locationManager_.distanceFilter = kCLDistanceFilterNone; 
        if(enableGeoTagging){
            [locationManager_ startUpdatingLocation];
        }
    }else if(enableGeoTagging != geoTaggingEnabled_){
        if(enableGeoTagging){
            [locationManager_ startUpdatingLocation];
        }else{
            [locationManager_ stopUpdatingLocation];
        }
    }
    geoTaggingEnabled_ = enableGeoTagging;
}

/*!
 * location did changed
 */
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation{
    location_ = newLocation;
    //NSLog(@"%@, %@", location_.coordinate.longitude, location_.coordinate.latitude);
}

/*!
 * requires network
 */
- (BOOL)requiresNetwork{
    for(NSNumber *key in submitters_){
        id<PhotoSubmitterProtocol> submitter = [submitters_ objectForKey:key];
        if(submitter.isEnabled && submitter.requiresNetwork){
            return YES;
        }
    }
    return NO;
}

#pragma mark -
#pragma mark PhotoSubmitterPhotoDelegate methods
/*!
 * upload started
 */
- (void)photoSubmitter:(id<PhotoSubmitterProtocol>)photoSubmitter willStartUpload:(NSString *)imageHash{
    uploadOperationCount_ ++;
}

/*!
 * upload finished
 */
- (void)photoSubmitter:(id<PhotoSubmitterProtocol>)photoSubmitter didSubmitted:(NSString *)imageHash suceeded:(BOOL)suceeded message:(NSString *)message{
    uploadOperationCount_ --;
}

/*!
 * progress changed
 */
- (void)photoSubmitter:(id<PhotoSubmitterProtocol>)photoSubmitter didProgressChanged:(NSString *)imageHash progress:(CGFloat)progress{
    //do nothing
}

#pragma mark -
#pragma mark static methods
/*!
 * singleton method
 */
+ (PhotoSubmitterManager *)getInstance{
    if(TottePostPhotoSubmitterSingletonInstance == nil){
        TottePostPhotoSubmitterSingletonInstance = [[PhotoSubmitterManager alloc]init];
    }
    return TottePostPhotoSubmitterSingletonInstance;
}

/*!
 * get submitter
 */
+ (id<PhotoSubmitterProtocol>)submitterForType:(PhotoSubmitterType)type{
    return [[PhotoSubmitterManager getInstance] submitterForType:type];
}
@end
