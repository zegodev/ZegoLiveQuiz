//
//  ZegoPlayViewController.m
//  LiveQuiz
//
//  Created by summeryxia on 17/01/2018.
//  Copyright © 2018 zego. All rights reserved.
//

#import "ZegoPlayViewController.h"
#import "ZegoSDKManager.h"
#import "ZegoSetting.h"
#import "ZegoMessageViewController.h"
#import "ZegoCommentView.h"
#import "ZegoQuizView.h"
#import <ZegoLiveRoom/ZegoliveRoomApi-Relay.h>
#import "ZegoQuizParser.h"
#import "ZegoQuizInfo.h"
#import "ZegoFinalStatViewController.h"
#import "ZegoActivityInfo.h"
#import "ZegoLogTableViewController.h"

#define COUNTDOWN 5;

static id selfObject;
static int countdown;
static int mediaSeq;
static const int maxRetryCount = 3;
static NSString * const questionKey = @"question";
static NSString * const answerKey = @"answer";
static NSString * const sumKey = @"sum";

@interface ZegoPlayViewController () <ZegoRoomDelegate, ZegoIMDelegate, ZegoLivePlayerDelegate, ZegoCommentViewDelegate, ZegoQuizViewDelegate, ZegoFinalStatViewControllerDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIButton *closeButton;
@property (weak, nonatomic) IBOutlet UIView *playViewContainer;
@property (weak, nonatomic) IBOutlet UIView *messageView;
@property (weak, nonatomic) IBOutlet UIView *commentView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *commentViewBottomConstraint;
@property (weak, nonatomic) IBOutlet UILabel *onlineCountLabel;

@property (nonatomic, strong) ZegoQuizView *quizView;
@property (nonatomic, strong) ZegoCommentView *customCommentView; // FIXME: 可以只用一个 commentView，待修改
@property (nonatomic, strong) ZegoMessageViewController *messageViewController;
@property (nonatomic, strong) ZegoFinalStatViewController *statViewController;

@property (nonatomic, copy) NSString *streamID;     // 创建stream后，server返回的streamID(当前直播的streamID)
@property (nonatomic, copy) NSArray *streamIDList;
@property (nonatomic, strong) NSMutableArray<ZegoStream *> *streamList;
@property (nonatomic, strong) NSMutableArray<ZegoStream *> *originStreamList;   // 直播秒开流列表
@property (nonatomic, assign) NSUInteger maxStreamCount;  //支持的最大流数量

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL isLoginSucceeded;

@property (nonatomic, strong) NSMutableArray *logArray;

@property (nonatomic, strong) NSMutableDictionary *viewContainers;
@property (nonatomic, strong) NSMutableDictionary *streamID2SizeDict;
@property (nonatomic, strong) NSMutableDictionary *videoSizeDict;

@property (nonatomic, strong) NSTimer *messageTimer; // 用于消息列表的假数据构造，检查滚动效果
@property (nonatomic, strong) NSMutableArray *messageList;

@property (nonatomic, strong) ZegoQuizInfo *currentQuiz;
@property (nonatomic, copy) NSString *receivedInfoType; // question, answer
@property (nonatomic, strong) ZegoActivityInfo *activityInfo;
@property (nonatomic, assign) NSInteger finalUserCount; // 最后胜利的用户数

@property (nonatomic, strong) NSTimer *countdownTimer; // 用于答题时倒计时
@property (nonatomic, assign) int retryPlayIndex;      // 播放失败重试控制
@property (nonatomic, assign) int retryConnectIndex;   // onDisconnect 失败重试控制

@property (nonatomic, strong) NSMutableArray *questionIDs;  // 记录一轮游戏中 question 的 questionID
@property (nonatomic, strong) NSMutableArray *answerIDS;    // 记录一轮游戏中 answer 的 questionID
@property (nonatomic, copy) NSString *sumID;    // 记录一轮游戏中 sum 的 activityID


@end

@implementation ZegoPlayViewController

#pragma mark - Life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    selfObject = self;
    
    [self setupModel];
    [self setupSDKKit];
    [self setupUI];
    
    [self loginRoom];
    
    [self setupNotification];

    // 如果在首页列表中获取到了流信息，则秒播
    if ([self.roomInfo.streamInfo count] > 0) {
        ZegoStream *stream = self.roomInfo.streamInfo[0]; // 默认取第一条流
        self.streamID = stream.streamID;
        [self playStreamDirectly];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    
    [[ZegoSDKManager api] setMediaSideCallback:nil];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSLog(@"ZegoPlayViewController did Receive Memory Warning");
}

- (void)dealloc {
    NSLog(@"ZegoPlayViewController dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Event response

- (void)onShowLog:(id)sender {
    ZegoLogTableViewController *logViewController = [[ZegoLogTableViewController alloc] init];
    logViewController.logArray = self.logArray;
    
    ZegoLogNavigationController *navigationController = [[ZegoLogNavigationController alloc] initWithRootViewController:logViewController];
    navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (IBAction)onClose:(id)sender {
    [[ZegoSDKManager api] stopPlayingStream:self.streamID];
    [[ZegoSDKManager api] logoutRoom];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)onTapView:(UIGestureRecognizer *)gesture
{
    if (self.customCommentView.commentInput.isEditing) {
        [self.customCommentView.commentInput resignFirstResponder];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    if (!self.customCommentView.commentInput.isEditing) {
        return;
    }
    
    // 键盘弹出需要花费的时间
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    // 键盘的开始位置点
//    CGRect beginFrame = [notification.userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    // 键盘的结束位置点
    CGRect endFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // 计算键盘在 self.view 中的位置
    endFrame = [self.view.window convertRect:endFrame toView:self.view];
    if (CGRectEqualToRect(endFrame, CGRectZero)) {
        return;
    }
    
    // 键盘弹出动画类型（开始/结束时快/慢)
    NSUInteger animationCurve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
    
    // 弹出键盘时，commentView 整体上移键盘高度
    //    CGFloat chatInputOffset = CGRectGetMinY(endFrame) + self.bottomLayoutGuide.length - CGRectGetHeight(self.view.bounds);
    //    if (chatInputOffset > 0) {
    //        chatInputOffset = 0;
    //    }
    
    self.commentViewBottomConstraint.constant = CGRectGetHeight(endFrame);     // 点击评论后，commentView 上移到键盘上方
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:animationCurve
                     animations:^{
                         [self.view layoutIfNeeded];
                     } completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.commentViewBottomConstraint.constant = 0;     // 点击评论后，commentView 上移到键盘上方
    
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    // 键盘弹出动画类型（开始/结束时快/慢)
    NSUInteger animationCurve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
//    self.customCommentView.commentInput.hidden = YES;
    
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:animationCurve
                     animations:^{
                         [self.view layoutIfNeeded];
                     } completion:nil];
}

#pragma mark -- Timer

- (void)onMessageTimerFired:(id)sender {
    NSArray *name = @[@"radom", @"jack", @"全世界都是傻子", @"普罗米修斯", @"斯卡多夫斯克", @"呵呵呵", @"rose", @"浮点数", @"奶茶奶奶", @"开始纯牛奶"];
    NSArray *infos = @[@"好刺激好好玩", @"又答对了", @"又答错了！！！", @"BBBBBBBB", @"ccc", @"废话太多了，快开始下一题", @"复活码：435232 复活码：435232 复活码：435232 复活码：435232 复活码：435232 复活码：435232", @"答案当然是C啊，哈哈哈哈哈哈哈哈", @"都是些什么题啊！！垃圾！", @"鹅鹅鹅鹅鹅鹅"];
    for (int i = 0; i < infos.count; i++) {
        ZegoBigRoomMessage *message = [[ZegoBigRoomMessage alloc] init];
        message.fromUserName = name[i];
        message.content = infos[i];
        [self.messageList addObject:message];
    }
    self.messageViewController.messageList = self.messageList;
}

- (void)onCountdownTimerFired:(id)sender {
    if (countdown == -1) {
        [self.quizView removeFromSuperview];
        [self stopCountdownTimer];
        return;
    }
    
    // 问题界面才需要显示倒计时，结果界面不用显示，但仍然有倒计时
    if ([self.receivedInfoType isEqualToString:questionKey]) {
        self.quizView.countdown = countdown;
    }
    
    countdown --;
}

#pragma mark - Private

- (void)setupModel {
    self.maxStreamCount = [ZegoLiveRoomApi getMaxPlayChannelCount];
    self.viewContainers = [[NSMutableDictionary alloc] initWithCapacity:self.maxStreamCount];
    self.videoSizeDict = [[NSMutableDictionary alloc] initWithCapacity:self.maxStreamCount];
    self.streamID2SizeDict = [[NSMutableDictionary alloc] initWithCapacity:self.maxStreamCount];
    self.originStreamList = [[NSMutableArray alloc] initWithCapacity:self.maxStreamCount];
    self.logArray = [[NSMutableArray alloc] init];
    
    self.isLoginSucceeded = NO;
    self.isPlaying = NO;
    
    self.retryPlayIndex = 0;
    self.retryConnectIndex = 0;
    
    mediaSeq = -1;
    self.finalUserCount = 0;
    
    self.questionIDs = [[NSMutableArray alloc] init];
    self.answerIDS = [[NSMutableArray alloc] init];
}

- (void)setupUI {
    // 背景文字
    UIImage *backgroundImage = [[ZegoSetting sharedInstance] getBackgroundImage:self.view.bounds.size withText:NSLocalizedString(@"加载中...", nil)];
    [self setBackgroundImage:backgroundImage playerView:self.playViewContainer];
    
    // 评论 view
    ZegoCommentView *customCommentView = [[[NSBundle mainBundle] loadNibNamed:@"ZegoCommentView" owner:self options:nil] lastObject];
    [self.commentView addSubview:customCommentView];
    customCommentView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 50);
    customCommentView.delegate = self;
    self.customCommentView = customCommentView;
    self.customCommentView.commentInput.delegate = self;
    
    // 消息 view
    ZegoMessageViewController *messageController = [[ZegoMessageViewController alloc] initWithNibName:@"ZegoMessageViewController" bundle:nil];
    [self displayMessageController:messageController];
    
    // 手势
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapView:)];
    [self.view addGestureRecognizer:tapGestureRecognizer];
}

- (void)setupNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)setupSDKKit
{
    [[ZegoSDKManager api] setRoomDelegate:self];
    [[ZegoSDKManager api] setIMDelegate:self];
    [[ZegoSDKManager api] setPlayerDelegate:self];
    [[ZegoSDKManager api] setMediaSideCallback:onReceivedMediaSideInfo];
}

- (void)displayMessageController:(ZegoMessageViewController *)viewController {
    [self addChildViewController:viewController];
    [self.messageView addSubview:viewController.view];
    [viewController didMoveToParentViewController:self];
    
    viewController.view.frame = CGRectMake(0, 0, CGRectGetWidth(self.messageView.bounds), CGRectGetHeight(self.messageView.bounds));
    
    self.messageViewController = viewController;
}

- (void)displayFinalStatController:(ZegoFinalStatViewController *)viewController {
    [self addChildViewController:viewController];
    [self.view addSubview:viewController.view];
    [viewController didMoveToParentViewController:self];
    
    viewController.view.frame = CGRectMake(0, 60, [UIScreen mainScreen].bounds.size.width, 383);
    
    self.statViewController = viewController;
    self.statViewController.delegate = self;
}

- (void)removeFinalStatController {
    [self.statViewController willMoveToParentViewController:nil];
    [self.statViewController.view removeFromSuperview];
    [self.statViewController removeFromParentViewController];
    self.statViewController = nil;
}

- (void)playStreamDirectly {
    [self addLogString:@"Enter playStreamDirectly"];
    NSLog(@"Play Stream Directly");
    
    UIView *bigView = [[UIView alloc] init];
    bigView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playViewContainer addSubview:bigView];
    [self.playViewContainer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[bigView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(bigView)]];
    [self.playViewContainer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bigView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(bigView)]];
    
    self.viewContainers[self.streamID] = bigView;
    
    [ZegoLiveRoomApi setConfig:@"prefer_play_ultra_source=1"]; // 默认从服务器拉流
    [[ZegoSDKManager api] startPlayingStream:self.streamID inView:bigView];
    [[ZegoSDKManager api] setViewMode:ZegoVideoViewModeScaleAspectFit ofStream:self.streamID];
}

- (void)loginRoom
{
    [[ZegoSDKManager api] loginRoom:self.roomInfo.roomID
                               role:ZEGO_AUDIENCE
                withCompletionBlock:^(int errorCode, NSArray<ZegoStream *> *streamList) {
        NSLog(@"[loginRoom] error: %d", errorCode);
        if (errorCode == 0)
        {
            NSLog(@"登录房间成功，roomID: %@", self.roomInfo.roomID);
            NSString *logString = [NSString stringWithFormat:NSLocalizedString(@"Login Room Succeeded, roomID: %@", nil), self.roomInfo.roomID];
            [self addLogString:logString];
            
            self.isLoginSucceeded = YES;
            self.retryConnectIndex = 0;
            
            if ([streamList count] == 0) {
                [self showAlert:@"房间流列表为空，请重新登录房间" title:@"提示"];
                return;
            }
            
            ZegoStream *streamFirst = streamList[0]; // FIXME: 默认只有一条流，且取第一条流，如果有多条流，这里要改
            if (self.streamID.length) {
                // 登录成功前已经从房间列表获取到了流ID
                if ([streamFirst.streamID isEqualToString:self.streamID]) {
                    NSLog(@"Login-StreamID is the same as the initial one, ignore");
                    return;
                }
            }
                
            // streamID 不一致或之前没有获取到，更新 self.streamID
            self.roomInfo.streamInfo = [streamList mutableCopy];
            self.streamID = streamFirst.streamID;
            [self playStreamDirectly];
        }
        else
        {
            NSLog(@"登录房间失败，error: %d", errorCode);
            NSString *logString = [NSString stringWithFormat:NSLocalizedString(@"Login Room Failed, error: %d", nil), errorCode];
            [self addLogString:logString];
            
            if (self.retryConnectIndex > maxRetryCount) {
                [self showAlert:@"应用断开连接，请重新登录" title:@"提示"];
            }
        }
    }];
    
    [self addLogString:[NSString stringWithFormat:NSLocalizedString(@"Begin to Login Room", nil)]];
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
    formatter.dateFormat = @"[HH-mm-ss:SSS]";
    return [formatter stringFromDate:[NSDate date]];
}

- (void)setBackgroundImage:(UIImage *)image playerView:(UIView *)playerView
{
    playerView.backgroundColor = [UIColor colorWithPatternImage:image];
}

- (void)showAlert:(NSString *)message title:(NSString *)title {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:NSLocalizedString(@"确定", nil)
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        
                                                    }];
    
    [alertController addAction:confirm];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark -- Timer

- (void)startMessageTimer {
    if (![self.messageTimer isValid]) {
        self.messageTimer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(onMessageTimerFired:) userInfo:nil repeats:YES];
    }
    
    [self.messageTimer fire];
}

- (void)stopMessageTimer {
    [self.messageTimer invalidate];
    self.messageTimer = nil;
}

- (void)startCountdownTimer {
    if (![self.countdownTimer isValid]) {
        self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(onCountdownTimerFired:) userInfo:nil repeats:YES];
    }
    [self.countdownTimer fire];
}

- (void)stopCountdownTimer {
    [self.countdownTimer invalidate];
    self.countdownTimer = nil;
}

#pragma mark -- Media side info

void onReceivedMediaSideInfo(const char *pszStreamID, const unsigned char* buf, int dataLen) {
    if (dataLen == 0) {
        NSLog(@"[onReceivedMediaSideInfo] data is empty");
        return;
    }
    
//    NSString *streamID = [NSString stringWithCString:pszStreamID encoding:NSUTF8StringEncoding];
    NSData *mediaInfo = [NSData dataWithBytes:buf + 4 length:dataLen - 4];
    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:mediaInfo options:0 error:&error];
    
    if (error == nil) {
        [selfObject handleActivity:info];
        
        if ([selfObject handleDuplication:info]) {
            return;
        }
        
        NSLog(@"[onReceivedMediaSideInfo] type: %@, questionId: %@, activityId: %@", info[@"type"], info[@"data"][@"id"], info[@"data"][@"activity_id"]);
        [selfObject addLogString:[NSString stringWithFormat:@"[onReceivedMediaSideInfo] type: %@, questionId: %@, activityId: %@", info[@"type"], info[@"data"][@"id"], info[@"data"][@"activity_id"]]];
        
        if ([info[@"type"] isEqualToString:questionKey]) {
            [selfObject handleQuestionInfo:info];
        } else if ([info[@"type"] isEqualToString:answerKey]) {
            [selfObject handleAnswerInfo:info];
        } else if ([info[@"type"] isEqualToString:sumKey]) {
            [selfObject handleFinalResult:info];
        } else {
            NSLog(@"onReceivedMediaSideInfo unknown type, ignore");
        }
    }
}

- (void)handleActivity:(NSDictionary *)info {
    NSString *activityID = info[@"data"][@"activity_id"];
    if (self.activityInfo.activityID.length == 0) {
        // 首次收到题目
        self.activityInfo.activityID = activityID;
    } else {
        if (![self.activityInfo.activityID isEqualToString:activityID]) {
            // activity ID 改变，重新开始一轮游戏
            self.activityInfo.activityID = activityID;
            [self.questionIDs removeAllObjects];
            [self.answerIDS removeAllObjects];
        }
    }
}

- (BOOL)handleDuplication:(NSDictionary *)info {
    NSString *type = info[@"type"];
    NSDictionary *data = info[@"data"];
    NSString *itemID = data[@"id"];
    NSString *itemActivityID = data[@"activity_id"];
    
    if ([type isEqualToString:questionKey]) {
        if ([self.questionIDs containsObject:itemID]) {
            NSLog(@"[handleDuplication] repeat question-questionID: %@, ignore", itemID);
            return YES;
        } else {
            [self.questionIDs addObject:itemID];
        }
    } else if ([type isEqualToString:answerKey]) {
        if ([self.answerIDS containsObject:itemID]) {
            NSLog(@"[handleDuplication] repeat answer-questionID: %@, ignore", itemID);
            return YES;
        } else {
            [self.answerIDS addObject:itemID];
        }
    } else if ([type isEqualToString:sumKey]) {
        if (self.sumID.length && [self.sumID isEqualToString:itemActivityID]) {
            NSLog(@"[handleDuplication] repeat sum-activityID: %@, ignore", itemActivityID);
            return YES;
        } else {
            self.sumID = itemActivityID;
            [self.questionIDs removeAllObjects];
            [self.answerIDS removeAllObjects];
        }
    } else {
        NSLog(@"onReceivedMediaSideInfo unknown type, ignore");
    }
    
    return NO;
}

/**
1. 主播向观众发送题目：
{
    "seq": 1,
    "type": "question",
    "data": {
        "id": "0ca175b9c0f726a831d895e269332461",
        "activity_id": "123456",
        "index": 1,
        "title": "下面哪个省的面积最大? ",
        "options": [{
            "answer": "A",
            "option": "河北"
        }, {
            "answer": "B",
            "option": "山东"
        }, {
            "answer": "C",
            "option": "湖南"
        }]
    }
}
**/
- (void)handleQuestionInfo:(NSDictionary *)info {
    self.receivedInfoType = questionKey;
    ZegoQuizInfo *currentQuiz = [[ZegoQuizInfo alloc] init];
    
    NSDictionary *data = info[@"data"];
    currentQuiz.quizID = data[@"id"];
    NSLog(@"[handleQuestionInfo] questionID: %@, activityID: %@", currentQuiz.quizID, self.activityInfo.activityID);
    
    NSInteger index = [data[@"index"] integerValue];
    currentQuiz.index = index;
    currentQuiz.title = [NSString stringWithFormat:@"%ld. %@", (long)index, data[@"title"]];
    currentQuiz.type = questionKey;
    NSArray *options = data[@"options"];
    
    if ([options count] != 3) {
        NSLog(@"onReceivedMediaSideInfo options count: %lu, which is not equal to 3, abandon", (unsigned long)[options count]);
        return;
    }
    
    NSMutableArray *optionSorted = [NSMutableArray arrayWithCapacity:3];
    for (NSDictionary *option in options) {
        ZegoOptionInfo *element = [[ZegoOptionInfo alloc] init];
        if ([option[@"answer"] isEqualToString:@"A"]) {
            element.optionDesc = [NSString stringWithFormat:@"%@. %@", option[@"answer"], option[@"option"]];
            element.optionCount = 0;
            optionSorted[0] = element;
        } else if ([option[@"answer"] isEqualToString:@"B"]) {
            element.optionDesc = [NSString stringWithFormat:@"%@. %@", option[@"answer"], option[@"option"]];
            element.optionCount = 0;
            optionSorted[1] = element;
        } else if ([option[@"answer"] isEqualToString:@"C"]) {
            element.optionDesc = [NSString stringWithFormat:@"%@. %@", option[@"answer"], option[@"option"]];
            element.optionCount = 0;
            optionSorted[2] = element;
        }
    }
    
    currentQuiz.options = [optionSorted copy];
    self.currentQuiz = currentQuiz;
    
    [self showQuizView:currentQuiz];
}

/**
2. 主播向观众发送每道题的统计以及正确答案：
 {
    "seq": 2,
    "type": "answer",
    "data": {
        "id": "0ca175b9c0f726a831d895e269332461",
        "activity_id": "123456",
        "correct_answer": "B",
        "answer_stat": [{
            "answer": "A",
            "user_count": 2000
            }, {
            "answer": "B",
            "user_count": 1300
            }, {
            "answer": "C",
            "user_count": 420
        }]
    }
 }
**/
- (void)handleAnswerInfo:(NSDictionary *)info {
    if (!self.currentQuiz) {
        // 先收到答案
        self.currentQuiz = [[ZegoQuizInfo alloc] init];
    }
    
    self.receivedInfoType = answerKey;
    NSDictionary *data = info[@"data"];
    NSString *quizID = data[@"id"];
    if (![quizID isEqualToString:self.currentQuiz.quizID]) {
        [self addLogString:@"answer received, but questionID mismatch, ignore"];
        NSLog(@"answer received, but questionID mismatch, ignore");
        return;
    }
    
    self.currentQuiz.type = answerKey;
    self.currentQuiz.correctAnswer = data[@"correct_answer"];
    NSArray *answerStat = data[@"answer_stat"];
    
    if ([answerStat count] != 3) {
        NSLog(@"onReceivedMediaSideInfo answerStat count: %lu, which is not equal to 3, ignore", (unsigned long)[answerStat count]);
        return;
    }
    
    for (NSDictionary *answer in answerStat) {
        // 获取正确答案的人数
        if ([answer[@"answer"] isEqualToString:self.currentQuiz.correctAnswer]) {
            self.finalUserCount =  [answer[@"user_count"] integerValue];
            NSLog(@"[handleAnswerInfo] finalUserCount: %ld", (long)self.finalUserCount);
        }
        
        if ([answer[@"answer"] isEqualToString:@"A"]) {
            ZegoOptionInfo *info = self.currentQuiz.options[0];
            info.optionCount = [answer[@"user_count"] integerValue];
        } else if ([answer[@"answer"] isEqualToString:@"B"]) {
            ZegoOptionInfo *info = self.currentQuiz.options[1];
            info.optionCount = [answer[@"user_count"] integerValue];
        } else if ([answer[@"answer"] isEqualToString:@"C"]) {
            ZegoOptionInfo *info = self.currentQuiz.options[2];
            info.optionCount = [answer[@"user_count"] integerValue];
        }
    }
    
    [self showQuizView:self.currentQuiz];
}

/**
3. 主播向观众发送用户列表：
{
    "seq": 3,
    "type": "sum",
    "data": {
        "room_id": "roomid123",
        "activity_id": "123456",
        "user_list": [
                      {
                          "id_name": "555",
                          "nick_name": "lzp"
                      },
                      {
                          "id_name": "666",
                          "nick_name": "hhh"
                      }
                      ]
    }
}
**/
- (void)handleFinalResult:(NSDictionary *)info {
    if (!self.currentQuiz) {
        // 直接收到最终结果
        self.currentQuiz = [[ZegoQuizInfo alloc] init];
    }

    self.receivedInfoType = sumKey;
    NSDictionary *data = info[@"data"];
    NSString *activityID = data[@"activity_id"];
    NSArray *userList = data[@"user_list"];
    
    NSMutableArray *list = [[NSMutableArray alloc] init];
    if ([userList count] == 0) {
        NSLog(@"userList is nil");
    } else {
        for (NSDictionary *dict in userList) {
            ZegoUser *user = [[ZegoUser alloc] init];
            user.userId = dict[@"id_name"];
            user.userName = dict[@"nick_name"];
            [list addObject:user];
        }
    }
    
    // 如果已存在，则先移除
    if (self.statViewController) {
        [self removeFinalStatController];
    }
    
    ZegoFinalStatViewController *statController = [[ZegoFinalStatViewController alloc] initWithNibName:@"ZegoFinalStatViewController" bundle:nil];
    statController.winnerList = list;
    statController.totalCount = self.finalUserCount;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self displayFinalStatController:statController];
    });
}

- (void)showQuizView:(ZegoQuizInfo *)quizInfo {
    NSLog(@"[showQuizView] quizInfo: %@", quizInfo);
    countdown = COUNTDOWN;
    
    // 如果之前的弹框还存在，先清理掉，并停止关联定时器
    if (self.quizView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.quizView removeFromSuperview];
        });
        self.quizView = nil;
        [self stopCountdownTimer];
    }
    
    self.quizView = [[[NSBundle mainBundle] loadNibNamed:@"ZegoQuizView" owner:self options:nil] lastObject];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.quizView.delegate = self;
        self.quizView.quizInfo = quizInfo;
        
        self.quizView.center = CGPointMake(self.playViewContainer.center.x, self.playViewContainer.center.y - 50);
        [self.view addSubview:self.quizView];
        [self.view bringSubviewToFront:self.quizView];
    
        [self startCountdownTimer];
    });
}

#pragma mark - ZegoIMDelegate

- (void)onUpdateOnlineCount:(int)onlineCount room:(NSString *)roomId {
    if ([roomId isEqualToString:self.roomInfo.roomID]) {
        self.onlineCountLabel.text = [NSString stringWithFormat:@"%d", onlineCount];
    }
}

- (void)onRecvBigRoomMessage:(NSString *)roomId messageList:(NSArray<ZegoBigRoomMessage*> *)messageList {
    if (![roomId isEqualToString:self.roomInfo.roomID]) {
        NSLog(@"[onRecvBigRoomMessage] receive big room message, but roomId mismatch, abandon");
        return;
    }
    
    if (messageList.count == 0) {
        NSLog(@"[onRecvBigRoomMessage] receive big room message, but messageList is nil");
        return;
    }
    
    [self.messageList addObjectsFromArray:messageList];
    self.messageViewController.messageList = self.messageList;
}

#pragma mark - ZegoLivePlayerDelegate

- (void)onPlayStateUpdate:(int)stateCode streamID:(NSString *)streamID
{
    NSLog(@"[onPlayStateUpdate] stateCode: %d, streamID:%@", stateCode, streamID);
    
    if (stateCode == 0) {
        NSString *logString = [NSString stringWithFormat:NSLocalizedString(@"Play Stream Failed, streamID: %@", nil), streamID];
        NSLog(@"%@", logString);
        [self addLogString:logString];
        
        self.isPlaying = YES;
        self.retryPlayIndex = 0;
    } else {
        NSString *logString = [NSString stringWithFormat:NSLocalizedString(@"Play Stream Failed, streamID: %@, error: %d", nil), streamID, stateCode];
        NSLog(@"%@", logString);
        [self addLogString:logString];
        
        self.retryPlayIndex ++;
//        [self retryPlay:streamID]; // FIXME: 定位到了问题再放开
    }
}

- (void)retryPlay:(NSString *)streamID {
    NSLog(@"[retryPlay] retryPlayIndex: %d", self.retryPlayIndex);
    
    if (self.retryPlayIndex <= maxRetryCount) {
        if (![self.viewContainers.allKeys containsObject:streamID]) {
            NSLog(@"retry play, but streamID not matched");
            return;
        }
        
        UIView *bigView = self.viewContainers[streamID];
        [[ZegoSDKManager api] startPlayingStream:streamID inView:bigView];
        [[ZegoSDKManager api] setViewMode:ZegoVideoViewModeScaleAspectFit ofStream:streamID];
    }
}

- (void)onVideoSizeChangedTo:(CGSize)size ofStream:(NSString *)streamID
{
    NSLog(@"[onVideoSizeChangedTo] streamID %@", streamID);
    
    NSString *logString = [NSString stringWithFormat:NSLocalizedString(@"Get the first video frame, streamID: %@", nil), streamID];
    [self addLogString:logString];

    UIView *view = self.viewContainers[streamID];
    [self setBackgroundImage:nil playerView:view];
}

#pragma mark - ZegoRoomDelegate

- (void)onDisconnect:(int)errorCode roomID:(NSString *)roomID {
    NSString *logString = [NSString stringWithFormat:@"[onDisconnect] roomID: %@, error: %d", roomID, errorCode];
    [self addLogString:logString];
    NSLog(@"%@", logString);
    
    [self retryConnect:roomID];
    self.retryConnectIndex ++;
}

- (void)onReconnect:(int)errorCode roomID:(NSString *)roomID {
    NSString *logString = [NSString stringWithFormat:@"[onReconnect] roomID: %@, error: %d", roomID, errorCode];
    [self addLogString:logString];
}

- (void)retryConnect:(NSString *)roomID {
    if (self.retryConnectIndex <= maxRetryCount) {
        [self loginRoom];
    }
}

#pragma mark - ZegoCommentViewDelegate

- (void)onLogButtonClicked:(id)sender {
    [self onShowLog:sender];
}

- (void)sendRoomMessage {
    [self.customCommentView.commentInput resignFirstResponder];
    if (self.customCommentView.commentInput.text.length == 0) {
        NSLog(@"[sendRoomMessage] 评论为空，不发送任何信息");
        return;
    }
    
    NSString *comment = self.customCommentView.commentInput.text;
    bool ret = [[ZegoSDKManager api] sendBigRoomMessage:comment
                                                   type:ZEGO_TEXT
                                               category:ZEGO_CHAT
                                             completion:nil];

    if (ret) {
        ZegoBigRoomMessage *roomMessage = [ZegoBigRoomMessage new];
        roomMessage.fromUserId = [ZegoSetting sharedInstance].userID;
        roomMessage.fromUserName = [ZegoSetting sharedInstance].userName;
        roomMessage.content = comment;
        roomMessage.type = ZEGO_TEXT;
        roomMessage.category = ZEGO_CHAT;
        roomMessage.priority = ZEGO_DEFAULT;
        
        [self.messageList addObject:roomMessage];
        self.messageViewController.messageList = self.messageList;
        self.customCommentView.commentInput.text = @"";
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.customCommentView.commentInput) {
        [self sendRoomMessage];
        return YES;
    }
    return NO;
}

#pragma mark - ZegoQuizViewDelegate

- (void)onOptionAClicked:(id)sender {
    NSLog(@"user choosed A");
    [self relayDataWithAnswer:@"A"];
}

- (void)onOptionBClicked:(id)sender {
    NSLog(@"user choosed B");
    [self relayDataWithAnswer:@"B"];
}

- (void)onOptionCClicked:(id)sender {
    NSLog(@"user choosed C");
    [self relayDataWithAnswer:@"C"];
}

- (void)relayDataWithAnswer:(NSString *)answer {
    self.currentQuiz.userAnswer = nil;
    NSString *relayData = [ZegoQuizParser assembleRelayData:self.activityInfo.activityID questionID:self.currentQuiz.quizID answer:answer userData:nil];
    
    if (relayData == nil) {
        NSLog(@"relay data is nil");
        [self showAlert:@"发送答案失败" title:@"提示"];
        return;
    }
    
    // TODO: 上传答案失败要重试
    BOOL invokeSuccess = [[ZegoSDKManager api] relayData:relayData type:ZEGO_RELAY_TYPE_DATI completion:^(int errorCode, NSString *roomId, NSString *relayResult) {
        if (errorCode == 0) {
            // 发送答案成功才能更新
            self.currentQuiz.userAnswer = answer;
            NSLog(@"relay data send succeed");
        } else {
            NSLog(@"relay data send failed, errorCode: %d", errorCode);
            [self showAlert:@"发送答案失败" title:@"提示"];
        }
    }];
    
    if (!invokeSuccess) {
        NSLog(@"relay data invoke failed");
        [self showAlert:@"发送答案失败" title:@"提示"];
    }
}

#pragma mark - ZegoFinalStatViewControllerDelegate

- (void)onCloseButtonClicked:(id)sender {
    [self removeFinalStatController];
}

#pragma mark - Getter

- (ZegoActivityInfo *)activityInfo {
    if (_activityInfo == nil) {
        _activityInfo = [[ZegoActivityInfo alloc] init];
    }
    return _activityInfo;
}

- (NSMutableArray *)messageList {
    if (_messageList == nil) {
        _messageList = [[NSMutableArray alloc] init];
    }
    
    // 控制 messageList 条目数量，不清理会爆内存
    if ([_messageList count] > 200) {
        NSRange range = NSMakeRange([_messageList count] - 100, 100);
        NSMutableArray *tmp = [[_messageList subarrayWithRange:range] mutableCopy];
        _messageList = tmp;
    }
    
    return _messageList;
}

@end
