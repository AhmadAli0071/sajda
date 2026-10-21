package com.sajda.dataplus

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import java.time.LocalTime

/// Home screen "Next Prayer" widget (feature F2).
///
/// Reads the prayer times the Dart side wrote into home_widget's
/// `HomeWidgetPreferences` and computes the next prayer itself so the
/// widget stays correct between app launches (30-min update period +
/// time/timezone change broadcasts).
class SajdaPrayerWidgetProvider : AppWidgetProvider() {
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
                    ComponentName(context, SajdaPrayerWidgetProvider::class.java)
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
            val fajr = prefs.getString("widget_fajr", null)
            val dhuhr = prefs.getString("widget_dhuhr", null)
            val asr = prefs.getString("widget_asr", null)
            val maghrib = prefs.getString("widget_maghrib", null)
            val isha = prefs.getString("widget_isha", null)

            val views = RemoteViews(context.packageName, R.layout.sajda_prayer_widget)
            views.setTextViewText(R.id.widget_fajr, to12h(fajr))
            views.setTextViewText(R.id.widget_dhuhr, to12h(dhuhr))
            views.setTextViewText(R.id.widget_asr, to12h(asr))
            views.setTextViewText(R.id.widget_maghrib, to12h(maghrib))
            views.setTextViewText(R.id.widget_isha, to12h(isha))

            val entries = listOfNotNull(
                fajr?.let { Pair("Fajr", it) },
                dhuhr?.let { Pair("Dhuhr", it) },
                asr?.let { Pair("Asr", it) },
                maghrib?.let { Pair("Maghrib", it) },
                isha?.let { Pair("Isha", it) }
            )
            if (entries.size == 5) {
                val now = LocalTime.now()
                val nowMin = now.hour * 60 + now.minute
                val next = entries.firstOrNull { toMin(it.second) > nowMin }
                if (next != null) {
                    views.setTextViewText(
                        R.id.widget_next, "${next.first} · ${to12h(next.second)}"
                    )
                    views.setViewVisibility(R.id.widget_tomorrow, View.GONE)
                } else {
                    // All five passed — Fajr is next, tomorrow.
                    views.setTextViewText(
                        R.id.widget_next, "Fajr · ${to12h(fajr)}"
                    )
                    views.setViewVisibility(R.id.widget_tomorrow, View.VISIBLE)
                }
            }

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                val pi = PendingIntent.getActivity(
                    context, id, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)
            }
            mgr.updateAppWidget(id, views)
        }

        /// "HH:mm" -> minutes since midnight; -1 when malformed.
        private fun toMin(hm: String): Int {
            val parts = hm.split(":")
            if (parts.size < 2) return -1
            val h = parts[0].trim().toIntOrNull() ?: return -1
            val m = parts[1].trim().take(2).toIntOrNull() ?: return -1
            return h * 60 + m
        }

        /// "HH:mm" -> "h:mm AM/PM" (widget shows 12-hour clock like the app).
        private fun to12h(hm: String?): String {
            if (hm.isNullOrBlank()) return "--:--"
            val min = toMin(hm)
            if (min < 0) return hm
            val h24 = min / 60
            val m = min % 60
            val suffix = if (h24 < 12) "AM" else "PM"
            val h12 = when {
                h24 == 0 -> 12
                h24 > 12 -> h24 - 12
                else -> h24
            }
            return "$h12:${m.toString().padStart(2, '0')} $suffix"
        }
    }
}
