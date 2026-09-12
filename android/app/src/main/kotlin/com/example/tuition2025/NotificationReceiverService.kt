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

        // Kiểm tra package của ứng dụng ngân hàng hoặc ví điện tử Việt Nam
        val isBankApp = isTrustedBankPackage(packageName)

        if (isBankApp) {
            // Lọc ra các thông báo giao dịch có phát sinh tăng số dư (cộng tiền / nhận tiền vào tài khoản)
            val fullText = "$title $text"
            val isCreditTransaction = text.contains("+") || 
                                       text.contains("cộng", ignoreCase = true) || 
                                       text.contains("nhận", ignoreCase = true) ||
                                       text.contains("có:", ignoreCase = true) ||
                                       text.contains("ps có", ignoreCase = true) ||
                                       text.contains("biến động số dư", ignoreCase = true) ||
                                       title.contains("cộng", ignoreCase = true) ||
                                       title.contains("nhận", ignoreCase = true)

            if (isCreditTransaction) {
                Log.d(TAG, "Detected bank credit transaction from $packageName! Sending broadcast...")
                val intent = Intent(ACTION_BANK_TRANSACTION)
                intent.putExtra(EXTRA_TITLE, title)
                intent.putExtra(EXTRA_TEXT, text)
                intent.putExtra(EXTRA_PACKAGE, packageName)
                sendBroadcast(intent)
            }
        }
    }

    private fun isTrustedBankPackage(pkg: String): Boolean {
        val lowerPkg = pkg.lowercase()
        val bankKeywords = listOf(
            "bank", "payment", "wallet", "sacombank", "vietcombank", "vcb",
            "mbbank", "mbmobile", "techcombank", "tcb", "vietinbank", "ctg",
            "bidv", "agribank", "vpbank", "tpbank", "acb", "ocb", "vib",
            "msb", "shb", "hdbank", "eximbank", "scb", "lpb", "lienviet",
            "shinhan", "woori", "seabank", "timo", "cake", "momo", "zalopay",
            "viettelpay", "vnptpay", "fintech", "napas"
        )
        return bankKeywords.any { lowerPkg.contains(it) }
    }
}
