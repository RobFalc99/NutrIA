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
        val proteins = prefs.getInt("kcal_proteins", 0)
        val goalProteins = prefs.getInt("kcal_goal_proteins", 150)
        val carbs = prefs.getInt("kcal_carbs", 0)
        val goalCarbs = prefs.getInt("kcal_goal_carbs", 200)
        val fats = prefs.getInt("kcal_fats", 0)
        val goalFats = prefs.getInt("kcal_goal_fats", 60)

        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId, calories, goal, water, proteins, goalProteins, carbs, goalCarbs, fats, goalFats)
        }
    }

    companion object {
        fun updateAllWidgets(
            context: Context, 
            calories: Int, 
            goal: Int, 
            water: Int,
            proteins: Int,
            goalProteins: Int,
            carbs: Int,
            goalCarbs: Int,
            fats: Int,
            goalFats: Int
        ) {
            // Salva nelle preferenze condivise native
            val prefs = context.getSharedPreferences("kcal_widget_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putInt("kcal_calories", calories)
                putInt("kcal_goal", goal)
                putInt("kcal_water", water)
                putInt("kcal_proteins", proteins)
                putInt("kcal_goal_proteins", goalProteins)
                putInt("kcal_carbs", carbs)
                putInt("kcal_goal_carbs", goalCarbs)
                putInt("kcal_fats", fats)
                putInt("kcal_goal_fats", goalFats)
                apply()
            }

            // Forza l'aggiornamento grafico del layout del widget principale
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, KCaliWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(component)

            appWidgetIds?.forEach { appWidgetId ->
                updateAppWidget(context, appWidgetManager, appWidgetId, calories, goal, water, proteins, goalProteins, carbs, goalCarbs, fats, goalFats)
            }
        }

        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            calories: Int,
            goal: Int,
            water: Int,
            proteins: Int,
            goalProteins: Int,
            carbs: Int,
            goalCarbs: Int,
            fats: Int,
            goalFats: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.kcal_widget)

            // Assegna testi dinamici
            views.setTextViewText(R.id.widget_calories_text, "Calorie: $calories / $goal kcal")
            views.setTextViewText(R.id.widget_water_text, "💧 $water ml")

            // Barra di progresso calorie
            val progressPercent = if (goal > 0) (calories * 100 / goal) else 0
            views.setProgressBar(R.id.widget_progress_bar, 100, progressPercent.coerceIn(0, 100), false)

            // Proteine
            views.setTextViewText(R.id.widget_proteins_text, "Pro: $proteins / ${goalProteins}g")
            val proPercent = if (goalProteins > 0) (proteins * 100 / goalProteins) else 0
            views.setProgressBar(R.id.widget_proteins_progress, 100, proPercent.coerceIn(0, 100), false)

            // Carboidrati
            views.setTextViewText(R.id.widget_carbs_text, "Carb: $carbs / ${goalCarbs}g")
            val carbsPercent = if (goalCarbs > 0) (carbs * 100 / goalCarbs) else 0
            views.setProgressBar(R.id.widget_carbs_progress, 100, carbsPercent.coerceIn(0, 100), false)

            // Grassi
            views.setTextViewText(R.id.widget_fats_text, "Fat: $fats / ${goalFats}g")
            val fatsPercent = if (goalFats > 0) (fats * 100 / goalFats) else 0
            views.setProgressBar(R.id.widget_fats_progress, 100, fatsPercent.coerceIn(0, 100), false)

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
