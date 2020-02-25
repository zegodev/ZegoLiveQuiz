//
//  ZegoFinalStatViewController.m
//  LiveQuiz
//
//  Created by summeryxia on 31/01/2018.
//  Copyright © 2018 zego. All rights reserved.
//

#import "ZegoFinalStatViewController.h"
#import "ZegoUserCell.h"

NSString *const userCellIdentifier = @"ZegoUserCellIdentifier";

@interface ZegoFinalStatViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UILabel *statLabel;
@property (weak, nonatomic) IBOutlet UITableView *winnerTableView;
@property (weak, nonatomic) IBOutlet UILabel *congratuateLabel;

@property (nonatomic, strong) NSMutableArray<NSArray *> *winnerListInner;

@end

@implementation ZegoFinalStatViewController

#pragma mark - Life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.winnerTableView.delegate = self;
    self.winnerTableView.dataSource = self;
    self.winnerTableView.tableFooterView = [[UIView alloc] init];
    [self.winnerTableView registerNib:[UINib nibWithNibName:@"ZegoUserCell" bundle:nil] forCellReuseIdentifier:userCellIdentifier];
    
    self.statLabel.text = [NSString stringWithFormat:@"%ld人通关", (long)self.totalCount];
    
    if (self.totalCount == 0) {
        self.congratuateLabel.hidden = YES;
    }
    
    self.winnerListInner = [[NSMutableArray alloc] initWithCapacity:1];
    NSMutableArray *tmp = [[NSMutableArray alloc] init];

    for (int i = 0; i < self.winnerList.count; i++) {
        ZegoUser *user = self.winnerList[i];
        NSLog(@"%d-winner is: %@", i, user.userName);
        
        if (tmp.count < 3) {
            [tmp addObject:self.winnerList[i]];
        } else {
            NSArray *element = [NSArray arrayWithArray:tmp];
            [self.winnerListInner addObject:element];
            [tmp removeAllObjects];
            [tmp addObject:self.winnerList[i]];
        }
        
        if (i == self.winnerList.count - 1) {
            [self.winnerListInner addObject:tmp];
        }
    }

    for (NSMutableArray *tmp in self.winnerListInner) {
        while ([tmp count] < 3) {
            ZegoUser *user = [[ZegoUser alloc] init];
            user.userId = @"";
            user.userName = @"";
            [tmp addObject:user];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Event response

- (IBAction)onClose:(id)sender {
    if ([self.delegate respondsToSelector:@selector(onCloseButtonClicked:)]) {
        [self.delegate onCloseButtonClicked:sender];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.winnerListInner.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.winnerListInner count] == 0 || indexPath.row > self.winnerListInner.count) {
        return nil;
    }
    
    ZegoUserCell *cell = [tableView dequeueReusableCellWithIdentifier:userCellIdentifier];
    NSArray *users = self.winnerListInner[indexPath.row];
    
    ZegoUser *firstUser = users[0];
    ZegoUser *secondUser = users[1];
    ZegoUser *thirdUser = users[2];
    
    cell.firstUser = firstUser.userName;
    cell.secondUser = secondUser.userName;
    cell.thirdUser = thirdUser.userName;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 40;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    return nil;
}


@end
