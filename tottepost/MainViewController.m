//
//  MainViewController.m
//  tottepost mainview controller
//
//  Created by Ken Watanabe on 11/12/10.
//  Copyright (c) 2011 cocotomo. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "MainViewController.h"
#import "Reachability.h"
#import "TottePostSettings.h"
#import "MainViewControllerConstants.h"
#import "TTLang.h"
#import "UIColor-Expanded.h"

//-----------------------------------------------------------------------------
//Private Implementations
//-----------------------------------------------------------------------------
@interface MainViewController(PrivateImplementation)
- (void) setupInitialState: (CGRect)aFrame;
- (void) didSettingButtonTapped: (id)sender;
- (void) didPostButtonTapped: (id)sender;
- (void) didPostCancelButtonTapped: (id)sender;
- (void) didCameraButtonTapped: (id)sender;
- (void) updateCoordinates;
- (BOOL) checkForConnection;
- (void) previewPhoto:(PhotoSubmitterImageEntity *)photo;
- (void) closePreview;
- (void) postPhoto:(PhotoSubmitterImageEntity *)photo;
- (void) changeCenterButtonTo: (UIBarButtonItem *)toButton;
- (void) updateCameraController;
- (void) createCameraController;
@end

@implementation MainViewController(PrivateImplementation)
#pragma mark -
#pragma mark private methods
/*!
 * Initialize view controller
 */
- (void) setupInitialState: (CGRect) aFrame{
    aFrame.origin.y = 0;
    self.view.frame = aFrame;
    self.view.backgroundColor = [UIColor clearColor];
    refreshCameraNeeded_ = NO;
    [UIApplication sharedApplication].statusBarHidden = YES;
    
    //photo submitter setting
    [[PhotoSubmitterManager getInstance] setPhotoDelegate:self];
    [PhotoSubmitterManager getInstance].submitPhotoWithOperations = YES;
    
    //setting view
    settingViewController_ = 
        [[SettingTableViewController alloc] init];
    settingNavigationController_ = [[UINavigationController alloc] initWithRootViewController:settingViewController_];
    settingNavigationController_.modalPresentationStyle = UIModalPresentationFormSheet;
    settingNavigationController_.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    settingViewController_.delegate = self;
    
    //preview image view
    previewImageView_ = [[PreviewPhotoView alloc] initWithFrame:CGRectZero];
    previewImageView_.delegate = self;
    
    //progress view
    progressTableViewController_ = [[ProgressTableViewController alloc] initWithFrame:CGRectZero andProgressSize:CGSizeMake(MAINVIEW_PROGRESS_WIDTH, MAINVIEW_PROGRESS_HEIGHT)];
    
    //add tool bar
    toolbar_ = [[UIToolbar alloc] initWithFrame:CGRectZero];
    toolbar_.barStyle = UIBarStyleBlack;
    
    //camera button
    UIButton *customView = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, MAINVIEW_CAMERA_BUTTON_WIDTH, 39)];
    [customView setBackgroundImage:[UIImage imageNamed:@"camera.png"]forState:UIControlStateNormal];
    [customView addTarget:self action:@selector(didCameraButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    cameraButton_ = [[UIBarButtonItem alloc]initWithCustomView:customView];
    cameraButton_.style = UIBarButtonItemStyleBordered;
    
    //comment button
    commentButton_ = [[UIBarButtonItem alloc] init];
        
    //setting button
    settingButton_ = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"setting.png"] style:UIBarButtonItemStylePlain target:self action:@selector(didSettingButtonTapped:)];
    
    //post button
    postButton_ = [[UIBarButtonItem alloc] initWithTitle:[TTLang lstr:@"Main_Post"] style:UIBarButtonItemStyleBordered target:self action:@selector(didPostButtonTapped:)];

    //cancel button
    postCancelButton_ = [[UIBarButtonItem alloc] initWithTitle:[TTLang lstr:@"Main_Cancel"] style:UIBarButtonItemStyleBordered target:self action:@selector(didPostCancelButtonTapped:)];
    
    //spacer for centalize camera button 
    flexSpace_ = [[UIBarButtonItem alloc]
                  initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                  target:nil
                  action:nil];
    UIBarButtonItem* spacer =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    [toolbar_ setItems:[NSArray arrayWithObjects:commentButton_,spacer, cameraButton_, spacer, settingButton_, nil]];
    
    //setting indicator view
    settingIndicatorView_ = [[SettingIndicatorView alloc] initWithFrame:CGRectZero];
    
    //progress summary
    progressSummaryView_ = [[ProgressSummaryView alloc] initWithFrame:CGRectZero];
    [[PhotoSubmitterManager getInstance] setPhotoDelegate:progressSummaryView_];
    [PhotoSubmitterManager getInstance].enableGeoTagging = 
      [TottePostSettings getInstance].gpsEnabled;
    if([UIDevice currentDevice].orientation == UIDeviceOrientationPortraitUpsideDown){
        orientation_ = UIInterfaceOrientationPortraitUpsideDown;
    }else{
        orientation_ = UIInterfaceOrientationPortrait;
    }
    lastOrientation_ = orientation_;
}

/*!
 * on setting button tapped, open setting view
 */
- (void) didSettingButtonTapped:(id)sender{
    [UIApplication sharedApplication].statusBarHidden = NO;
    [self presentModalViewController:settingNavigationController_ animated:YES];
    settingViewPresented_ = YES;
}

/*!
 * on comment button tapped, switch toggle comment post
 */
- (void) didCommentButtonTapped:(id)sender{
    [TottePostSettings getInstance].commentPostEnabled = ![TottePostSettings getInstance].commentPostEnabled;
    [self updateCoordinates];
}

#pragma mark -
#pragma mark coordinates
/*!
 * did rotate
 */
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    imagePicker_.showsCameraControls = YES;
}

/*!
 * will rotate
 */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    imagePicker_.showsCameraControls = NO;
    if(toInterfaceOrientation == UIInterfaceOrientationPortrait ||
       toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown ||
       toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
       toInterfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        orientation_ = toInterfaceOrientation;
    }
    
    if(orientation_ == lastOrientation_)
    {
        return;
    }
    lastOrientation_ = orientation_;
    [self updateCoordinates];
}

/*!
 * update control coodinates
 */
- (void)updateCoordinates{ 
    CGRect frame = self.view.frame;
    CGRect screen = [UIScreen mainScreen].bounds;
    if(UIInterfaceOrientationIsLandscape(orientation_)){
        frame = CGRectMake(0, 0, screen.size.height, screen.size.width);
    }else if(UIInterfaceOrientationIsPortrait(orientation_)){
        frame = CGRectMake(0, 0, screen.size.width, screen.size.height);
    }
    
    [previewImageView_ updateWithFrame:frame];
    
    //progress view
    [progressTableViewController_ updateWithFrame:CGRectMake(frame.size.width - MAINVIEW_PROGRESS_WIDTH - MAINVIEW_PROGRESS_PADDING_X, MAINVIEW_PROGRESS_PADDING_Y, MAINVIEW_PROGRESS_WIDTH, frame.size.height - MAINVIEW_PROGRESS_PADDING_Y - MAINVIEW_PROGRESS_HEIGHT - MAINVIEW_TOOLBAR_HEIGHT - (MAINVIEW_PADDING_Y * 2) - settingIndicatorView_.contentSize.height - MAINVIEW_INDICATOR_PADDING_Y)];
    
    //progress summary
    CGRect ptframe = progressTableViewController_.view.frame;
    [progressSummaryView_ updateWithFrame:CGRectMake(ptframe.origin.x, ptframe.origin.y + ptframe.size.height + MAINVIEW_PADDING_Y, MAINVIEW_PROGRESS_WIDTH, MAINVIEW_PROGRESS_HEIGHT)];
    
    //setting indicator
    CGRect psframe = progressSummaryView_.frame;
    settingIndicatorView_.frame = CGRectMake(frame.size.width - settingIndicatorView_.contentSize.width - MAINVIEW_PROGRESS_PADDING_X, psframe.origin.y + psframe.size.height + MAINVIEW_PADDING_Y, settingIndicatorView_.contentSize.width, settingIndicatorView_.contentSize.height);
    [settingIndicatorView_ update];
    
    //toolbar
    [toolbar_ setFrame:CGRectMake(0, frame.size.height - MAINVIEW_TOOLBAR_HEIGHT, frame.size.width, MAINVIEW_TOOLBAR_HEIGHT)];
    flexSpace_.width = frame.size.width / 2 - MAINVIEW_CAMERA_BUTTON_WIDTH/2 - MAINVIEW_COMMENT_BUTTON_WIDTH - MAINVIEW_COMMENT_BUTTON_PADDING; 

    /*if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
        CGAffineTransform transform = CGAffineTransformIdentity;
        if(orientation_ == UIInterfaceOrientationPortraitUpsideDown){
            transform = CGAffineTransformMakeRotation(M_PI);
        }else if(orientation_ == UIInterfaceOrientationPortrait){
            transform = CGAffineTransformMakeRotation(0);
        }
        [imagePicker_ setCameraViewTransform:transform];
    }*/
    
    if([TottePostSettings getInstance].commentPostEnabled){
        UIButton *customView = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, MAINVIEW_COMMENT_BUTTON_WIDTH, 33)];
        [customView setBackgroundImage:[UIImage imageNamed:@"comment-selected.png"]forState:UIControlStateNormal];
        [customView addTarget:self action:@selector(didCommentButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        commentButton_.customView = customView;
    }else{
        UIButton *customView = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, MAINVIEW_COMMENT_BUTTON_WIDTH, 33)];
        [customView setBackgroundImage:[UIImage imageNamed:@"comment.png"]forState:UIControlStateNormal];
        [customView addTarget:self action:@selector(didCommentButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        commentButton_.customView = customView;
    }
}

#pragma mark -
#pragma mark photo methods
/*!
 * check for connection
 */
- (BOOL) checkForConnection
{
    Reachability* pathReach = [Reachability reachabilityWithHostName:@"www.facebook.com"];
    switch([pathReach currentReachabilityStatus])
    {
        case NotReachable:
            return NO;
            break;
        case ReachableViaWWAN:
        case ReachableViaWiFi:
            return YES;
            break;
    }
    return NO;
}

/*!
 * on camera button tapped
 */
- (void)didCameraButtonTapped:(id)sender
{
    imagePicker_.showsCameraControls = NO;
    cameraButton_.enabled = NO;
    [imagePicker_ takePicture];
}

/*!
 * post photo
 */
- (void)postPhoto:(PhotoSubmitterImageEntity *)photo{
    PhotoSubmitterManager *manager = [PhotoSubmitterManager getInstance];
    if(manager.enabledSubmitterCount == 0){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[TTLang lstr:@"Alert_Error"] message:[TTLang lstr:@"Alert_NoSubmittersEnabled"] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    if(manager.requiresNetwork == NO ||
       (manager.requiresNetwork && [self checkForConnection])){
        [manager submitPhoto:photo];
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[TTLang lstr:@"Alert_Error"] message:[TTLang lstr:@"Alert_NoNetwork"] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
    
    if(manager.requiresNetwork && [self checkForConnection] == NO &&
       [manager submitterForType:PhotoSubmitterTypeFile].isEnabled){
        [[manager submitterForType:PhotoSubmitterTypeFile] submitPhoto:photo andOperationDelegate:nil];
    }
}

#pragma mark -
#pragma mark preview methods
/*!
 * on post button tapped
 */
- (void) didPostButtonTapped:(id)sender{
    [self postPhoto:previewImageView_.photo];
    [self closePreview];
}

/*!
 * on post cancel button tapped
 */
- (void) didPostCancelButtonTapped:(id)sender{
    [self closePreview];
}

/*!
 * close preview
 */
- (void)closePreview{
    [previewImageView_ dissmiss];
    [self changeCenterButtonTo:cameraButton_];
}

/*!
 * preview photo
 */
- (void)previewPhoto:(PhotoSubmitterImageEntity *)photo{
    [self.view addSubview:previewImageView_];
    [previewImageView_ presentWithPhoto:photo];
    
    [self.view bringSubviewToFront:toolbar_];
    [self changeCenterButtonTo:postButton_];
}

/*!
 * toggle camera button <-> post button
 */
- (void)changeCenterButtonTo:(UIBarButtonItem *)toButton{
    NSMutableArray *items = [NSMutableArray arrayWithArray: toolbar_.items];
    if(toButton == cameraButton_){
        int index = [items indexOfObject:postButton_];
        flexSpace_.width += MAINVIEW_CAMERA_BUTTON_WIDTH;
        [items removeObject:postButton_];
        [items removeObject:postCancelButton_];
        [items insertObject:toButton atIndex:index];
    }else{
        int index = [items indexOfObject:cameraButton_];
        flexSpace_.width -= MAINVIEW_CAMERA_BUTTON_WIDTH;
        [items removeObject:cameraButton_];
        [items insertObject:postCancelButton_ atIndex:index];
        [items insertObject:toButton atIndex:index];
    }
    [toolbar_ setItems: items animated:YES];    
}

/*!
 * update cameracontroller
 */
- (void)updateCameraController{
    [imagePicker_.view removeFromSuperview];
    [progressTableViewController_.view removeFromSuperview];
    [settingIndicatorView_ removeFromSuperview];
    [toolbar_ removeFromSuperview];
    [progressSummaryView_ removeFromSuperview];
    [self.view addSubview:imagePicker_.view];
    [self.view addSubview:progressTableViewController_.view];
    [self.view addSubview:settingIndicatorView_];
    [self.view addSubview:toolbar_];
    [self.view addSubview:progressSummaryView_];  
    imagePicker_.delegate = self;

    [self updateCoordinates];
}

/*!
 * create camera view
 */
- (void) createCameraController{
    [UIApplication sharedApplication].statusBarHidden = YES;
    if(imagePicker_ == nil){
        imagePicker_ = [[AVFoundationCameraController alloc] initWithFrame:self.view.frame];
        imagePicker_.delegate = self;
        imagePicker_.showsCameraControls = YES;
        imagePicker_.showsShutterButton = NO;
    }
    [self updateCameraController];
}
@end

//-----------------------------------------------------------------------------
//Public Implementations
//-----------------------------------------------------------------------------
@implementation MainViewController
@synthesize refreshCameraNeeded = refreshCameraNeeded_;

#pragma mark -
#pragma mark public methods
/*!
 * initializer
 */
- (id)initWithFrame:(CGRect)frame
{
    self = [super init];
    if(self){
        [self setupInitialState:frame];
    }
    bool isCameraSupported = [UIImagePickerController isSourceTypeAvailable:
                              UIImagePickerControllerSourceTypeCamera];        
    if (isCameraSupported == false) {
        NSLog(@"camera is not supported");
    }
    return self;
}

/*!
 * application Did Become active
 */
- (void)applicationDidBecomeActive{
    if(settingViewPresented_){
        [settingViewController_ updateSocialAppSwitches];
    }
}

/*!
 * determin refresh needed
 */
- (void)determinRefreshCameraNeeded{
    if(settingViewPresented_){
        refreshCameraNeeded_ = YES;
    }else{
        refreshCameraNeeded_ = NO;
    }
}

#pragma mark -
#pragma mark Image Picker delegate
/*! 
 * take photo
 */
- (void)cameraController:(AVFoundationCameraController *)cameraController didFinishPickingImageData:(NSData *)data{
    cameraButton_.enabled = YES;
    imagePicker_.showsCameraControls = YES;
    PhotoSubmitterImageEntity *photo = [[PhotoSubmitterImageEntity alloc] initWithData:data];
    if([TottePostSettings getInstance].commentPostEnabled){
        [self previewPhoto:photo];
    }else{
        [self postPhoto:photo];
    }    
}

#pragma mark -
#pragma mark PhotoSubmitter delegate
/*!
 * photo upload start
 */
- (void)photoSubmitter:(id<PhotoSubmitterProtocol>)photoSubmitter willStartUpload:(NSString *)imageHash{
    //NSLog(@"%@ upload started", imageHash);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [progressTableViewController_ addProgressWithType:photoSubmitter.type
                                                  forHash:imageHash];
    });
}

/*!
 * photo submitted
 */
- (void)photoSubmitter:(id<PhotoSubmitterProtocol>)photoSubmitter didSubmitted:(NSString *)imageHash suceeded:(BOOL)suceeded message:(NSString *)message{
    //NSLog(@"%@ submitted.", imageHash);
    dispatch_async(dispatch_get_main_queue(), ^{
        [progressTableViewController_ removeProgressWithType:photoSubmitter.type
                                                 forHash:imageHash];
    });
}

/*!
 * photo upload progress changed
 */
- (void)photoSubmitter:(id<PhotoSubmitterProtocol>)photoSubmitter didProgressChanged:(NSString *)imageHash progress:(CGFloat)progress{
    //NSLog(@"%@, %f", imageHash, progress);
    dispatch_async(dispatch_get_main_queue(), ^{
        [progressTableViewController_ updateProgressWithType:photoSubmitter.type 
                                                     forHash:imageHash progress:progress];
    });
}

#pragma mark -
#pragma mark PreviewPhotoVieww delegate
/*!
 * request for orientation
 */
- (UIInterfaceOrientation)requestForOrientation{
    return orientation_;
}

#pragma mark -
#pragma mark SettingView delegate
/*!
 * did dismiss setting view
 */
- (void)didDismissSettingTableViewController{
    [UIApplication sharedApplication].statusBarHidden = YES;
    //for iphone heck
    if(self.view.frame.origin.y == MAINVIEW_STATUS_BAR_HEIGHT){
        CGRect frame = self.view.frame;
        frame.origin.y = 0;
        frame.size.height += MAINVIEW_STATUS_BAR_HEIGHT;
        [self.view setFrame:frame];
    }
    if(self.refreshCameraNeeded){
        refreshCameraNeeded_ = NO;
        [self performSelector:@selector(updateCameraController) withObject:nil afterDelay:0.5];
    }else{
        [self updateCoordinates];
    }
    settingViewPresented_ = NO;
}

#pragma mark -
#pragma mark UIView delegate
/*!
 * auto rotation
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
        if(interfaceOrientation == UIInterfaceOrientationPortrait ||
           interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown){
            return YES;
        }
        return NO;
    }
    return YES;
}

/*!
 * create camera controller when the view appeared
 */
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if(imagePicker_ == nil){
        [self performSelector:@selector(createCameraController) withObject:nil afterDelay:0.5];
    }
}
@end
