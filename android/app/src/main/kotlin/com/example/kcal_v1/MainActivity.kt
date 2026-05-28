package com.example.kcal_v1

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.example.kcal/widget"
    private var widgetActionToDeliver: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWidgetIntent(intent)
        deliverWidgetActionIfPossible()
    }

    private fun handleWidgetIntent(intent: Intent?) {
        if (intent != null && intent.action == "com.example.kcal.ACTION_WIDGET_CLICK") {
            widgetActionToDeliver = intent.getStringExtra("widget_action")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val calories = call.argument<Int>("calories") ?: 0
                    val goal = call.argument<Int>("goal") ?: 2000
                    val water = call.argument<Int>("water") ?: 0
                    
                    KCaliWidgetProvider.updateAllWidgets(applicationContext, calories, goal, water)
                    result.success(null)
                }
                "getWidgetAction" -> {
                    val action = widgetActionToDeliver
                    widgetActionToDeliver = null
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun deliverWidgetActionIfPossible() {
        if (widgetActionToDeliver != null && flutterEngine != null) {
            MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, WIDGET_CHANNEL).invokeMethod("onWidgetAction", widgetActionToDeliver)
            widgetActionToDeliver = null
        }
    }
}
