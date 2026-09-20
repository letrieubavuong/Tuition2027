package com.example.tuition2025

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.tuition2025/notification_listener"
    private var methodChannel: MethodChannel? = null

    private val transactionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == NotificationReceiverService.ACTION_BANK_TRANSACTION) {
                val title = intent.getStringExtra(NotificationReceiverService.EXTRA_TITLE) ?: ""
                val text = intent.getStringExtra(NotificationReceiverService.EXTRA_TEXT) ?: ""
                val pkg = intent.getStringExtra(NotificationReceiverService.EXTRA_PACKAGE) ?: ""

                val data = mapOf(
                    "title" to title,
                    "text" to text,
                    "package" to pkg
                )
                
                runOnUiThread {
                    methodChannel?.invokeMethod("onNotificationReceived", data)
                }
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationServiceEnabled" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "openNotificationListenerSettings" -> {
                    openNotificationListenerSettings()
                    result.success(true)
                }
                "rescheduleWidgetWorker" -> {
                    val interval = (call.argument<Int>("interval") ?: 80).toLong().coerceAtLeast(15L)
                    try {
                        val workManager = WorkManager.getInstance(applicationContext)
                        val periodicWork = PeriodicWorkRequestBuilder<WidgetBackgroundWorker>(
                            interval, TimeUnit.MINUTES
                        ).build()
                        workManager.enqueueUniquePeriodicWork(
                            "widget_periodic_refresh",
                            ExistingPeriodicWorkPolicy.REPLACE,
                            periodicWork
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WORK_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(NotificationReceiverService.ACTION_BANK_TRANSACTION)
        registerReceiver(transactionReceiver, filter)

        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val storedInterval = prefs.getString("flutter.widget_refresh_interval_minutes", null)
                ?: prefs.getString("widget_refresh_interval_minutes", "80")
            val intervalMinutes = storedInterval?.toLongOrNull()?.coerceAtLeast(15L) ?: 80L

            val workManager = WorkManager.getInstance(applicationContext)
            val periodicWork = PeriodicWorkRequestBuilder<WidgetBackgroundWorker>(
                intervalMinutes, TimeUnit.MINUTES
            ).build()
            workManager.enqueueUniquePeriodicWork(
                "widget_periodic_refresh",
                ExistingPeriodicWorkPolicy.KEEP,
                periodicWork
            )
            val immediateWork = OneTimeWorkRequestBuilder<WidgetBackgroundWorker>().build()
            workManager.enqueue(immediateWork)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to schedule WorkManager in MainActivity", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(transactionReceiver)
        } catch (e: Exception) {
            // Ignore if not registered
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!flat.isNullOrEmpty()) {
            val names = flat.split(":")
            for (name in names) {
                val cn = android.content.ComponentName.unflattenFromString(name)
                if (cn != null && cn.packageName == pkgName) {
                    return true
                }
            }
        }
        return false
    }

    private fun openNotificationListenerSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}

