package com.example.kcal_v1

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews

class KCaliCalorieWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("kcal_widget_prefs", Context.MODE_PRIVATE)
        val calories = prefs.getInt("kcal_calories", 0)
        val goal = prefs.getInt("kcal_goal", 2000)

        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId, calories, goal)
        }
    }

    companion object {
        fun updateAllWidgets(context: Context, calories: Int, goal: Int) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, KCaliCalorieWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(component)

            appWidgetIds?.forEach { appWidgetId ->
                updateAppWidget(context, appWidgetManager, appWidgetId, calories, goal)
            }
        }

        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            calories: Int,
            goal: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.kcal_calorie_widget)

            // Consumed and Goal
            views.setTextViewText(R.id.widget_cal_consumed, "$calories")
            views.setTextViewText(R.id.widget_cal_goal, " / $goal kcal")

            // Progress Bar
            val progressPercent = if (goal > 0) (calories * 100 / goal) else 0
            views.setProgressBar(R.id.widget_cal_progress_bar, 100, progressPercent.coerceIn(0, 100), false)

            // Remaining
            val remaining = goal - calories
            if (remaining >= 0) {
                views.setTextViewText(R.id.widget_cal_remaining, "Rimanenti: $remaining kcal")
            } else {
                views.setTextViewText(R.id.widget_cal_remaining, "Superato di: ${-remaining} kcal")
            }

            // Click action to open manual input
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.kcal.ACTION_WIDGET_CLICK"
                putExtra("widget_action", "add_manual")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pendingIntent = PendingIntent.getActivity(context, 1002, intent, flags)
            views.setOnClickPendingIntent(R.id.btn_cal_action, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
