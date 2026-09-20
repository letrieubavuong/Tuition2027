package com.example.tuition2025

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class WidgetBackgroundWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    companion object {
        const val TAG = "WidgetBackgroundWorker"
        const val PREFS_NAME = "FlutterSharedPreferences"
    }

    override fun doWork(): Result {
        try {
            Log.d(TAG, "Running WidgetBackgroundWorker background execution...")
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val currentDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            val storedSnapshotDate = prefs.getString("flutter.date", "")

            val editor = prefs.edit()

            // Kiểm tra Chuyển ngày (Day Rollover) khi Flutter app chưa được mở vào ngày mới
            if (!storedSnapshotDate.isNullOrEmpty() && storedSnapshotDate != currentDateStr) {
                Log.d(TAG, "Day Rollover detected in background! Stored: $storedSnapshotDate, Now: $currentDateStr")

                val dayFormat = SimpleDateFormat("dd/MM/yyyy", Locale.getDefault())
                val formattedDateStr = "Hôm nay (${dayFormat.format(Date())})"

                editor.putString("widget_date", formattedDateStr)
                editor.putBoolean("is_stale", true)
                editor.apply()
            }

            // Yêu cầu AppWidgetManager cập nhật giao diện Widget
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, TuitionWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            if (appWidgetIds.isNotEmpty()) {
                val provider = TuitionWidgetProvider()
                provider.onUpdate(context, appWidgetManager, appWidgetIds, prefs)
            }

            val bankComponentName = ComponentName(context, BankQRWidgetProvider::class.java)
            val bankAppWidgetIds = appWidgetManager.getAppWidgetIds(bankComponentName)
            if (bankAppWidgetIds.isNotEmpty()) {
                val bankProvider = BankQRWidgetProvider()
                bankProvider.onUpdate(context, appWidgetManager, bankAppWidgetIds, prefs)
            }

            return Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Error in WidgetBackgroundWorker", e)
            return Result.failure()
        }
    }
}
