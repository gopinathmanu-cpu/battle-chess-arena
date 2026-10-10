package com.manugopinath.battlechessarena

import android.app.NotificationChannel
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import kotlin.math.max

class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        removeScheduledId(context, intent.getStringExtra("id") ?: "online")
        show(
            context,
            intent.getStringExtra("id") ?: "online",
            intent.getStringExtra("title") ?: "Battle Chess Arena",
            intent.getStringExtra("body") ?: "Online game update",
        )
    }

    companion object {
        private const val channelId = "online_games"
        private const val preferencesName = "battle_chess_notifications"
        private const val scheduledIdsKey = "scheduled_ids"

        fun pendingIntent(
            context: Context,
            id: String,
            title: String,
            body: String,
        ): PendingIntent {
            val intent = Intent(context, NotificationReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", title)
                putExtra("body", body)
            }
            return PendingIntent.getBroadcast(
                context,
                id.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun ensureChannel(context: Context) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        channelId,
                        "Online games",
                        NotificationManager.IMPORTANCE_HIGH,
                    ).apply {
                        description = "Invitations, opponents joining, and online moves"
                    },
                )
            }
        }

        fun show(context: Context, id: String, title: String, body: String) {
            ensureChannel(context)
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val contentIntent = launch?.let {
                PendingIntent.getActivity(
                    context,
                    id.hashCode(),
                    it.apply {
                        if (id.startsWith("game:")) {
                            action = Intent.ACTION_VIEW
                            data = android.net.Uri.Builder().scheme("battlechessarena").authority("join")
                                .appendQueryParameter("game", id.removePrefix("game:")).build()
                        }
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.app.Notification.Builder(context, channelId)
            } else {
                @Suppress("DEPRECATION")
                android.app.Notification.Builder(context)
            }
            builder
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(android.app.Notification.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setContentIntent(contentIntent)
            manager.notify(id.hashCode(), builder.build())
        }

        fun schedule(context: Context, id: String, title: String, body: String, at: Long) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                max(at, System.currentTimeMillis()),
                pendingIntent(context, id, title, body),
            )
            val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            val ids = preferences.getStringSet(scheduledIdsKey, emptySet())!!.toMutableSet()
            ids.add(id)
            preferences.edit().putStringSet(scheduledIdsKey, ids).apply()
        }

        fun cancel(context: Context, id: String) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.cancel(pendingIntent(context, id, "", ""))
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(id.hashCode())
            removeScheduledId(context, id)
        }

        fun cancelAll(context: Context) {
            val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            val ids = preferences.getStringSet(scheduledIdsKey, emptySet())!!.toList()
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (id in ids) alarm.cancel(pendingIntent(context, id, "", ""))
            preferences.edit().remove(scheduledIdsKey).apply()
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
        }

        private fun removeScheduledId(context: Context, id: String) {
            val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            val ids = preferences.getStringSet(scheduledIdsKey, emptySet())!!.toMutableSet()
            if (ids.remove(id)) preferences.edit().putStringSet(scheduledIdsKey, ids).apply()
        }
    }
}
