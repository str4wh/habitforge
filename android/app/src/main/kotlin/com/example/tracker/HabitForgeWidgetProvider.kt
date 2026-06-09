package com.example.tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class HabitForgeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val rawStatement = prefs.getString("widget_why_statement", "").orEmpty()
        val progress = prefs.getString("widget_progress", "0 / 9 HABITS DONE TODAY").orEmpty()

        val statement = rawStatement.ifBlank {
            "OPEN HABITFORGE AND DEFINE YOUR WHY. YOU HAVE NO REASON WRITTEN DOWN YET."
        }

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.habit_forge_widget)
            views.setTextViewText(R.id.widget_statement, statement)
            views.setTextViewText(R.id.widget_progress, progress)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
