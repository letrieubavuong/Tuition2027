package com.example.tuition2025

import android.app.Notification
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class NotificationReceiverService : NotificationListenerService() {

    companion object {
        const val ACTION_BANK_TRANSACTION = "com.example.tuition2025.BANK_TRANSACTION"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_PACKAGE = "package"
        private const val TAG = "NotificationReceiver"
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification Listener connected successfully")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        
        val packageName = sbn.packageName ?: return
        val extras = sbn.notification.extras ?: return
        val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

        Log.d(TAG, "Notification received from package: $packageName | Title: $title | Text: $text")

        // Kiểm tra xem thông báo có thuộc về ngân hàng Sacombank không
        // Tên package Sacombank: com.sacombank.msacombank hoặc chứa từ khóa sacombank
        val isSacombank = packageName.contains("sacombank", ignoreCase = true) || 
                           title.contains("sacombank", ignoreCase = true) ||
                           text.contains("sacombank", ignoreCase = true)

        if (isSacombank) {
            // Lọc ra các thông báo giao dịch có phát sinh tăng số dư (cộng tiền vào tài khoản)
            // Ví dụ Sacombank: "GD: +50,000 VND..." hoặc có ký tự "+" đi kèm
            val isCreditTransaction = text.contains("+") || 
                                      text.contains("cộng", ignoreCase = true) || 
                                      text.contains("nhận", ignoreCase = true)

            if (isCreditTransaction) {
                Log.d(TAG, "Detected Sacombank credit transaction! Sending broadcast...")
                val intent = Intent(ACTION_BANK_TRANSACTION)
                intent.putExtra(EXTRA_TITLE, title)
                intent.putExtra(EXTRA_TEXT, text)
                intent.putExtra(EXTRA_PACKAGE, packageName)
                sendBroadcast(intent)
            }
        }
    }
}
