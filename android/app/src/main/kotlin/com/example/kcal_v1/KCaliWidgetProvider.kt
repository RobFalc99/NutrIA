package com.example.kcal_v1

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews

class KCaliWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("kcal_widget_prefs", Context.MODE_PRIVATE)
        val calories = prefs.getInt("kcal_calories", 0)
        val goal = prefs.getInt("kcal_goal", 2000)
        val water = prefs.getInt("kcal_water", 0)

        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId, calories, goal, water)
        }
    }

    companion object {
        fun updateAllWidgets(context: Context, calories: Int, goal: Int, water: Int) {
            // Salva nelle preferenze condivise native
            val prefs = context.getSharedPreferences("kcal_widget_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putInt("kcal_calories", calories)
                putInt("kcal_goal", goal)
                putInt("kcal_water", water)
                apply()
            }

            // Forza l'aggiornamento grafico del layout
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, KCaliWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(component)

            appWidgetIds?.forEach { appWidgetId ->
                updateAppWidget(context, appWidgetManager, appWidgetId, calories, goal, water)
            }
        }

        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            calories: Int,
            goal: Int,
            water: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.kcal_widget)

            // Assegna testi dinamici
            views.setTextViewText(R.id.widget_calories_text, "Calorie: $calories / $goal kcal")
            views.setTextViewText(R.id.widget_water_text, "💧 $water ml")

            // Barra di progresso
            val progressPercent = if (goal > 0) (calories * 100 / goal) else 0
            views.setProgressBar(R.id.widget_progress_bar, 100, progressPercent.coerceIn(0, 100), false)

            // Associa intent di click
            views.setOnClickPendingIntent(R.id.btn_add_water, getPendingIntent(context, "add_water"))
            views.setOnClickPendingIntent(R.id.btn_add_manual, getPendingIntent(context, "add_manual"))
            views.setOnClickPendingIntent(R.id.btn_add_ia, getPendingIntent(context, "ai_pasto"))

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun getPendingIntent(context: Context, actionType: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.kcal.ACTION_WIDGET_CLICK"
                putExtra("widget_action", actionType)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val requestCode = when (actionType) {
                "add_water" -> 1001
                "add_manual" -> 1002
                "ai_pasto" -> 1003
                else -> 1000
            }
            return PendingIntent.getActivity(context, requestCode, intent, flags)
        }
    }
}
