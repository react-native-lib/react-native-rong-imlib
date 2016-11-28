/**
 * Created by tdzl2003 on 4/13/16.
 */
'use strict';
import {NativeModules, NativeAppEventEmitter} from 'react-native';
import {EventEmitter} from 'fbemitter';

const RongIMLib = NativeModules.RongIMLib;

const emitter = new EventEmitter();
// Object.assign(exports, RongIMLib);
export const eventEmitter = emitter;
export const addListener = eventEmitter.addListener.bind(eventEmitter);
export const once = eventEmitter.once.bind(eventEmitter);
export const removeAllListeners = eventEmitter.removeAllListeners.bind(eventEmitter);
export const removeCurrentListener = eventEmitter.removeCurrentListener.bind(eventEmitter);

NativeAppEventEmitter.addListener('rongIMMsgRecved', msg => {
  eventEmitter.emit('msgRecved', msg);
});

NativeAppEventEmitter.addListener('rongIMConnectionStatus', msg => {
  eventEmitter.emit('connectionStatus', msg);
});

export const connect = async (token)=>{
    return await RongIMLib.connect(token)
}

export const logout = async ()=>{
    return await RongIMLib.logout()
}

export const disconnect = async ()=>{
    return await RongIMLib.disconnect()
}

export const getConversationList = async ()=>{
    return await RongIMLib.getConversationList()
}

export const getLatestMessages = async (type, targetId, count)=>{
    return await RongIMLib.getLatestMessages(type, targetId, count)
}

export const sendMessage = async (type, targetId, contentObj, pushContent, pushData)=>{
    return await RongIMLib.sendMessage(type, targetId, contentObj, pushContent, pushData)
}

export const insertMessage = async (type, targetId, senderId, contentObj)=>{
    return await RongIMLib.insertMessage(type, targetId, senderId, contentObj)
}

export const clearMessageUnreadStatus = async (type, targetId)=>{
    return await RongIMLib.clearMessageUnreadStatus(type, targetId)
}

export const canRecordVoice = async ()=>{
    return await RongIMLib.canRecordVoice()
}

export const startRecordVoice = async ()=>{
    return await RongIMLib.startRecordVoice()
}

export const cancelRecordVoice = ()=>{
    return RongIMLib.cancelRecordVoice()
}

export const finishRecordVoice = ()=>{
    return RongIMLib.finishRecordVoice()
}

export const startPlayVoice = async (voice)=>{
    return await RongIMLib.startPlayVoice(voice)
}

export const stopPlayVoice = ()=>{
    return RongIMLib.stopPlayVoice()
}

//extra

export const getConversationList2 = async (conversationTypeList)=>{
    return await RongIMLib.getConversationList2(conversationTypeList)
}

export const getConversation = async (conversationType, targetId)=>{
    return await RongIMLib.getConversationList(conversationType, targetId)
}

export const getHistoryMessages = async (conversationType, targetId, oldestMessageId, count)=>{
    return await RongIMLib.getHistoryMessages(conversationType, targetId, oldestMessageId, count)
}

export const getHistoryMessagesByObjName = async (conversationType, targetId, objectName, oldestMessageId, count)=>{
    return await RongIMLib.getHistoryMessages2(conversationType, targetId, objectName, oldestMessageId, count)
}

export const getHistoryMessagesWithForward = async (conversationType, targetId, objectName, baseMessageId, isForward, count)=>{
    return await RongIMLib.getHistoryMessages3(conversationType, targetId, objectName, baseMessageId, isForward, count)
}

export const setConversationNotificationStatus = async (conversationType, targetId, isBlocked)=>{
    return await RongIMLib.setConversationNotificationStatus(conversationType, targetId, isBlocked)
}

export const getConversationNotificationStatus = async (conversationType, targetId)=>{
    return await RongIMLib.getConversationNotificationStatus(conversationType, targetId)
}

export const getTotalUnreadCount = async ()=>{
    return await RongIMLib.getTotalUnreadCount()
}

export const getUnreadCount = async (conversationType, targetId)=>{
    return await RongIMLib.getUnreadCount(conversationType, targetId)
}

export const getUnreadCount2 = async (conversationTypes)=>{
    return await RongIMLib.getUnreadCount2(conversationTypes)
}

export const deleteMessages = async (messageIds)=>{
    return await RongIMLib.deleteMessages(messageIds)
}

export const deleteMessages2 = async (conversationType, targetId)=>{
    return await RongIMLib.deleteMessages2(conversationType, targetId)
}

export const clearMessages = async (conversationType, targetId)=>{
    return await RongIMLib.clearMessages(conversationType, targetId)
}

