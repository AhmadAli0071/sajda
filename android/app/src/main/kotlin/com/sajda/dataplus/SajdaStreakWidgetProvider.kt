package com.sajda.dataplus

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.time.LocalDate

/// Home screen "Streak" widget (feature F2).
///
/// Shows the last-known current streak and today's prayer progress (dots).
/// When the stored `widget_date` is not today, the day has rolled over —
/// the progress resets to 0/5 until the app refreshes it.
class SajdaStreakWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) updateOne(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> {
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(
                    ComponentName(context, SajdaStreakWidgetProvider::class.java)
                )
                if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
            }
        }
    }

    companion object {
        fun updateOne(context: Context, mgr: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences(
                "HomeWidgetPreferences", Context.MODE_PRIVATE
            )
            val streak = prefs.getInt("widget_streak", 0)
            val todayCount = prefs.getInt("widget_today", 0)
            val storedDate = prefs.getString("widget_date", null)

            // Day rolled over while the app was closed: progress restarts.
            val today = LocalDate.now().toString()
            val progress = if (storedDate == today) todayCount.coerceIn(0, 5) else 0

            val filled = "● ".repeat(progress)
            val empty = "○ ".repeat(5 - progress)
            val dots = (filled + empty).trim()

            val views = RemoteViews(context.packageName, R.layout.sajda_streak_widget)
            views.setTextViewText(R.id.widget_streak_days, streak.toString())
            views.setTextViewText(R.id.widget_streak_dots, dots)
            views.setTextViewText(R.id.widget_streak_today, "Today $progress/5")

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                val pi = PendingIntent.getActivity(
                    context, id, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_streak_root, pi)
            }
            mgr.updateAppWidget(id, views)
        }
    }
}
