package com.example.tuition2025

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class WidgetBootReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "WidgetBootReceiver"
        const val PERIODIC_WORK_NAME = "widget_periodic_refresh"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "onReceive triggered with action: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == Intent.ACTION_DATE_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_TIME_CHANGED
        ) {
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val storedInterval = prefs.getString("flutter.widget_refresh_interval_minutes", null)
                    ?: prefs.getString("widget_refresh_interval_minutes", "80")
                val intervalMinutes = storedInterval?.toLongOrNull()?.coerceAtLeast(15L) ?: 80L

                val workManager = WorkManager.getInstance(context)

                // 1. Đăng ký Periodic WorkRequest định kỳ (Mặc định 80 phút, tối thiểu 15 phút)
                val periodicWork = PeriodicWorkRequestBuilder<WidgetBackgroundWorker>(
                    intervalMinutes, TimeUnit.MINUTES
                ).build()

                workManager.enqueueUniquePeriodicWork(
                    PERIODIC_WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    periodicWork
                )

                // 2. Chạy ngay 1-time WorkRequest để cập nhật ngày mới / reboot lập tức
                val immediateWork = OneTimeWorkRequestBuilder<WidgetBackgroundWorker>().build()
                workManager.enqueue(immediateWork)

                Log.d(TAG, "Successfully scheduled WorkManager background widget refresh for action: $action")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule WorkManager in WidgetBootReceiver", e)
            }
        }
    }
}
