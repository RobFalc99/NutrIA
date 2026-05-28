package com.example.kcal_v1

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews

class KCaliWaterWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("kcal_widget_prefs", Context.MODE_PRIVATE)
        val water = prefs.getInt("kcal_water", 0)

        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId, water)
        }
    }

    companion object {
        fun updateAllWidgets(context: Context, water: Int) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, KCaliWaterWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(component)

            appWidgetIds?.forEach { appWidgetId ->
                updateAppWidget(context, appWidgetManager, appWidgetId, water)
            }
        }

        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            water: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.kcal_water_widget)

            // Current Volume
            views.setTextViewText(R.id.widget_water_volume, "$water ml")

            // Buttons
            views.setOnClickPendingIntent(R.id.btn_water_add_250, getPendingIntent(context, "add_water", 1001))
            views.setOnClickPendingIntent(R.id.btn_water_add_500, getPendingIntent(context, "add_water_500", 1004))

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun getPendingIntent(context: Context, actionType: String, requestCode: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.kcal.ACTION_WIDGET_CLICK"
                putExtra("widget_action", actionType)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getActivity(context, requestCode, intent, flags)
        }
    }
}
