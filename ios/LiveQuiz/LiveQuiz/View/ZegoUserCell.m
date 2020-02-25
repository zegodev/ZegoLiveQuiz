//
//  ZegoUserCell.m
//  LiveQuiz
//
//  Created by summeryxia on 01/02/2018.
//  Copyright © 2018 zego. All rights reserved.
//

#import "ZegoUserCell.h"


@interface ZegoUserCell ()

@property (weak, nonatomic) IBOutlet UILabel *firstUserLabel;
@property (weak, nonatomic) IBOutlet UILabel *secondUserLabel;
@property (weak, nonatomic) IBOutlet UILabel *thirdUserLabel;

@end

@implementation ZegoUserCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
    }
    
    return self;
}

- (void)setFirstUser:(NSString *)firstUser {
    self.firstUserLabel.text = firstUser;
}

- (void)setSecondUser:(NSString *)secondUser {
    self.secondUserLabel.text = secondUser;
}

- (void)setThirdUser:(NSString *)thirdUser {
    self.thirdUserLabel.text = thirdUser;
}

@end
