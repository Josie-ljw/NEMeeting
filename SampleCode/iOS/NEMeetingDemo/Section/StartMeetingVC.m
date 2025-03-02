// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

#import "StartMeetingVC.h"
#import "MeetingSettingVC.h"
#import "CheckBox.h"
#import "MeetingMenuSelectVC.h"
#import <IQKeyboardManager/IQKeyboardManager.h>
#import <NEMeetingKit/NEMeetingKit.h>
#import <YYModel/YYModel.h>
#import "MeetingConfigRepository.h"
#import "MeetingConfigEnum.h"

typedef NS_ENUM(NSInteger, MeetingMenuType) {
    MeetingMenuTypeToolbar = 1,
    MeetingMenuTypeMore = 2,
};

@interface StartMeetingVC ()<CheckBoxDelegate,MeetingMenuSelectVCDelegate,MeetingServiceListener>

@property (weak, nonatomic) IBOutlet CheckBox *configCheckBox;
@property (weak, nonatomic) IBOutlet CheckBox *settingCheckBox;
/// 会议号输入框
@property (weak, nonatomic) IBOutlet UITextField *meetingIdInput;
/// 昵称输入框
@property (weak, nonatomic) IBOutlet UITextField *nickInput;
/// 菜单按钮IId输入框
@property (weak, nonatomic) IBOutlet UITextField *coHostInput;
/// 菜单文本输入框
@property (weak, nonatomic) IBOutlet UITextField *extraInput;
/// tag输入框
@property (weak, nonatomic) IBOutlet UITextField *tagInput;
/// 会议密码输入框
@property (weak, nonatomic) IBOutlet UITextField *passwordInput;

@property (nonatomic, copy) NSString *meetingId;
@property (nonatomic, assign) BOOL audioOffAllowSelfOn;
@property (nonatomic, assign) BOOL audioOffNotAllowSelfOn;
@property (nonatomic, assign) BOOL videoOffAllowSelfOn;
@property (nonatomic, assign) BOOL videoOffNotAllowSelfOn;

@property (nonatomic, strong) NSArray <NEMeetingMenuItem *> *fullToolbarMenuItems;

@property (nonatomic, strong) NSArray <NEMeetingMenuItem *> *fullMoreMenuItems;
// 自定义菜单类型：toolbar/更多
@property (nonatomic, assign) MeetingMenuType currentType;
@end


@implementation StartMeetingVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [[NEMeetingKit getInstance].getMeetingService addListener:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [IQKeyboardManager sharedManager].enable = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [IQKeyboardManager sharedManager].enable = NO;
}

- (void)setupUI {
    [_configCheckBox setItemTitleWithArray:@[@"入会时打开摄像头",
                                             @"入会时打开麦克风",
                                             @"显示会议持续时间"]];
    [_settingCheckBox setItemTitleWithArray:@[@"入会时关闭聊天菜单",
                                              @"入会时关闭邀请菜单",
                                              @"入会时隐藏最小化",
                                              @"使用个人会议号",
                                              @"使用默认会议设置",
                                              @"入会时关闭画廊模式",
                                              @"仅显示会议ID长号",
                                              @"仅显示会议ID短号",
                                              @"关闭摄像头切换",
                                              @"关闭音频模式切换",
                                              @"展示白板",//10
                                              @"隐藏白板菜单按钮",
                                              @"关闭会中改名",
                                              @"开启云录制",
                                              @"隐藏Sip菜单",
                                              @"显示用户角色标签",
                                              @"自动静音(可解除)",
                                              @"自动静音(不可解除)",
                                              @"自动关视频(可解除)",
                                              @"自动关视频(不可解除)",
                                            ]];
    _settingCheckBox.delegate = self;
}
#pragma mark -----------------------------  自定义toolbar/更多 菜单  -----------------------------

- (void)didSelectedItems:(NSArray<NEMeetingMenuItem *> *)menuItems {
    if (self.currentType == MeetingMenuTypeToolbar) {
        self.fullToolbarMenuItems = menuItems;
    }else {
        self.fullMoreMenuItems = menuItems;
    }
    [self showSeletedItemResult:menuItems];
}
/// 结束会议
- (IBAction)doCloseMeeting:(id)sender {
    WEAK_SELF(weakSelf);
    [[NEMeetingKit.getInstance getMeetingService] leaveCurrentMeeting:YES callback:^(NSInteger resultCode, NSString *resultMsg, id resultData) {
        if (resultCode != ERROR_CODE_SUCCESS) {
            [weakSelf showErrorCode:resultCode msg:resultMsg];
        }
    }];
}

#pragma mark - Function
- (void)doStartMeeting {
    NEStartMeetingParams *params = [[NEStartMeetingParams alloc] init];
    // 昵称
    params.displayName = _nickInput.text;
    // 会议号
    params.meetingId = self.meetingId ? : _meetingIdInput.text;
    // 会议密码
    params.password = _passwordInput.text.length ? _passwordInput.text : nil;
    // 标签
    params.tag = _tagInput.text;
    // 额外参数
    params.extraData = _extraInput.text.length ? _extraInput.text : nil;
    
    // 联席主持人配置
    if (_coHostInput.text.length) {
        NSString *cohostText = _coHostInput.text;
        NSData *data = [cohostText dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        if (dic) params.roleBinds = dic.mutableCopy;
    }
    
    NSMutableArray<NEMeetingControl*> *controls = @[].mutableCopy;
    if (self.audioOffAllowSelfOn || self.audioOffNotAllowSelfOn) {
        NEMeetingControl* control = [NEMeetingControl createAudioControl];
        control.attendeeOff = self.audioOffAllowSelfOn ? AttendeeOffTypeOffAllowSelfOn : AttendeeOffTypeOffNotAllowSelfOn;
        [controls addObject: control];
    }
    if (self.videoOffAllowSelfOn || self.videoOffNotAllowSelfOn) {
        NEMeetingControl* control = [NEMeetingControl createVideoControl];
        control.attendeeOff = self.videoOffAllowSelfOn ? AttendeeOffTypeOffAllowSelfOn : AttendeeOffTypeOffNotAllowSelfOn;
        [controls addObject: control];
    }
    params.controls = controls.count ? controls : nil;
    
    NEStartMeetingOptions *options = [[NEStartMeetingOptions alloc] init];
    if (![self selectedSetting:CreateMeetingSettingTypeDefaultSetting]) {
        options.noVideo = ![self selectedConfig:MeetingConfigTypeJoinOnVideo];
        options.noAudio = ![self selectedConfig:MeetingConfigTypeJoinOnAudio];
        options.showMeetingTime = [self selectedConfig:MeetingConfigTypeShowTime];
    } else {
        NESettingsService *settingService = NEMeetingKit.getInstance.getSettingsService;
        options.noAudio = !settingService.isTurnOnMyAudioWhenJoinMeetingEnabled;
        options.noVideo = !settingService.isTurnOnMyVideoWhenJoinMeetingEnabled;
        options.showMeetingTime = settingService.isShowMyMeetingElapseTimeEnabled;
    }
    options.meetingIdDisplayOption = [self meetingIdDisplayOption];
    options.noInvite = [self selectedSetting:CreateMeetingSettingTypeJoinOffInvitation];
    options.noChat = [self selectedSetting:CreateMeetingSettingTypeJoinOffChatroom];
    options.noMinimize = [self selectedSetting:CreateMeetingSettingTypeHideMini];
    options.noGallery = [self selectedSetting:CreateMeetingSettingTypeJoinOffGallery];
    options.noSwitchCamera = [self selectedSetting:CreateMeetingSettingTypeOffSwitchCamera];
    options.noSwitchAudioMode = [self selectedSetting:CreateMeetingSettingTypeOffSwitchAudio];
    options.noRename = [self selectedSetting:CreateMeetingSettingTypeOffReName];
    options.noSip = [self selectedSetting:CreateMeetingSettingTypeHiddenSip];
    options.joinTimeout = [[MeetingConfigRepository getInstance] joinMeetingTimeout];
    options.showMemberTag = [self selectedSetting:CreateMeetingSettingTypeShowRoleLabel];
    
    //白板相关设置
    options.defaultWindowMode = [self selectedSetting:CreateMeetingSettingTypeShowWhiteboard] ? NEMeetingWindowModeWhiteBoard : NEMeetingWindowModeGallery;
    //设置是否隐藏菜单栏白板创建按钮
    options.noWhiteBoard = [self selectedSetting:CreateMeetingSettingTypeHiddenWhiteboardButton];
    options.noCloudRecord = ![self selectedSetting:CreateMeetingSettingTypeOpenCloudRecord];
    if ([MeetingConfigRepository getInstance].useMusicAudioProfile) {
        options.audioProfile = [NEAudioProfile createMusicAudioProfile];
    } else if ([MeetingConfigRepository getInstance].useSpeechAudioProfile) {
        options.audioProfile = [NEAudioProfile createSpeechAudioProfile];
    }
    
    options.noMuteAllAudio = [MeetingConfigRepository getInstance].noMuteAllAudio;
    options.noMuteAllVideo = [MeetingConfigRepository getInstance].noMuteAllVideo;
    options.fullToolbarMenuItems = _fullToolbarMenuItems;
    options.fullMoreMenuItems = _fullMoreMenuItems;
    
    WEAK_SELF(weakSelf);
    [SVProgressHUD show];
    [[NEMeetingKit getInstance].getMeetingService startMeeting:params
                                                          opts:options
                                                      callback:^(NSInteger resultCode, NSString *resultMsg, id result) {
        [SVProgressHUD dismiss];
        if (resultCode != ERROR_CODE_SUCCESS) {
            if (resultCode == MEETING_ERROR_FAILED_MEETING_ALREADY_EXIST) {
                [weakSelf showMessage:@"会议创建失败，该会议还在进行中"];
                return;
            }
            [weakSelf showErrorCode:resultCode msg:resultMsg];
        } else {
            weakSelf.fullMoreMenuItems = nil;
            weakSelf.fullToolbarMenuItems = nil;
        }
    }];
}

- (void)doGetUserMeetingId {
    WEAK_SELF(weakSelf);
    [SVProgressHUD show];
    
    [[NEMeetingKit getInstance].getAccountService getAccontInfo:^(NSInteger resultCode, NSString *resultMsg, id result) {
        [SVProgressHUD dismiss];
        if (resultCode != ERROR_CODE_SUCCESS) {
            [weakSelf showErrorCode:resultCode msg:resultMsg];
        } else {
            if (![result isKindOfClass:[NEAccountInfo class]] || result == nil) return;
            NEAccountInfo *accountInfo = result;
            self.meetingId = accountInfo.meetingId;
            NSString *meetingId = accountInfo.meetingId;
            if (accountInfo.shortMeetingId) {
                meetingId = [NSString stringWithFormat:@"%@(短号:%@)",meetingId,accountInfo.shortMeetingId];
            }
            weakSelf.meetingIdInput.text = meetingId;
        };
    }];
}

- (void)updateNickname {
    WEAK_SELF(weakSelf);
    [[NEMeetingKit getInstance].getSettingsService getHistoryMeetingItem:^(NSInteger resultCode, NSString* resultMsg, NSArray<NEHistoryMeetingItem *> * items) {
        if (items && items.count > 0) {
            NSLog(@"NEHistoryMeetingItem: %@ %@ %@", @(resultCode), resultMsg, items[0]);
            if ([items[0].meetingId isEqualToString: weakSelf.meetingIdInput.text]) {
                weakSelf.nickInput.text = items[0].nickname;
            }
        }
    }];
}

#pragma mark - MeetingServiceListener
- (void)onMeetingStatusChanged:(NEMeetingEvent *)event {
    if (event.status == MEETING_STATUS_DISCONNECTING) {
        [self updateNickname];
    }
}

#pragma mark - Actions
/// 创建会议
- (IBAction)onStartMeeting:(id)sender {
    [self doStartMeeting];
}
/// 自定义toolbar菜单
- (IBAction)configToolbarMenuItems:(UIButton *)sender {
    self.currentType = MeetingMenuTypeToolbar;
    [self enterMenuVC:_fullToolbarMenuItems];
}
/// 自定义更多菜单
- (IBAction)configMoreMenuItems:(UIButton *)sender {
    self.currentType = MeetingMenuTypeMore;
    [self enterMenuVC:_fullMoreMenuItems];
}
- (void)enterMenuVC:(NSArray *)items {
    MeetingMenuSelectVC *menuSeletedVC = [[MeetingMenuSelectVC alloc] init];
    menuSeletedVC.seletedItems = items;
    menuSeletedVC.delegate = self;
    [self.navigationController pushViewController:menuSeletedVC animated:YES];
}
- (void)showSeletedItemResult:(NSArray *)menuItems {
    if (!menuItems.count) return;
    
    NSString *string = @"已选";
    for (NEMeetingMenuItem *item in menuItems) {
        if ([item isKindOfClass:[NESingleStateMenuItem class]]) {
            NESingleStateMenuItem *single = (NESingleStateMenuItem *)item;
            string = [string stringByAppendingFormat:@" %@",single.singleStateItem.text];
        }else {
            NECheckableMenuItem *checkableItem = (NECheckableMenuItem *)item;
            string = [string stringByAppendingFormat:@" %@",checkableItem.checkedStateItem.text];
        }
    }
    [self.view makeToast:string];
}
#pragma mark -----------------------------  CheckBoxDelegate  -----------------------------
- (void)checkBoxItemdidSelected:(UIButton *)item
                        atIndex:(NSUInteger)index
                       checkBox:( CheckBox *)checkbox {
    if (checkbox != _settingCheckBox) return;
    
    if (index == 3) { //使用个人会议号
        if ([self selectedSetting:CreateMeetingSettingTypeUsePid]) {
            [self doGetUserMeetingId];
        }else {
            self.meetingIdInput.text = @"";
            self.meetingId = @"";
        }
    } else if (index == 4) {
        _configCheckBox.disableAllItems = [self selectedSetting:CreateMeetingSettingTypeDefaultSetting];
    }
    if (index == CreateMeetingSettingTypeAutoMuteAudio) {
        self.audioOffAllowSelfOn = item.selected;
    } else if (index == CreateMeetingSettingTypeAutoMuteAudioNotRemove) {
        self.audioOffNotAllowSelfOn = item.selected;
    } else if (index == CreateMeetingSettingTypeAutoMuteVideo) {
        self.videoOffAllowSelfOn = item.selected;
    } else if (index == CreateMeetingSettingTypeAutoMuteVideoNotRemove) {
        self.videoOffNotAllowSelfOn = item.selected;
    }
}

#pragma mark - Getter
- (BOOL)selectedConfig:(MeetingConfigType)configType {
    return [self.configCheckBox getItemSelectedAtIndex:configType];
}
- (BOOL)selectedSetting:(CreateMeetingSettingType)settingType {
    return [self.settingCheckBox getItemSelectedAtIndex:settingType];
}
- (BOOL)audioOffAllowSelfOn {
    return [self selectedSetting:CreateMeetingSettingTypeAutoMuteAudio];
}
- (void)setAudioOffAllowSelfOn:(BOOL)audioOffAllowSelfOn {
    [_settingCheckBox setItemSelected:audioOffAllowSelfOn index:CreateMeetingSettingTypeAutoMuteAudio];
    if (audioOffAllowSelfOn) {
        self.audioOffNotAllowSelfOn = NO;
    }
}

- (BOOL)audioOffNotAllowSelfOn {
    return [self selectedSetting:CreateMeetingSettingTypeAutoMuteAudioNotRemove];
}

- (void)setAudioOffNotAllowSelfOn:(BOOL)audioOffNotAllowSelfOn {
    [_settingCheckBox setItemSelected:audioOffNotAllowSelfOn index:CreateMeetingSettingTypeAutoMuteAudioNotRemove];
    if (audioOffNotAllowSelfOn) {
        self.audioOffAllowSelfOn = NO;
    }
}

- (BOOL)videoOffAllowSelfOn {
    return [self selectedSetting:CreateMeetingSettingTypeAutoMuteVideo];
}

- (void)setVideoOffAllowSelfOn:(BOOL)videoOffAllowSelfOn {
    [_settingCheckBox setItemSelected:videoOffAllowSelfOn index:CreateMeetingSettingTypeAutoMuteVideo];
    if (videoOffAllowSelfOn) {
        self.videoOffNotAllowSelfOn = NO;
    }
}

- (BOOL)videoOffNotAllowSelfOn {
    return [self selectedSetting:CreateMeetingSettingTypeAutoMuteVideoNotRemove];
}

- (void)setVideoOffNotAllowSelfOn:(BOOL)videoOffNotAllowSelfOn {
    [_settingCheckBox setItemSelected:videoOffNotAllowSelfOn index:CreateMeetingSettingTypeAutoMuteVideoNotRemove];
    if (videoOffNotAllowSelfOn) {
        self.videoOffAllowSelfOn = NO;
    }
}

- (NEMeetingIdDisplayOption)meetingIdDisplayOption {
    if ([self selectedSetting:CreateMeetingSettingTypeOnlyShowLongId]) {
        return DISPLAY_LONG_ID_ONLY;
    } else if ([self selectedSetting:CreateMeetingSettingTypeOnlyShowShortId]) {
        return DISPLAY_SHORT_ID_ONLY;
    }
    return DISPLAY_ALL;
}

@end

