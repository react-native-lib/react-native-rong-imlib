package io.rong.imlib.ipc;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import io.rong.push.notification.PushMessageReceiver;
import io.rong.push.notification.PushNotificationMessage;

/**
 * Created by tdzl2003 on 11/5/16.
 */
public class PushReceiver extends PushMessageReceiver {
    @Override
    public boolean onNotificationMessageArrived(Context context, PushNotificationMessage pushNotificationMessage) {
        return false;
    }

    @Override
    public boolean onNotificationMessageClicked(Context context, PushNotificationMessage pushNotificationMessage) {
        Intent intent = new Intent();
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        Uri.Builder builder = Uri.parse("rong://" + context.getPackageName()).buildUpon();

        ;
        builder.appendPath("conversation").
                appendQueryParameter("sessionType", pushNotificationMessage.getConversationType().name())
                .appendQueryParameter("sessionTargetId", pushNotificationMessage.getTargetId())
                .appendQueryParameter("msgExtra", pushNotificationMessage.getExtra())
                .appendQueryParameter("title", pushNotificationMessage.getPushTitle());
        Uri uri = builder.build();
        intent.setData(uri);
        intent.setAction(Intent.ACTION_VIEW);
        context.startActivity(intent);
        return true;
    }
}
