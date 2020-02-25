//
//  ZegoRoomViewController.m
//  LiveQuiz
//
//  Created by summeryxia on 05/02/2018.
//  Copyright © 2018 zego. All rights reserved.
//

#import "ZegoRoomViewController.h"
#import "ZegoSetting.h"
#import "ZegoSDKManager.h"
#import "ZegoPlayViewController.h"
#import "ZegoLogTableViewController.h"
#import "ZegoSettingTableViewController.h"
#import "ZegoNoRoomCell.h"
#import <ZGAppSupport/ZGAppSupportHelper.h>
#import <ZGAppSupport/ZGRoomListUpdateListener.h>
#import <ZGAppSupport/ZGRoomInfo.h>

static NSString *const zegoDomain      = @"zego.im";
static NSString *const alphaBaseUrl    = @"https://alpha-liveroom-api.zego.im";
static NSString *const testBaseUrl     = @"https://test2-liveroom-api.zego.im";
static NSString *const enterPlayingIdentifier = @"EnterPlayingIdentifier";


@interface ZegoRoomCell ()

@property (weak, nonatomic) IBOutlet UIView *backView;
@property (weak, nonatomic) IBOutlet UILabel *roomIDLabel;

@end

@implementation ZegoRoomCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.backView.layer.cornerRadius = 15.0;
    self.roomIDLabel.text = self.roomID;
}

- (void)setRoomID:(NSString *)roomID {
    self.roomIDLabel.text = roomID;
    [self layoutIfNeeded];
}

@end



@interface ZegoRoomViewController () <ZGRoomListUpdateListener>

@property (weak, nonatomic) IBOutlet UITableView *roomTableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

@property (weak, nonatomic) IBOutlet UIButton *settingButton;
@property (weak, nonatomic) IBOutlet UIButton *refreshButton;

@property (nonatomic, strong) NSMutableArray<ZegoRoomInfo *> *roomList;
@property (nonatomic, strong) ZegoRoomInfo *quizRoom;

@property (nonatomic, strong) NSMutableArray *logArray;

@property (nonatomic, assign) BOOL zegoSDKInited;

@end


@implementation ZegoRoomViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIImage *image = [UIImage imageNamed:@"background"];
    self.view.layer.contents = (id)image.CGImage;
    
    self.logArray = [[NSMutableArray alloc] init];
    
    self.settingButton.layer.cornerRadius = self.settingButton.bounds.size.height / 2.0;
    self.refreshButton.layer.cornerRadius = self.refreshButton.bounds.size.height / 2.0;
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    [self.roomTableView insertSubview:self.refreshControl atIndex:0];
    
    [self.roomTableView registerNib:[UINib nibWithNibName:@"ZegoNoRoomCell" bundle:nil] forCellReuseIdentifier:@"ZegoNoRoomCellID"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    // 监听 zego SDK 初始化完成
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onReceiveZegoLiveRoomApiInitCompleteNotification:)
        name:ZegoLiveRoomApiInitCompleteNotification
      object:nil];
    
    [[ZGAppSupportHelper sharedInstance].api setRoomListUpdateListener:self];
    
    [self fetchLiveRoom];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:enterPlayingIdentifier]) {
        ZegoPlayViewController *viewController = (ZegoPlayViewController *)segue.destinationViewController;
        viewController.roomInfo = sender;
    }
}

- (IBAction)onShowSettingController:(id)sender {
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"ZegoSettingTableViewController" bundle:nil];
    ZegoSettingTableViewController *settingController = [sb instantiateViewControllerWithIdentifier:@"Setting"];
    settingController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:settingController animated:YES completion:nil];
}

- (IBAction)onRefresh:(id)sender {
    [self handleRefresh:sender];
}

- (void)applicationBecomeActive {
    [self handleRefresh:self.refreshControl];
}

- (void)onReceiveZegoLiveRoomApiInitCompleteNotification:(NSNotification *)note {
    NSNumber *errorCodeObj = note.userInfo[ZegoLiveRoomApiInitErrorCodeKey];
    if (![errorCodeObj isKindOfClass:[NSNumber class]]) {
        return;
    }
    int errorCode = [errorCodeObj intValue];
    self.zegoSDKInited = (errorCode == 0);
    [self fetchLiveRoom];
}

- (void)handleRefresh:(UIRefreshControl *)refreshControl {
    [self fetchLiveRoom];
}

- (void)onShowLog:(id)sender {
    ZegoLogTableViewController *logViewController = [[ZegoLogTableViewController alloc] init];
    logViewController.logArray = self.logArray;
    ZegoLogNavigationController *navigationController = [[ZegoLogNavigationController alloc] initWithRootViewController:logViewController];
    navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - Private

- (void)fetchLiveRoom {
    // init Zego SDK if need
    [ZegoSDKManager api];
    if (self.zegoSDKInited) {
        [self.refreshControl beginRefreshing];
        [self.refreshButton setTitle:@"刷新中" forState:UIControlStateNormal];
        
        uint32_t appID = [ZegoSetting sharedInstance].appID;
        NSLog(@"refreshRoomList, appID:%u",appID);
        [[ZGAppSupportHelper sharedInstance].api updateRoomList:appID];
    }
}

#pragma mark - ZGRoomListUpdateListener
- (void)onUpdateRoomList:(NSArray<ZGRoomInfo *> *)roomList {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"onUpdateRoomList, roomList.count:%u", roomList.count);
        
        if ([self.refreshControl isRefreshing]) {
            [self.refreshControl endRefreshing];
        }
        
        [self.refreshButton setTitle:@"刷新" forState:UIControlStateNormal];
        
        [self.roomList removeAllObjects];
        
        for (ZGRoomInfo *info in roomList) {
            ZegoRoomInfo *roomInfo = [ZegoRoomInfo new];
            roomInfo.roomID = info.roomId;
            roomInfo.roomName = info.roomName;
            roomInfo.anchorID = info.anchorIdName;
            roomInfo.anchorName = info.anchorNickName;
            roomInfo.streamInfo = @[].mutableCopy;
            for (ZGStreamInfo *stream in info.streamInfo) {
                ZegoStream *tarStream = [[ZegoStream alloc] init];
                tarStream.streamID = stream.streamId;
                [roomInfo.streamInfo addObject:tarStream];
            }
            
            [self.roomList addObject:roomInfo];
        }
        
        [self.roomTableView reloadData];
    });
}

- (void)onUpdateRoomListError {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"onUpdateRoomListError");
        
        if ([self.refreshControl isRefreshing]) {
            [self.refreshControl endRefreshing];
        }
        
        [self.refreshButton setTitle:@"刷新" forState:UIControlStateNormal];
    });
}

- (void)addLogString:(NSString *)logString
{
    if (logString.length != 0)
    {
        NSString *totalString = [NSString stringWithFormat:@"%@: %@", [self getCurrentTime], logString];
        [self.logArray insertObject:totalString atIndex:0];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"logUpdateNotification" object:self userInfo:nil];
    }
}

- (NSString *)getCurrentTime
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"[YYYY-HH-mm-ss:SSS]";
    return [formatter stringFromDate:[NSDate date]];
}

#pragma mark - Access

- (NSMutableArray *)roomList {
    if (!_roomList) {
        _roomList = [NSMutableArray array];
    }
    return _roomList;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.roomList.count > 0 ? self.roomList.count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.roomList.count < indexPath.row) {
        return nil;
    }
    
    if (self.roomList.count > 0) {
        ZegoRoomCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RoomCell" forIndexPath:indexPath];
        ZegoRoomInfo *info = self.roomList[indexPath.row];
        cell.roomID = [NSString stringWithFormat:@"%@", info.roomID];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.userInteractionEnabled = YES;
        return cell;
    } else {
        ZegoNoRoomCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ZegoNoRoomCellID" forIndexPath:indexPath];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.userInteractionEnabled = NO;
        return cell;
    }
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 65;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    self.quizRoom = self.roomList[indexPath.row];
    [self performSegueWithIdentifier:enterPlayingIdentifier sender:self.quizRoom];
}

@end
