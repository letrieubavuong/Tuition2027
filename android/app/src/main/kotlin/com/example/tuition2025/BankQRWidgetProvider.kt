package com.example.tuition2025

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class BankQRWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.bank_qr_widget)

            // Get bank info text
            val bankInfo = widgetData.getString("qr_bank_info", "Chưa cấu hình tài khoản")
            views.setTextViewText(R.id.widget_qr_info, bankInfo)

            // Get QR image path
            val qrPath = widgetData.getString("qr_image_path", "")
            if (!qrPath.isNullOrEmpty()) {
                val file = File(qrPath)
                if (file.exists()) {
                    try {
                        val bitmap = BitmapFactory.decodeFile(file.absolutePath)
                        views.setImageViewBitmap(R.id.widget_qr_image, bitmap)
                    } catch (e: Exception) {
                        // Fail silently
                    }
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
