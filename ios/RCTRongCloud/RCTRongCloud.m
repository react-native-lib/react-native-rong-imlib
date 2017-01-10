//
//  RCTRongCloud.m
//  RCTRongCloud
//
//  Created by LvBingru on 1/26/16.
//  Copyright © 2016 erica. All rights reserved.
//

#import "RCTRongCloud.h"
#import <RongIMLib/RongIMLib.h>
#import "RCTConvert+RongCloud.h"
#import <React/RCTUtils.h>
#import <React/RCTEventDispatcher.h>
#import "RCTRongCloudVoiceManager.h"
#import <React/RCTImageLoader.h>

#define OPERATION_FAILED (@"operation returns false.")

@interface RCTRongCloud()<RCIMClientReceiveMessageDelegate, RCConnectionStatusChangeDelegate>

@property (nonatomic, strong) NSMutableDictionary *userInfoDic;
@property (nonatomic, strong) RCTRongCloudVoiceManager *voiceManager;

@end

@implementation RCTRongCloud

RCT_EXPORT_MODULE(RCTRongIMLib);

@synthesize bridge = _bridge;

- (NSDictionary *)constantsToExport
{
    return @{};
};

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[RCIMClient sharedRCIMClient] setReceiveMessageDelegate:self object:nil];
        [[RCIMClient sharedRCIMClient] setRCConnectionStatusChangeDelegate:self];
        _voiceManager = [RCTRongCloudVoiceManager new];
    }
    return self;
}

- (void)dealloc
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    [client disconnect];
}

+ (void)registerAPI:(NSString *)aString
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[RCIMClient sharedRCIMClient] initWithAppKey:aString];
    });
}

+ (void)setDeviceToken:(NSData *)aToken
{
    NSString *token =
    [[[[aToken description] stringByReplacingOccurrencesOfString:@"<"
                                                      withString:@""]
      stringByReplacingOccurrencesOfString:@">"
      withString:@""]
     stringByReplacingOccurrencesOfString:@" "
     withString:@""];
    
    [[RCIMClient sharedRCIMClient] setDeviceToken:token];
}

RCT_EXPORT_METHOD(connect:(NSString *)token resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [[RCIMClient sharedRCIMClient] connectWithToken:token success:^(NSString *userId) {
        // Connect 成功
        resolve(userId);
    } error:^(RCConnectErrorCode status) {
        // Connect 失败
        reject([NSString stringWithFormat:@"%d", (int)status], @"Connection error", nil);
    }
                                     tokenIncorrect:^() {
                                         // Token 失效的状态处理
                                         reject(@"tokenIncorrect", @"Incorrect token provided.", nil);
                                     }];
}

// 断开与融云服务器的连接，并不再接收远程推送
RCT_EXPORT_METHOD(logout:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [[RCIMClient sharedRCIMClient] logout];
    resolve(nil);
}

// 断开与融云服务器的连接，但仍然接收远程推送
RCT_EXPORT_METHOD(disconnect:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [[RCIMClient sharedRCIMClient] disconnect];
    resolve(nil);
}

RCT_EXPORT_METHOD(getConversationList:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    NSArray *array = [[RCIMClient sharedRCIMClient] getConversationList:@[@(ConversationType_PRIVATE),
                                                                          @(ConversationType_DISCUSSION),
                                                                          @(ConversationType_GROUP),
                                                                          @(ConversationType_CHATROOM),
                                                                          @(ConversationType_CUSTOMERSERVICE),
                                                                          @(ConversationType_SYSTEM),
                                                                          @(ConversationType_APPSERVICE),
                                                                          @(ConversationType_PUBLICSERVICE),
                                                                          @(ConversationType_PUSHSERVICE)]];
    NSMutableArray *newArray = [NSMutableArray new];
    for (RCConversation *conv in array) {
        NSDictionary *convDic = [self.class _convertConversation:conv];
        [newArray addObject:convDic];
    }
    resolve(newArray);
}

RCT_EXPORT_METHOD(getLatestMessages: (RCConversationType) type targetId:(NSString*) targetId count:(int) count
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    NSArray* array = [[RCIMClient sharedRCIMClient] getLatestMessages:type targetId:targetId count:count];
    
    NSMutableArray* newArray = [NSMutableArray new];
    for (RCMessage* msg in array) {
        NSDictionary* convDic = [self.class _convertMessage:msg];
        [newArray addObject:convDic];
    }
    resolve(newArray);
}

RCT_EXPORT_METHOD(sendMessage: (RCConversationType) type targetId:(NSString*) targetId content:(NSDictionary*) json
                  pushContent: (NSString*) pushContent pushData:(NSString*) pushData
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    if ([[json valueForKey:@"type"] isEqualToString:@"image"]) {
        NSString * uri = [RCTConvert NSString:json[@"imageUrl"]];
        [self.bridge.imageLoader loadImageWithURLRequest:uri callback:^(NSError *error, UIImage *image) {
            dispatch_async([self methodQueue], ^(void) {
                if (error) {
                    reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
                    return;
                }
                RCImageMessage *content = [RCImageMessage messageWithImage:image];
                content.full = [json[@"full"] boolValue];
                content.extra = [RCTConvert NSString:json[@"extra"]];
                RCIMClient* client = [RCIMClient sharedRCIMClient];
                RCMessage* msg = [client sendImageMessage:type targetId:targetId content:content pushContent:pushContent
                                                 progress:^(int progress, long messageId) {
                                                     
                                                 }
                                                  success:^(long messageId){
                                                      [_bridge.eventDispatcher sendAppEventWithName:@"msgSendOk" body:@(messageId)];
                                                  } error:^(RCErrorCode code, long messageId){
                                                      NSMutableDictionary* dic = [NSMutableDictionary new];
                                                      dic[@"messageId"] = @(messageId);
                                                      dic[@"errCode"] = @((int)code);
                                                      [_bridge.eventDispatcher sendAppEventWithName:@"msgSendFailed" body:dic];
                                                  }];
                resolve([self.class _convertMessage:msg]);
            });
        }];
        
        return;
    }
    RCMessageContent* content = [RCTConvert RCMessageContent:json];
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    RCMessage* msg = [client sendMessage:type targetId:targetId content:content pushContent:pushContent
                                 success:^(long messageId){
                                     [_bridge.eventDispatcher sendAppEventWithName:@"msgSendOk" body:@(messageId)];
                                 } error:^(RCErrorCode code, long messageId){
                                     NSMutableDictionary* dic = [NSMutableDictionary new];
                                     dic[@"messageId"] = @(messageId);
                                     dic[@"errCode"] = @((int)code);
                                     [_bridge.eventDispatcher sendAppEventWithName:@"msgSendFailed" body:dic];
                                 }];
    resolve([self.class _convertMessage:msg]);
}

RCT_EXPORT_METHOD(insertMessage: (RCConversationType) type targetId:(NSString*) targetId senderId:(NSString*) senderId content:(NSDictionary*) json
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCMessageContent* content = [RCTConvert RCMessageContent:json];
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    RCMessage* msg = [client insertMessage:type targetId:targetId senderUserId:senderId sendStatus:SentStatus_SENT content:content];
    resolve([self.class _convertMessage:msg]);
}

RCT_EXPORT_METHOD(clearMessageUnreadStatus: (RCConversationType) type targetId:(NSString*) targetId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    [client clearMessagesUnreadStatus:type targetId:targetId];
    resolve(nil);
}

RCT_EXPORT_METHOD(canRecordVoice:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [_voiceManager canRecordVoice:^(NSError *error, NSDictionary *result) {
        if (error) {
            reject([NSString stringWithFormat:@"%ld", error.code], error.description, error);
        }
        else {
            resolve(result);
        }
    }];
}

RCT_EXPORT_METHOD(startRecordVoice:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [_voiceManager startRecord:^(NSError *error,NSDictionary *result) {
        if (error) {
            reject([NSString stringWithFormat:@"%ld", error.code], error.description, error);
        }
        else {
            resolve(result);
        }
    }];
}

RCT_EXPORT_METHOD(cancelRecordVoice)
{
    [_voiceManager cancelRecord];
}

RCT_EXPORT_METHOD(finishRecordVoice)
{
    [_voiceManager finishRecord];
}

RCT_EXPORT_METHOD(startPlayVoice:(RCMessageContent *)voice rosolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [_voiceManager startPlayVoice:(RCVoiceMessage *)voice result:^(NSError *error, NSDictionary *result) {
        if (error) {
            reject([NSString stringWithFormat:@"%ld", error.code], error.description, error);
        }
        else {
            resolve(result);
        }
    }];
}

RCT_EXPORT_METHOD(stopPlayVoice)
{
    [_voiceManager stopPlayVoice];
}



#pragma extra

/*!
 获取会话列表
 
 @param conversationTypeList 会话类型的数组(需要将RCConversationType转为NSNumber构建Array)
 @return                        会话RCConversation的列表
 
 @discussion 此方法会从本地数据库中，读取会话列表。
 返回的会话列表按照时间从前往后排列，如果有置顶的会话，则置顶的会话会排列在前面。
 */
RCT_EXPORT_METHOD(getConversationList2:(NSArray *)conversationTypeList
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    NSArray *ret = [client getConversationList:conversationTypeList];
    resolve(ret);
}

/*!
 获取单个会话数据
 
 @param conversationType    会话类型
 @param targetId            目标会话ID
 @return                    会话的对象
 */
RCT_EXPORT_METHOD(getConversation:(RCConversationType)conversationType
                  targetId:(NSString *)targetId
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    RCConversation *ret = [client getConversation:conversationType targetId:targetId];
    resolve(ret);
}


/*!
 获取会话中，从指定消息之前、指定数量的最新消息实体
 
 @param conversationType    会话类型
 @param targetId            目标会话ID
 @param oldestMessageId     截止的消息ID
 @param count               需要获取的消息数量
 @return                    消息实体RCMessage对象列表
 
 @discussion
 此方法会获取该会话中，oldestMessageId之前的、指定数量的最新消息实体，返回的消息实体按照时间从新到旧排列。
 返回的消息中不包含oldestMessageId对应那条消息，如果会话中的消息数量小于参数count的值，会将该会话中的所有消息返回。
 如：
 oldestMessageId为10，count为2，会返回messageId为9和8的RCMessage对象列表。
 */
RCT_EXPORT_METHOD(getHistoryMessages:(RCConversationType)conversationType
                  targetId:(NSString *)targetId
                  oldestMessageId:(long)oldestMessageId
                  count:(int)count
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    NSArray *ret = [client getHistoryMessages:conversationType targetId:targetId oldestMessageId:oldestMessageId count:count];
    resolve(ret);
}


/*!
 获取会话中，从指定消息之前、指定数量的、指定消息类型的最新消息实体
 
 @param conversationType    会话类型
 @param targetId            目标会话ID
 @param objectName          消息内容的类型名
 @param oldestMessageId     截止的消息ID
 @param count               需要获取的消息数量
 @return                    消息实体RCMessage对象列表
 
 @discussion
 此方法会获取该会话中，oldestMessageId之前的、指定数量和消息类型的最新消息实体，返回的消息实体按照时间从新到旧排列。
 返回的消息中不包含oldestMessageId对应的那条消息，如果会话中的消息数量小于参数count的值，会将该会话中的所有消息返回。
 如：
 oldestMessageId为10，count为2，会返回messageId为9和8的RCMessage对象列表。
 */
RCT_EXPORT_METHOD(getHistoryMessages2:(RCConversationType)conversationType
                  targetId:(NSString *)targetId
                  objectName:(NSString *)objectName
                  oldestMessageId:(long)oldestMessageId
                  count:(int)count
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    NSArray *ret = [client getHistoryMessages:conversationType targetId:targetId objectName:objectName oldestMessageId:oldestMessageId count:count];
    resolve(ret);
}

/*!
 获取会话中，从指定消息之前、指定数量的、指定消息类型、可以向前或向后查找的最新消息实体
 
 @param conversationType    会话类型
 @param targetId            目标会话ID
 @param objectName          消息内容的类型名
 @param baseMessageId       当前的消息ID
 @param isForward           查询方向 true为向前，false为向后
 @param count               需要获取的消息数量
 @return                    消息实体RCMessage对象列表
 
 @discussion
 此方法会获取该会话中，baseMessageId之前或之后的、指定数量、消息类型和查询方向的最新消息实体，返回的消息实体按照时间从新到旧排列。
 返回的消息中不包含baseMessageId对应的那条消息，如果会话中的消息数量小于参数count的值，会将该会话中的所有消息返回。
 */
RCT_EXPORT_METHOD(getHistoryMessages3:(RCConversationType)conversationType
                  targetId:(NSString *)targetId
                  objectName:(NSString *)objectName
                  baseMessageId:(long)baseMessageId
                  isForward:(BOOL)isForward
                  count:(int)count
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    NSArray *ret = [client getHistoryMessages:conversationType targetId:targetId objectName:objectName baseMessageId:baseMessageId isForward:isForward count:count];
    resolve(ret);
}

/*!
 设置会话的消息提醒状态
 
 @param conversationType            会话类型
 @param targetId                    目标会话ID
 @param isBlocked                   是否屏蔽消息提醒
 @param successBlock                设置成功的回调
 [nStatus:会话设置的消息提醒状态]
 @param errorBlock                  设置失败的回调 [status:设置失败的错误码]
 
 @discussion
 如果您使用IMLib，此方法会屏蔽该会话的远程推送；如果您使用IMKit，此方法会屏蔽该会话的所有提醒（远程推送、本地通知、前台提示音）。
 */
RCT_EXPORT_METHOD(setConversationNotificationStatus:(RCConversationType)conversationType targetId:(NSString *)targetId isBlocked:(BOOL)isBlocked
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    [client setConversationNotificationStatus:conversationType targetId:targetId isBlocked:isBlocked success:^(RCConversationNotificationStatus nStatus) {
        NSNumber *status = [NSNumber numberWithInt: nStatus];
        resolve(status);
    } error:^(RCErrorCode status) {
        NSNumber *err = [NSNumber numberWithInt: status];
        reject([NSString stringWithFormat:@"%ld", status], @"", NULL);
    }];
}

/*!
 查询会话的消息提醒状态
 
 @param conversationType    会话类型
 @param targetId            目标会话ID
 @param successBlock        查询成功的回调 [nStatus:会话设置的消息提醒状态]
 @param errorBlock          查询失败的回调 [status:设置失败的错误码]
 */
RCT_EXPORT_METHOD(getConversationNotificationStatus:(RCConversationType)conversationType targetId:(NSString *)targetId
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    [client getConversationNotificationStatus:conversationType targetId:targetId success:^(RCConversationNotificationStatus nStatus) {
        NSNumber *status = [NSNumber numberWithInt: nStatus];
        resolve(status);
    } error:^(RCErrorCode status) {
        NSNumber *err = [NSNumber numberWithInt: status];
        reject([NSString stringWithFormat:@"%ld", status], @"", NULL);
    }];
}

/*!
 获取某个会话内的未读消息数
 
 @param conversationType    会话类型
 @param targetId            会话目标ID
 @return                    该会话内的未读消息数
 */
RCT_EXPORT_METHOD(getTotalUnreadCount:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    int count = [client getTotalUnreadCount];
    NSNumber *retCount = [NSNumber numberWithInt: count];
    resolve(retCount);
}


/*!
 获取某个会话内的未读消息数
 
 @param conversationType    会话类型
 @param targetId            会话目标ID
 @return                    该会话内的未读消息数
 */
RCT_EXPORT_METHOD(getUnreadCount:(RCConversationType)conversationType targetId:(NSString *)targetId
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    int count = [client getUnreadCount:conversationType targetId:targetId];
    NSNumber *retCount = [NSNumber numberWithInt: count];
    resolve(retCount);
}

/*!
 获取某个类型的会话中所有的未读消息数
 
 @param conversationTypes   会话类型的数组
 @return                    该类型的会话中所有的未读消息数
 */
RCT_EXPORT_METHOD(getUnreadCount2:(NSArray *)conversationTypes
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    int count = [client getUnreadCount:conversationTypes];
    NSNumber *retCount = [NSNumber numberWithInt: count];
    resolve(retCount);
}


/*!
 删除消息
 
 @param messageIds  消息ID的列表
 @return            是否删除成功
 */
RCT_EXPORT_METHOD(deleteMessages:(NSArray *)messageIds
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    bool ret = [client deleteMessages:messageIds];
    NSNumber *retNum = [NSNumber numberWithBool: ret];
    resolve(retNum);
}


/*!
 删除某个会话中的所有消息
 
 @param conversationType    会话类型，不支持聊天室
 @param targetId            目标会话ID
 @param successBlock        成功的回调
 @param errorBlock          失败的回调
 
 @discussion 此方法删除数据库中该会话的消息记录，同时会整理压缩数据库，减少占用空间
 */
RCT_EXPORT_METHOD(deleteMessages2:(RCConversationType)conversationType
                  targetId:(NSString *)targetId
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    [client deleteMessages:conversationType targetId:targetId success:^{
        resolve(@1);
    } error:^(RCErrorCode status) {
        NSNumber *err = [NSNumber numberWithInt: status];
        reject([NSString stringWithFormat:@"%ld", status], @"", NULL);
    }];
}

/*!
 删除某个会话中的所有消息
 
 @param conversationType    会话类型，不支持聊天室
 @param targetId            目标会话ID
 @return                    是否删除成功
 */
RCT_EXPORT_METHOD(clearMessages:(RCConversationType)conversationType
                  targetId:(NSString *)targetId
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCIMClient* client = [RCIMClient sharedRCIMClient];
    bool ret = [client clearMessages:conversationType targetId:targetId];
    NSNumber *retNum = [NSNumber numberWithBool: ret];
    resolve(retNum);
}

/*!
 设置未读消息个数
 
 @param conversationType    会话类型，不支持聊天室
 @param targetId            目标会话ID
 @return                    是否删除成功
 */
RCT_EXPORT_METHOD(setBadgeVal:(int)badgeVal)
{
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    [UIApplication sharedApplication].applicationIconBadgeNumber = badgeVal;
}

#pragma mark - delegate
- (void)onReceived:(RCMessage *)message
              left:(int)nLeft
            object:(id)object
{
    [_bridge.eventDispatcher sendAppEventWithName:@"rongIMMsgRecved" body:[self.class _convertMessage:message]];
}

- (void)onConnectionStatusChanged:(RCConnectionStatus)status
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    switch (status){
        case ConnectionStatus_UNKNOWN:
            [dict setObject:@(-2) forKey:@"code"];
            [dict setObject:@"Unknown" forKey:@"message"];
            break;
        case ConnectionStatus_NETWORK_UNAVAILABLE:
            [dict setObject:@(-1) forKey:@"code"];
            [dict setObject:@"Network is unavailable." forKey:@"message"];
            break;
        case ConnectionStatus_Connected:
            [dict setObject:@(0) forKey:@"code"];
            [dict setObject:@"Connect Success." forKey:@"message"];
            break;
        case ConnectionStatus_Connecting:
            [dict setObject:@(1) forKey:@"code"];
            [dict setObject:@"Connecting" forKey:@"message"];
            break;
        case ConnectionStatus_Unconnected:
        case ConnectionStatus_SignUp:
            [dict setObject:@(2) forKey:@"code"];
            [dict setObject:@"Disconnected" forKey:@"message"];
            break;
        case ConnectionStatus_KICKED_OFFLINE_BY_OTHER_CLIENT:
            [dict setObject:@(3) forKey:@"code"];
            [dict setObject:@"Login on the other device, and be kicked offline." forKey:@"message"];
            break;
        case ConnectionStatus_TOKEN_INCORRECT:
            [dict setObject:@(4) forKey:@"code"];
            [dict setObject:@"Token incorrect." forKey:@"message"];
            break;
        case ConnectionStatus_SERVER_INVALID:
            [dict setObject:@(5) forKey:@"code"];
            [dict setObject:@"Server invalid." forKey:@"message"];
            break;
        case ConnectionStatus_Cellular_2G:
        case ConnectionStatus_Cellular_3G_4G:
        case ConnectionStatus_WIFI:
        case ConnectionStatus_LOGIN_ON_WEB:
        case ConnectionStatus_VALIDATE_INVALID:
        case ConnectionStatus_DISCONN_EXCEPTION:
        default:
            //ignore
            return;
    }
    [_bridge.eventDispatcher sendAppEventWithName:@"rongIMConnectionStatus" body:[dict copy]];
}

#pragma mark - private

+ (NSDictionary *)_convertConversation:(RCConversation *)conversation
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    dic[@"title"] = conversation.conversationTitle;
    dic[@"type"] = [self _convertConversationType: conversation.conversationType];
    dic[@"targetId"] = conversation.targetId;
    dic[@"unreadCount"] = @(conversation.unreadMessageCount);
    dic[@"lastMessage"] = [self _converMessageContent:conversation.lastestMessage];
    
    dic[@"isTop"] = @(conversation.isTop);
    dic[@"receivedStatus"] = @(conversation.receivedStatus);
    dic[@"sentStatus"] = @(conversation.sentStatus);
    dic[@"receivedTime"] = @(conversation.receivedTime);
    dic[@"sentTime"] = @(conversation.sentTime);
    dic[@"draft"] = conversation.draft;
    dic[@"objectName"] = conversation.objectName;
    dic[@"senderUserId"] = conversation.senderUserId;
    
    dic[@"conversationTitle"] = conversation.conversationTitle;
    
    dic[@"jsonDict"] = conversation.jsonDict;
    dic[@"lastestMessageId"] = @(conversation.lastestMessageId);
    return dic;
}

+ (NSString *) _convertConversationType: (RCConversationType) type
{
    switch(type) {
        case ConversationType_PRIVATE: return @"private";
        case ConversationType_DISCUSSION: return @"discussion";
        case ConversationType_GROUP: return @"group";
        case ConversationType_CHATROOM: return @"chatroom";
        case ConversationType_CUSTOMERSERVICE: return @"customer_service";
        case ConversationType_SYSTEM: return @"system";
        case ConversationType_APPSERVICE: return @"app_service";
        case ConversationType_PUBLICSERVICE: return @"public_service";
        case ConversationType_PUSHSERVICE: return @"push_service";
        default: return @"unknown";
    }
}

+ (NSDictionary *)_convertMessage:(RCMessage *)message
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    dic[@"senderId"] = message.senderUserId;
    dic[@"targetId"] = message.targetId;
    dic[@"conversationType"] = [self _convertConversationType: message.conversationType];;
    dic[@"extra"] = message.extra;
    dic[@"messageId"] = @(message.messageId);
    dic[@"receivedTime"] = @(message.receivedTime);
    dic[@"sentTime"] = @(message.sentTime);
    dic[@"content"] = [self _converMessageContent:message.content];
    
    dic[@"messageDirection"] = @(message.messageDirection);
    dic[@"receivedStatus"] = @(message.receivedStatus);
    dic[@"sentStatus"] = @(message.sentStatus);
    dic[@"objectName"] = message.objectName;
    dic[@"messageUId"] = message.messageUId;
    return dic;
}

+ (NSDictionary *)_converMessageContent:(RCMessageContent *)messageContent
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    if ([messageContent isKindOfClass:[RCTextMessage class]]) {
        RCTextMessage *message = (RCTextMessage *)messageContent;
        dic[@"type"] = @"text";
        dic[@"content"] = message.content;
        dic[@"extra"] = message.extra;
    }
    else if ([messageContent isKindOfClass:[RCVoiceMessage class]]) {
        RCVoiceMessage *message = (RCVoiceMessage *)messageContent;
        dic[@"type"] = @"voice";
        dic[@"duration"] = @(message.duration);
        dic[@"extra"] = message.extra;
        if (message.wavAudioData) {
            dic[@"base64"] = [message.wavAudioData base64EncodedStringWithOptions:(NSDataBase64EncodingOptions)0];
        }
    }
    else if ([messageContent isKindOfClass:[RCImageMessage class]]) {
        RCImageMessage *message = (RCImageMessage*)messageContent;
        dic[@"type"] = @"image";
        if ([[message.imageUrl substringToIndex:1] isEqualToString:@"/"]) {
            dic[@"imageUrl"] = [NSString stringWithFormat: @"file://%@", message.imageUrl];
        } else {
            dic[@"imageUrl"] = message.imageUrl;
        }
        dic[@"thumb"] = [NSString stringWithFormat:@"data:image/png;base64,%@", [UIImagePNGRepresentation(message.thumbnailImage) base64EncodedStringWithOptions:0]];
        dic[@"extra"] = message.extra;
    }
    else if ([messageContent isKindOfClass:[RCCommandNotificationMessage class]]){
        RCCommandNotificationMessage * message = (RCCommandNotificationMessage*)messageContent;
        dic[@"type"] = @"notify";
        dic[@"name"] = message.name;
        dic[@"data"] = message.data;
    }
    else {
        dic[@"type"] = @"unknown";
    }
    return dic;
}


@end
