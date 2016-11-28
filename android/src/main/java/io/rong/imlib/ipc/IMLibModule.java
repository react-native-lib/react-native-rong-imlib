package io.rong.imlib.ipc;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.media.MediaPlayer;
import android.media.MediaRecorder;
import android.net.Uri;
import android.support.annotation.Nullable;
import android.support.v4.app.NotificationCompat;
import android.util.Base64;
import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.UiThreadUtil;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.modules.core.RCTNativeAppEventEmitter;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

import io.rong.imlib.RongCommonDefine;
import io.rong.imlib.RongIMClient;
import io.rong.imlib.model.Conversation;
import io.rong.imlib.model.Message;
import io.rong.imlib.model.MessageContent;

/**
 * Created by tdzl2003 on 3/31/16.
 */
public class IMLibModule extends ReactContextBaseJavaModule implements RongIMClient.OnReceiveMessageListener, RongIMClient.ConnectionStatusListener, LifecycleEventListener {

    static boolean isIMClientInited = false;

    boolean hostActive = true;

    public IMLibModule(ReactApplicationContext reactContext) {
        super(reactContext);

        if (!isIMClientInited) {
            isIMClientInited = true;
            RongIMClient.init(reactContext.getApplicationContext());
        }

        reactContext.addLifecycleEventListener(this);
    }

    @Override
    public String getName() {
        return "RCTRongIMLib";
    }

    @Override
    public void initialize() {
        RongIMClient.setOnReceiveMessageListener(this);
        RongIMClient.setConnectionStatusListener(this);
    }

    @Override
    public void onCatalystInstanceDestroy() {
        RongIMClient.setOnReceiveMessageListener(null);
        RongIMClient.getInstance().disconnect();
    }

    private void sendDeviceEvent(String type, Object arg){
        ReactContext context = this.getReactApplicationContext();
        context.getJSModule(RCTNativeAppEventEmitter.class)
                .emit(type, arg);

    }

    @Override
    public boolean onReceived(Message message, int i) {
        sendDeviceEvent("rongIMMsgRecved", Utils.convertMessage(message));

        if (!hostActive) {
            Context context = getReactApplicationContext();
            NotificationManager mNotificationManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
            NotificationCompat.Builder mBuilder = new NotificationCompat.Builder(context);
            MessageContent content = message.getContent();
            String title = content.getUserInfo() != null ? content.getUserInfo().getName() : message.getSenderUserId();

            String contentString = Utils.convertMessageContentToString(content);
            mBuilder.setSmallIcon(context.getApplicationInfo().icon)
                    .setContentTitle(title)
                    .setContentText(contentString)
                    .setTicker(contentString)
                    .setAutoCancel(true)
                    .setDefaults(Notification.DEFAULT_ALL);

            Intent intent = new Intent();
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            Uri.Builder builder = Uri.parse("rong://" + context.getPackageName()).buildUpon();

            builder.appendPath("conversation").appendPath(message.getConversationType().getName())
                    .appendQueryParameter("targetId", message.getTargetId())
                    .appendQueryParameter("title", message.getTargetId());
            intent.setData(builder.build());
            mBuilder.setContentIntent(PendingIntent.getActivity(context, 0, intent, 0));

            Notification notification = mBuilder.build();
            mNotificationManager.notify(1000, notification);
        }
        return true;
    }

    RongIMClient client = null;

    @ReactMethod
    public void connect(String token, final Promise promise){
        if (client != null) {
            promise.reject("AlreadyLogined", "Is already logined.");
            return;
        }
        client = RongIMClient.connect(token, new RongIMClient.ConnectCallback() {
            /**
             * Token 错误，在线上环境下主要是因为 Token 已经过期，您需要向 App Server 重新请求一个新的 Token
             */
            @Override
            public void onTokenIncorrect() {
                promise.reject("tokenIncorrect", "Incorrect token provided.");
            }

            /**
             * 连接融云成功
             * @param userid 当前 token
             */
            @Override
            public void onSuccess(String userid) {
                promise.resolve(userid);
            }

            /**
             * 连接融云失败
             * @param errorCode 错误码，可到官网 查看错误码对应的注释
             */
            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    @ReactMethod
    public void getConversationList(final Promise promise){
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        client.getConversationList(new RongIMClient.ResultCallback<List<Conversation>>() {

            @Override
            public void onSuccess(List<Conversation> conversations) {
                promise.resolve(Utils.convertConversationList(conversations));
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    @ReactMethod
    public void logout(final Promise promise){
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        client.logout();
        client = null;
        promise.resolve(null);
    }

    @ReactMethod
    public void disconnect(final Promise promise){
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        client.disconnect();
        promise.resolve(null);
    }

    @ReactMethod
    public void getLatestMessages(String type, String targetId, int count, final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        client.getLatestMessages(Conversation.ConversationType.valueOf(type.toUpperCase()), targetId, count, new RongIMClient.ResultCallback<List<Message>>() {

            @Override
            public void onSuccess(List<Message> messages) {
                promise.resolve(Utils.convertMessageList(messages));
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    @ReactMethod
    public void sendMessage(final String type, final String targetId, final ReadableMap map, final String pushContent, final String pushData, final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        if ("image".equals(map.getString("type"))) {
            Utils.getImage(Uri.parse(map.getString("imageUrl")), null, new Utils.ImageCallback(){

                @Override
                public void invoke(@Nullable Bitmap bitmap) {
                    if (bitmap == null){
                        promise.reject("loadImageFailed", "Cannot open image uri ");
                        return;
                    }
                    MessageContent content;
                    try {
                        content = Utils.convertImageMessageContent(getReactApplicationContext(), bitmap);
                    } catch (Throwable e){
                        promise.reject("cacheImageFailed", e);
                        return;
                    }
                    client.sendImageMessage(Conversation.ConversationType.valueOf(type.toUpperCase()), targetId, content, pushContent, pushData, new RongIMClient.SendImageMessageCallback() {

                        @Override
                        public void onAttached(Message message) {
                            promise.resolve(Utils.convertMessage(message));
                        }

                        @Override
                        public void onError(Message message, RongIMClient.ErrorCode e) {
                            WritableMap ret = Arguments.createMap();
                            ret.putInt("messageId", message.getMessageId());
                            ret.putInt("errCode", e.getValue());
                            ret.putString("errMsg", e.getMessage());
                            sendDeviceEvent("msgSendFailed", ret);
                        }

                        @Override
                        public void onSuccess(Message message) {
                            sendDeviceEvent("msgSendOk", message.getMessageId());
                        }

                        @Override
                        public void onProgress(Message message, int i) {

                        }
                    });
                }
            });
            return;
        }
        client.sendMessage(Conversation.ConversationType.valueOf(type.toUpperCase()), targetId, Utils.convertToMessageContent(map), pushContent, pushData, new RongIMClient.SendMessageCallback() {
            @Override
            public void onError(Integer messageId, RongIMClient.ErrorCode e) {
                WritableMap ret = Arguments.createMap();
                ret.putInt("messageId", messageId);
                ret.putInt("errCode", e.getValue());
                ret.putString("errMsg", e.getMessage());
                sendDeviceEvent("msgSendFailed", ret);
            }

            @Override
            public void onSuccess(Integer messageId) {
                sendDeviceEvent("msgSendOk", messageId);

            }

        }, new RongIMClient.ResultCallback<Message>() {
            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }

            @Override
            public void onSuccess(Message message) {
                promise.resolve(Utils.convertMessage(message));
            }

        });
    }

    @ReactMethod
    public void insertMessage(String type, String targetId, String senderId, ReadableMap map, final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        client.insertMessage(Conversation.ConversationType.valueOf(type.toUpperCase()), targetId, senderId, Utils.convertToMessageContent(map),
                new RongIMClient.ResultCallback<Message>() {
                    @Override
                    public void onError(RongIMClient.ErrorCode errorCode) {
                        promise.reject("" + errorCode.getValue(), errorCode.getMessage());
                    }

                    @Override
                    public void onSuccess(Message message) {
                        promise.resolve(Utils.convertMessage(message));
                    }
                });
    }

    @ReactMethod
    public void clearMessageUnreadStatus(String type, String targetId, final Promise promise){
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        client.clearMessagesUnreadStatus(Conversation.ConversationType.valueOf(type.toUpperCase()), targetId, new RongIMClient.ResultCallback<Boolean>() {
            @Override
            public void onSuccess(Boolean aBoolean) {
                promise.resolve(null);
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    private MediaRecorder recorder;
    private Promise recordPromise;

    private File recordTarget = new File(this.getReactApplicationContext().getFilesDir(), "imlibrecord.amr");

    private long startTime;

    @ReactMethod
    public void startRecordVoice(Promise promise)
    {
        if (recorder != null) {
            cancelRecordVoice();
            return;
        }
        startTime = new Date().getTime();
        recorder = new MediaRecorder();// new出MediaRecorder对象
        // 设置MediaRecorder的音频源为麦克风
        recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        // 设置MediaRecorder录制的音频格式
        recorder.setOutputFormat(MediaRecorder.OutputFormat.AMR_NB);
        // 设置MediaRecorder录制音频的编码为amr.
        recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB);

        recorder.setAudioChannels(1);
        recorder.setAudioSamplingRate(8000);

        recorder.setOnErrorListener(new MediaRecorder.OnErrorListener() {
            @Override
            public void onError(MediaRecorder mr, int what, int extra) {
                Log.d("MediaRecord", "OnError: " + what + "" + extra);
            }
        });

        recorder.setOnInfoListener(new MediaRecorder.OnInfoListener() {
            @Override
            public void onInfo(MediaRecorder mr, int what, int extra) {
                Log.d("MediaRecord", "OnInfo: " + what + "" + extra);
            }
        });

        recorder.setOutputFile(recordTarget.toString());

        try {
            recorder.prepare();
        } catch (IOException e) {
            recorder.release();
            recorder = null;
            promise.reject(e);
            return;
        }
        recorder.start();
        recordPromise = promise;
    }

    @ReactMethod
    public void cancelRecordVoice()
    {
        if (recorder == null){
            return;
        }
        recorder.stop();
        recorder.release();
        recorder = null;
        recordPromise.reject("Canceled", "Record was canceled by user.");
        recordPromise = null;
    }

    @ReactMethod
    public void finishRecordVoice()
    {
        if (recorder == null){
            return;
        }
        recorder.stop();
        recorder.release();
        recorder = null;
        FileInputStream inputFile = null;
        try {
            WritableMap ret = Arguments.createMap();

            inputFile = new FileInputStream(recordTarget);
            byte[] buffer = new byte[(int) recordTarget.length()];
            inputFile.read(buffer);
            inputFile.close();
            ret.putString("type", "voice");
            ret.putString("base64", Base64.encodeToString(buffer, Base64.DEFAULT));
            ret.putString("uri", Uri.fromFile(recordTarget).toString());
            ret.putInt("duration", (int)(new Date().getTime() - startTime));
            recordPromise.resolve(ret);
        } catch (IOException e) {
            recordPromise.reject(e);
            e.printStackTrace();
        }
        recordPromise = null;
    }

    private MediaPlayer player;
    private Promise playerPromise;

    @ReactMethod
    public void startPlayVoice(ReadableMap map, Promise promise) {
        if (player != null){
            this.stopPlayVoice();
        }

        String strUri = map.getString("uri");
        player = MediaPlayer.create(this.getReactApplicationContext(), Uri.parse(strUri));
        playerPromise = promise;
        player.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
            @Override
            public void onCompletion(MediaPlayer mp) {
                onPlayComplete(mp);
            }
        });
        player.start();
    }

    //extra

    @ReactMethod
    public void getConversationList2(ReadableArray types, final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        Conversation.ConversationType[] conversationTypes = new Conversation.ConversationType[types.size()];
        for(int i=0;i<types.size();i++){
            conversationTypes[i] = Conversation.ConversationType.valueOf(types.getString(i).toUpperCase());
        }
        client.getConversationList(new RongIMClient.ResultCallback<List<Conversation>>() {
            @Override
            public void onSuccess(List<Conversation> conversations) {
                promise.resolve(Utils.convertConversationList(conversations));
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        }, conversationTypes);
    }

    @ReactMethod
    public void getConversation(String type, String targetId, final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        Conversation.ConversationType conversationType = Conversation.ConversationType.valueOf(type.toUpperCase());
        client.getConversation(conversationType, targetId, new RongIMClient.ResultCallback<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                promise.resolve(conversation);
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }


    @ReactMethod
    public void getHistoryMessages(String type, String targetId,
                                   Integer oldestMessageId, Integer count,
                                   final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        Conversation.ConversationType conversationType = Conversation.ConversationType.valueOf(type.toUpperCase());
        client.getHistoryMessages(conversationType, targetId, oldestMessageId, count, new RongIMClient.ResultCallback<List<Message>>() {
            @Override
            public void onSuccess(List<Message> messages) {
                promise.resolve(Utils.convertMessageList(messages));
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    @ReactMethod
    public void getHistoryMessages2(String type, String targetId,
                                   String objectName, Integer oldestMessageId, Integer count,
                                   final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        Conversation.ConversationType conversationType = Conversation.ConversationType.valueOf(type.toUpperCase());
        client.getHistoryMessages(conversationType, targetId, objectName, oldestMessageId, count, new RongIMClient.ResultCallback<List<Message>>() {
            @Override
            public void onSuccess(List<Message> messages) {
                promise.resolve(Utils.convertMessageList(messages));
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    @ReactMethod
    public void getHistoryMessages3(String type, String targetId,
                                    String objectName, Integer baseMessageId, Boolean isForward, Integer count,
                                    final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        Conversation.ConversationType conversationType = Conversation.ConversationType.valueOf(type.toUpperCase());
        RongCommonDefine.GetMessageDirection direction = RongCommonDefine.GetMessageDirection.BEHIND;
        if(isForward){
            direction = RongCommonDefine.GetMessageDirection.FRONT;
        }
        client.getHistoryMessages(conversationType, targetId, objectName, baseMessageId, count, direction, new RongIMClient.ResultCallback<List<Message>>() {
            @Override
            public void onSuccess(List<Message> messages) {
                promise.resolve(Utils.convertMessageList(messages));
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    @ReactMethod
    public void setConversationNotificationStatus(String type, String targetId,
                                    Boolean isBlocked,
                                    final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        Conversation.ConversationType conversationType = Conversation.ConversationType.valueOf(type.toUpperCase());

        Conversation.ConversationNotificationStatus val = Conversation.ConversationNotificationStatus.NOTIFY;
        if(isBlocked){
            val = Conversation.ConversationNotificationStatus.DO_NOT_DISTURB;
        }
        client.setConversationNotificationStatus(conversationType, targetId, val, new RongIMClient.ResultCallback<Conversation.ConversationNotificationStatus>() {
            @Override
            public void onSuccess(Conversation.ConversationNotificationStatus conversationNotificationStatus) {
                promise.resolve(conversationNotificationStatus);
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }


    @ReactMethod
    public void getConversationNotificationStatus(String type, String targetId,
                                                  final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }

        Conversation.ConversationType conversationType = Conversation.ConversationType.valueOf(type.toUpperCase());

        client.getConversationNotificationStatus(conversationType, targetId, new RongIMClient.ResultCallback<Conversation.ConversationNotificationStatus>() {
            @Override
            public void onSuccess(Conversation.ConversationNotificationStatus conversationNotificationStatus) {
                promise.resolve(conversationNotificationStatus);
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    @ReactMethod
    public void getTotalUnreadCount(final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        client.getTotalUnreadCount( new RongIMClient.ResultCallback<Integer>() {
            @Override
            public void onSuccess(Integer count) {
                promise.resolve(count);
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    @ReactMethod
    public void getUnreadCount(String type, String targetId, final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }

        Conversation.ConversationType conversationType = Conversation.ConversationType.valueOf(type.toUpperCase());

        client.getUnreadCount(conversationType, targetId, new RongIMClient.ResultCallback<Integer>() {
            @Override
            public void onSuccess(Integer count) {
                promise.resolve(count);
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }


    @ReactMethod
    public void getUnreadCount2(ReadableArray types, String targetId, final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }

        Conversation.ConversationType[] conversationTypes = new Conversation.ConversationType[types.size()];
        for(int i=0;i<types.size();i++){
            conversationTypes[i] = Conversation.ConversationType.valueOf(types.getString(i).toUpperCase());
        }
        client.getUnreadCount(conversationTypes, new RongIMClient.ResultCallback<Integer>() {
            @Override
            public void onSuccess(Integer count) {
                promise.resolve(count);
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    @ReactMethod
    public void deleteMessages(ReadableArray messageIds, final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }
        int[] mids = new int[messageIds.size()];
        for(int i=0;i<messageIds.size();i++){
            mids[i] = messageIds.getInt(i);
        }
        client.deleteMessages(mids, new RongIMClient.ResultCallback<Boolean>() {
            @Override
            public void onSuccess(Boolean ret) {
                promise.resolve(ret);
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    @ReactMethod
    public void deleteMessages2(String type, String targetId, final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }

        Conversation.ConversationType conversationType = Conversation.ConversationType.valueOf(type.toUpperCase());

        client.deleteMessages(conversationType, targetId, new RongIMClient.ResultCallback<Boolean>() {
            @Override
            public void onSuccess(Boolean ret) {
                promise.resolve(ret);
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }

    @ReactMethod
    public void clearMessages(String type, String targetId, final Promise promise) {
        if (client == null) {
            promise.reject("NotLogined", "Must call connect first.");
            return;
        }

        Conversation.ConversationType conversationType = Conversation.ConversationType.valueOf(type.toUpperCase());

        client.clearMessages(conversationType, targetId, new RongIMClient.ResultCallback<Boolean>() {
            @Override
            public void onSuccess(Boolean ret) {
                promise.resolve(ret);
            }

            @Override
            public void onError(RongIMClient.ErrorCode errorCode) {
                promise.reject("" + errorCode.getValue(), errorCode.getMessage());
            }
        });
    }


    private void onPlayComplete(MediaPlayer mp) {
        if (player == mp) {
            playerPromise.resolve(null);
            playerPromise = null;
            player.release();
            player = null;
        }
    }

    @ReactMethod
    public void stopPlayVoice() {
        if (player != null) {
            playerPromise.reject("Canceled", "Record was canceled by user.");
            playerPromise = null;
            player.stop();
            player.release();
            player = null;
        }
    }

    @Override
    public void onChanged(ConnectionStatus connectionStatus) {
        WritableMap map = Arguments.createMap();
        map.putInt("code", connectionStatus.getValue());
        map.putString("message", connectionStatus.getMessage());
        this.sendDeviceEvent("rongIMConnectionStatus", map);
    }

    @Override
    public void onHostResume() {
        this.hostActive = true;
    }

    @Override
    public void onHostPause() {
        this.hostActive = false;
    }

    @Override
    public void onHostDestroy() {

    }
}
