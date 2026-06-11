package com.example.tuition2025

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class TuitionWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.tuition_widget)

            // Retrieve date
            val dateText = widgetData.getString("widget_date", "Hôm nay")
            views.setTextViewText(R.id.widget_date, dateText)

            // Check if empty
            val isEmpty = widgetData.getBoolean("widget_empty", true)
            if (isEmpty) {
                views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)
                views.setViewVisibility(R.id.widget_class_container, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_empty_text, View.GONE)
                views.setViewVisibility(R.id.widget_class_container, View.VISIBLE)

                // Set Class 1
                val time1 = widgetData.getString("time_1", "")
                val name1 = widgetData.getString("name_1", "")
                if (!time1.isNullOrEmpty() || !name1.isNullOrEmpty()) {
                    views.setViewVisibility(R.id.widget_item_1, View.VISIBLE)
                    views.setTextViewText(R.id.widget_time_1, time1)
                    views.setTextViewText(R.id.widget_name_1, name1)
                } else {
                    views.setViewVisibility(R.id.widget_item_1, View.GONE)
                }

                // Set Class 2
                val time2 = widgetData.getString("time_2", "")
                val name2 = widgetData.getString("name_2", "")
                if (!time2.isNullOrEmpty() || !name2.isNullOrEmpty()) {
                    views.setViewVisibility(R.id.widget_item_2, View.VISIBLE)
                    views.setTextViewText(R.id.widget_time_2, time2)
                    views.setTextViewText(R.id.widget_name_2, name2)
                } else {
                    views.setViewVisibility(R.id.widget_item_2, View.GONE)
                }

                // Set Class 3
                val time3 = widgetData.getString("time_3", "")
                val name3 = widgetData.getString("name_3", "")
                if (!time3.isNullOrEmpty() || !name3.isNullOrEmpty()) {
                    views.setViewVisibility(R.id.widget_item_3, View.VISIBLE)
                    views.setTextViewText(R.id.widget_time_3, time3)
                    views.setTextViewText(R.id.widget_name_3, name3)
                } else {
                    views.setViewVisibility(R.id.widget_item_3, View.GONE)
                }

                // Set Class 4
                val time4 = widgetData.getString("time_4", "")
                val name4 = widgetData.getString("name_4", "")
                if (!time4.isNullOrEmpty() || !name4.isNullOrEmpty()) {
                    views.setViewVisibility(R.id.widget_item_4, View.VISIBLE)
                    views.setTextViewText(R.id.widget_time_4, time4)
                    views.setTextViewText(R.id.widget_name_4, name4)
                } else {
                    views.setViewVisibility(R.id.widget_item_4, View.GONE)
                }

                // Set Class 5
                val time5 = widgetData.getString("time_5", "")
                val name5 = widgetData.getString("name_5", "")
                if (!time5.isNullOrEmpty() || !name5.isNullOrEmpty()) {
                    views.setViewVisibility(R.id.widget_item_5, View.VISIBLE)
                    views.setTextViewText(R.id.widget_time_5, time5)
                    views.setTextViewText(R.id.widget_name_5, name5)
                } else {
                    views.setViewVisibility(R.id.widget_item_5, View.GONE)
                }

                // Set Class 6
                val time6 = widgetData.getString("time_6", "")
                val name6 = widgetData.getString("name_6", "")
                if (!time6.isNullOrEmpty() || !name6.isNullOrEmpty()) {
                    views.setViewVisibility(R.id.widget_item_6, View.VISIBLE)
                    views.setTextViewText(R.id.widget_time_6, time6)
                    views.setTextViewText(R.id.widget_name_6, name6)
                } else {
                    views.setViewVisibility(R.id.widget_item_6, View.GONE)
                }

                // Set Class 7
                val time7 = widgetData.getString("time_7", "")
                val name7 = widgetData.getString("name_7", "")
                if (!time7.isNullOrEmpty() || !name7.isNullOrEmpty()) {
                    views.setViewVisibility(R.id.widget_item_7, View.VISIBLE)
                    views.setTextViewText(R.id.widget_time_7, time7)
                    views.setTextViewText(R.id.widget_name_7, name7)
                } else {
                    views.setViewVisibility(R.id.widget_item_7, View.GONE)
                }

                // Set Class 8
                val time8 = widgetData.getString("time_8", "")
                val name8 = widgetData.getString("name_8", "")
                if (!time8.isNullOrEmpty() || !name8.isNullOrEmpty()) {
                    views.setViewVisibility(R.id.widget_item_8, View.VISIBLE)
                    views.setTextViewText(R.id.widget_time_8, time8)
                    views.setTextViewText(R.id.widget_name_8, name8)
                } else {
                    views.setViewVisibility(R.id.widget_item_8, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
