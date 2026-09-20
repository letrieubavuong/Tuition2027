package com.example.tuition2025

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class TuitionWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.tuition_widget)

            // 1. Đọc dữ liệu từ SharedPreferences / Snapshot
            val dateText = getString(widgetData, "widget_date", "HÔM NAY")
            val todaySessionCount = getInt(widgetData, "today_session_count", 0)
            val todayTotalStudents = getInt(widgetData, "today_total_students", 0)
            val completedSessionCount = getInt(widgetData, "completed_session_count", 0)

            val widgetState = getString(widgetData, "widget_state", "NO_SESSION")
            val isStale = getBoolean(widgetData, "is_stale", false)
            val privacyMode = getString(widgetData, "privacy_mode", "FULL")

            val currentName = getString(widgetData, "current_session_name", "")
            val currentTime = getString(widgetData, "current_time", "")
            val currentAttendedCount = getInt(widgetData, "current_attended_count", 0)
            val currentResolvedCount = getInt(widgetData, "current_resolved_count", 0)
            val currentTotalCount = getInt(widgetData, "current_total_count", 0)

            val nextName = getString(widgetData, "next_session_name", "")
            val nextTime = getString(widgetData, "next_time", "")
            val nextTotalCount = getInt(widgetData, "next_total_count", 0)

            val attentionCount = getInt(widgetData, "attention_count", 0)
            val tuitionCount = getInt(widgetData, "tuition_count", 0)
            val parentCount = getInt(widgetData, "parent_count", 0)
            val studentAttentionCount = getInt(widgetData, "student_attention_count", 0)

            val dailyBriefSummary = getString(widgetData, "daily_brief_summary", "")
            val lastUpdatedAt = getString(widgetData, "last_updated_at", "")

            // 2. Gắn dữ liệu Top Bar Header (4×1)
            val headerDateDisplay = if (dateText.contains("(")) {
                val dayPart = dateText.substringBefore("(").trim()
                val datePart = dateText.substringAfter("(").substringBefore(")").trim()
                val shortDate = if (datePart.length >= 5) datePart.substring(0, 5) else datePart
                "${dayPart.uppercase()} • $shortDate"
            } else {
                dateText.uppercase()
            }
            views.setTextViewText(R.id.widget_header_date, headerDateDisplay)
            views.setTextViewText(
                R.id.widget_header_subtitle,
                if (todayTotalStudents > 0) "$todaySessionCount ca • $todayTotalStudents HS" else "$todaySessionCount ca dạy hôm nay"
            )
            views.setTextViewText(
                R.id.widget_header_badge,
                if (todaySessionCount > 0) "✓ $completedSessionCount/$todaySessionCount xong" else "Nghỉ dạy"
            )

            // 3. Gắn dữ liệu Ca hiện tại / Ca tiếp theo (4×2)
            when (widgetState) {
                "CURRENT_SESSION" -> {
                    views.setTextViewText(R.id.widget_session_title, "🔴 CA HIỆN TẠI")
                    val displayName = if (privacyMode == "COUNTS_ONLY") "Lớp học" else currentName
                    val detailText = if (currentTime.isNotEmpty()) "$currentTime • $displayName" else displayName
                    views.setTextViewText(R.id.widget_session_detail, detailText)

                    val attendanceText = when {
                        currentTotalCount == 0 -> "Chưa có sĩ số"
                        currentResolvedCount == 0 -> "$currentTotalCount HS • ○ Chưa điểm danh"
                        currentResolvedCount < currentTotalCount -> "$currentTotalCount HS • ● Đang điểm danh $currentResolvedCount/$currentTotalCount"
                        else -> "$currentTotalCount HS • ✓ Đã điểm danh ($currentAttendedCount/$currentTotalCount có mặt)"
                    }
                    views.setTextViewText(R.id.widget_session_attendance, attendanceText)
                }
                "NEXT_SESSION" -> {
                    views.setTextViewText(R.id.widget_session_title, "⏱ CA TIẾP THEO")
                    val displayName = if (privacyMode == "COUNTS_ONLY") "Lớp học" else nextName
                    val detailText = if (nextTime.isNotEmpty()) "$nextTime • $displayName" else displayName
                    views.setTextViewText(R.id.widget_session_detail, detailText)
                    views.setTextViewText(
                        R.id.widget_session_attendance,
                        "Sĩ số dự kiến: $nextTotalCount HS • Chuẩn bị ca học"
                    )
                }
                "EVENING_SUMMARY" -> {
                    views.setTextViewText(R.id.widget_session_title, "✓ HÔM NAY ĐÃ TỔNG KẾT")
                    views.setTextViewText(R.id.widget_session_detail, "Hoàn tất $completedSessionCount/$todaySessionCount ca dạy hôm nay")
                    views.setTextViewText(R.id.widget_session_attendance, "✓ Đã ghi nhận đầy đủ điểm danh & thu tiền")
                }
                else -> {
                    views.setTextViewText(R.id.widget_session_title, if (isStale) "⚠ DỮ LIỆU CŨ" else "☕ HÔM NAY")
                    views.setTextViewText(R.id.widget_session_detail, if (todaySessionCount == 0) "Hôm nay không có ca dạy" else "$todaySessionCount ca dạy scheduled")
                    views.setTextViewText(R.id.widget_session_attendance, if (dailyBriefSummary.isNotEmpty()) dailyBriefSummary else "Chuẩn bị cho ngày làm việc tiếp theo")
                }
            }

            // 4. Gắn dữ liệu Metrics Grid (2×2)
            views.setTextViewText(R.id.widget_val_attention, "$attentionCount việc")
            views.setTextViewText(R.id.widget_val_tuition, "$tuitionCount PH cần nhắc")
            views.setTextViewText(R.id.widget_val_parents, "$parentCount chưa liên hệ")
            views.setTextViewText(R.id.widget_val_students, "$studentAttentionCount cần chú ý")

            // 5. Gắn dữ liệu Bottom Footer (4×1)
            views.setTextViewText(
                R.id.widget_footer_brief,
                if (dailyBriefSummary.isNotEmpty()) dailyBriefSummary else "✓ Hôm nay ổn"
            )
            views.setTextViewText(
                R.id.widget_footer_time,
                if (lastUpdatedAt.isNotEmpty()) "• Cập nhật $lastUpdatedAt" else ""
            )

            // 6. Cấu hình Deep Links khi bấm vào Widget Buttons / Tiles
            val mainIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val diemDanhPendingIntent = PendingIntent.getActivity(
                context, 1001,
                mainIntent.apply { data = Uri.parse("tuition2025://diemdanh") },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val attentionPendingIntent = PendingIntent.getActivity(
                context, 1002,
                mainIntent.apply { data = Uri.parse("tuition2025://attention") },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val briefPendingIntent = PendingIntent.getActivity(
                context, 1003,
                mainIntent.apply { data = Uri.parse("tuition2025://dailybrief") },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.widget_btn_diemdanh, diemDanhPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_btn_ketthuc, diemDanhPendingIntent)

            views.setOnClickPendingIntent(R.id.widget_box_attention, attentionPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_box_tuition, briefPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_box_parents, briefPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_box_students, briefPendingIntent)

            views.setOnClickPendingIntent(R.id.widget_header_layout, briefPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_footer_layout, briefPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun getString(prefs: SharedPreferences, key: String, defaultVal: String): String {
        val keysToTry = listOf(key, "flutter.$key")
        for (k in keysToTry) {
            if (prefs.contains(k)) {
                try {
                    val raw = prefs.all[k]
                    if (raw != null) {
                        val str = raw.toString()
                        if (str.isNotEmpty()) return str
                    }
                } catch (e: Exception) {
                    // Try next key
                }
            }
        }
        return defaultVal
    }

    private fun getBoolean(prefs: SharedPreferences, key: String, defaultVal: Boolean): Boolean {
        val keysToTry = listOf(key, "flutter.$key")
        for (k in keysToTry) {
            if (prefs.contains(k)) {
                try {
                    val raw = prefs.all[k]
                    when (raw) {
                        is Boolean -> return raw
                        is String -> return raw.toBooleanStrictOrNull() ?: defaultVal
                        is Number -> return raw.toInt() != 0
                    }
                } catch (e: Exception) {
                    // Try next key
                }
            }
        }
        return defaultVal
    }

    private fun getInt(prefs: SharedPreferences, key: String, defaultVal: Int): Int {
        val keysToTry = listOf(key, "flutter.$key")
        for (k in keysToTry) {
            if (prefs.contains(k)) {
                try {
                    val raw = prefs.all[k]
                    when (raw) {
                        is Int -> return raw
                        is Long -> return raw.toInt()
                        is Number -> return raw.toInt()
                        is String -> return raw.toIntOrNull() ?: defaultVal
                    }
                } catch (e: Exception) {
                    // Try next key
                }
            }
        }
        return defaultVal
    }
}
