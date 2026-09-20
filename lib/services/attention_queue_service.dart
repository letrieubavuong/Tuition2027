// File: lib/services/attention_queue_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/attention_item.dart';
import '../models/hs.dart';
import '../models/student_signal.dart';
import '../services/hoc_sinh_service.dart';
import '../services/lop_service.dart';
import '../services/student_signal_service.dart';
import '../services/smart_scheduling_service.dart';
import '../utils/db.dart';

class AttentionQueueService extends ChangeNotifier {
  static final AttentionQueueService instance =
      AttentionQueueService._internal();
  factory AttentionQueueService() => instance;
  AttentionQueueService._internal();

  final _dbHelper = DBHelper.instance;
  final _signalService = StudentSignalService();
  final _hsService = HocSinhService();
  final _lopService = LopService();

  Future<void>? _refreshInFlight;
  DateTime? _lastScheduleRecomputeTime;
  static const Duration _scheduleRecomputeTtl = Duration(minutes: 15);

  /// READ PATH: Pure cached / DB read query without recomputation
  Future<List<AttentionItem>> readAttentionQueue({
    String categoryFilter = 'all',
    bool activeOnly = true,
  }) async {
    final sw = Stopwatch()..start();
    developer.log('[AttentionQueue] readAttentionQueue START filter=$categoryFilter activeOnly=$activeOnly', name: 'AttentionQueueService');

    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();

      final maps = await db.query(
        DBHelper.tenBangAttentionItems,
        orderBy: 'created_at DESC',
      );

      final rawItems = maps.map((m) => AttentionItem.fromMap(m)).toList();
      final result = <AttentionItem>[];

      for (var item in rawItems) {
        if (activeOnly &&
            (item.status == AttentionStatus.resolved ||
                item.status == AttentionStatus.dismissed)) {
          continue;
        }

        if (activeOnly &&
            item.status == AttentionStatus.snoozed &&
            item.snoozedUntil != null &&
            item.snoozedUntil!.isAfter(now)) {
          continue;
        }

        if (categoryFilter != 'all') {
          if (categoryFilter == 'student' &&
              ![
                AttentionType.UNEXCUSED_ABSENCE,
                AttentionType.REPEATED_HOMEWORK_MISSING,
                AttentionType.LEARNING_SUPPORT_NEEDED,
                AttentionType.BEHAVIOR_ATTENTION,
              ].contains(item.type)) {
            continue;
          }
          if (categoryFilter == 'session' &&
              ![
                AttentionType.SESSION_ATTENDANCE_MISSING,
                AttentionType.SESSION_REVIEW_MISSING,
                AttentionType.SESSION_HOMEWORK_MISSING,
                AttentionType.SCHEDULE_CONFLICT,
              ].contains(item.type)) {
            continue;
          }
          if (categoryFilter == 'payment' &&
              ![
                AttentionType.TUITION_REMINDER_DUE,
                AttentionType.PAYMENT_NEEDS_REVIEW,
              ].contains(item.type)) {
            continue;
          }
          if (categoryFilter == 'parent' &&
              item.type != AttentionType.PARENT_CONTACT_PENDING) {
            continue;
          }
          if (categoryFilter == 'data' &&
              ![
                AttentionType.DATA_WARNING,
                AttentionType.STUDENT_PARTICIPATION_WARNING,
                AttentionType.SCHEDULE_CONFLICT,
              ].contains(item.type)) {
            continue;
          }
        }

        result.add(item);
      }

      result.sort((a, b) {
        final pComp = _priorityOrder(
          b.priority,
        ).compareTo(_priorityOrder(a.priority));
        if (pComp != 0) return pComp;

        final sComp = _severityOrder(
          b.severity,
        ).compareTo(_severityOrder(a.severity));
        if (sComp != 0) return sComp;

        return b.createdAt.compareTo(a.createdAt);
      });

      sw.stop();
      developer.log('[AttentionQueue] readAttentionQueue END durationMs=${sw.elapsedMilliseconds} rowCount=${result.length}', name: 'AttentionQueueService');
      return result;
    } catch (e, st) {
      sw.stop();
      developer.log('[AttentionQueue] readAttentionQueue ERROR: $e', name: 'AttentionQueueService', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Backward-compatible alias that defaults to read-only path
  Future<List<AttentionItem>> getAttentionQueue({
    String categoryFilter = 'all',
    bool activeOnly = true,
  }) async {
    return readAttentionQueue(
      categoryFilter: categoryFilter,
      activeOnly: activeOnly,
    );
  }

  /// RECOMPUTE PATH: Explicit refresh with single-flight guard
  Future<void> refreshAttentionSources({bool force = false}) {
    if (_refreshInFlight != null) {
      developer.log('[AttentionQueue] refreshAttentionSources in-flight request reused', name: 'AttentionQueueService');
      return _refreshInFlight!;
    }

    final future = _doRefreshAttentionSources(force: force);
    _refreshInFlight = future;
    return future;
  }

  Future<void> _doRefreshAttentionSources({bool force = false}) async {
    try {
      final sw = Stopwatch()..start();
      developer.log('[AttentionQueue] refreshAttentionSources START force=$force', name: 'AttentionQueueService');

      await _recomputeAllAttentionItems(forceScheduleRecompute: force);

      sw.stop();
      developer.log('[AttentionQueue] refreshAttentionSources END durationMs=${sw.elapsedMilliseconds}', name: 'AttentionQueueService');

      notifyListeners();
    } catch (e, st) {
      developer.log('[AttentionQueue] refreshAttentionSources ERROR: $e', name: 'AttentionQueueService', error: e, stackTrace: st);
      rethrow;
    } finally {
      _refreshInFlight = null;
    }
  }

  int _priorityOrder(AttentionPriority p) {
    switch (p) {
      case AttentionPriority.urgent:
        return 4;
      case AttentionPriority.high:
        return 3;
      case AttentionPriority.normal:
        return 2;
      case AttentionPriority.low:
        return 1;
    }
  }

  int _severityOrder(AttentionSeverity s) {
    switch (s) {
      case AttentionSeverity.critical:
        return 4;
      case AttentionSeverity.warning:
        return 3;
      case AttentionSeverity.attention:
        return 2;
      case AttentionSeverity.info:
        return 1;
    }
  }

  /// Summary Counts for Badge: Pure lightweight SQL query (< 100ms)
  Future<Map<String, int>> getSummaryCounts() async {
    final sw = Stopwatch()..start();
    developer.log('[AttentionQueue] getSummaryCounts START', name: 'AttentionQueueService');

    try {
      final db = await _dbHelper.database;
      final nowStr = DateTime.now().toIso8601String();

      final rows = await db.rawQuery(
        '''
        SELECT priority, severity, type, status, snoozed_until
        FROM ${DBHelper.tenBangAttentionItems}
        WHERE status IN ('ACTIVE', 'ACKNOWLEDGED', 'SNOOZED')
        ''',
      );

      int urgent = 0;
      int high = 0;
      int normal = 0;
      int total = 0;

      for (var row in rows) {
        final statusStr = row['status'] as String?;
        final snoozedUntilStr = row['snoozed_until'] as String?;

        if (statusStr == 'SNOOZED' && snoozedUntilStr != null) {
          if (snoozedUntilStr.compareTo(nowStr) > 0) {
            continue; // Currently snoozed
          }
        }

        final typeStr = row['type'] as String? ?? '';
        if (typeStr == AttentionType.BEHAVIOR_ATTENTION.name) {
          continue;
        }

        total++;
        final prioStr = row['priority'] as String? ?? '';
        final sevStr = row['severity'] as String? ?? '';

        if (prioStr == 'URGENT' || sevStr == 'CRITICAL') {
          urgent++;
        } else if (prioStr == 'HIGH' || sevStr == 'WARNING') {
          high++;
        } else {
          normal++;
        }
      }

      sw.stop();
      developer.log('[AttentionQueue] getSummaryCounts END durationMs=${sw.elapsedMilliseconds} urgent=$urgent high=$high normal=$normal total=$total', name: 'AttentionQueueService');

      return {
        'urgent': urgent,
        'high': high,
        'normal': normal,
        'total': total,
      };
    } catch (e, st) {
      sw.stop();
      developer.log('[AttentionQueue] getSummaryCounts ERROR: $e', name: 'AttentionQueueService', error: e, stackTrace: st);
      return {'urgent': 0, 'high': 0, 'normal': 0, 'total': 0};
    }
  }

  /// Đánh dấu đã nắm / đã xem (ACKNOWLEDGED)
  Future<void> acknowledge(dynamic idOrSignalId) async {
    final itemId = idOrSignalId.toString();
    await _updateItemStatus(itemId, AttentionStatus.acknowledged);
    notifyListeners();
  }

  /// Tạm ẩn (SNOOZE)
  Future<void> snooze(
    dynamic idOrSignalId, {
    Duration duration = const Duration(hours: 24),
    DateTime? until,
  }) async {
    final itemId = idOrSignalId.toString();
    final snoozedUntil = until ?? DateTime.now().add(duration);
    await _updateItemStatus(
      itemId,
      AttentionStatus.snoozed,
      snoozedUntil: snoozedUntil,
    );
    notifyListeners();
  }

  /// Giải quyết (RESOLVED)
  Future<void> resolve(dynamic idOrSignalId) async {
    final itemId = idOrSignalId.toString();
    await _updateItemStatus(itemId, AttentionStatus.resolved);
    notifyListeners();
  }

  /// Đóng / Bỏ qua (DISMISSED)
  Future<void> dismiss(dynamic idOrSignalId) async {
    final itemId = idOrSignalId.toString();
    await _updateItemStatus(itemId, AttentionStatus.dismissed);
    notifyListeners();
  }

  /// Auto-resolve matching items
  Future<void> autoResolve(
    AttentionType type, {
    int? studentId,
    int? classId,
    int? sessionId,
    String? sourceId,
  }) async {
    final db = await _dbHelper.database;
    final nowStr = DateTime.now().toIso8601String();

    String where = 'type = ? AND status IN (?, ?, ?)';
    List<dynamic> args = [type.name, 'ACTIVE', 'ACKNOWLEDGED', 'SNOOZED'];

    if (studentId != null) {
      where += ' AND student_id = ?';
      args.add(studentId);
    }
    if (classId != null) {
      where += ' AND class_id = ?';
      args.add(classId);
    }
    if (sessionId != null) {
      where += ' AND session_id = ?';
      args.add(sessionId);
    }
    if (sourceId != null) {
      where += ' AND source_id = ?';
      args.add(sourceId);
    }

    await db.update(
      DBHelper.tenBangAttentionItems,
      {'status': 'RESOLVED', 'due_at': nowStr},
      where: where,
      whereArgs: args,
    );
    notifyListeners();
  }

  Future<void> _updateItemStatus(
    String itemId,
    AttentionStatus status, {
    DateTime? snoozedUntil,
  }) async {
    final db = await _dbHelper.database;
    final Map<String, dynamic> updates = {'status': status.name.toUpperCase()};
    if (snoozedUntil != null) {
      updates['snoozed_until'] = snoozedUntil.toIso8601String();
    } else if (status != AttentionStatus.snoozed) {
      updates['snoozed_until'] = null;
    }

    await db.update(
      DBHelper.tenBangAttentionItems,
      updates,
      where: 'id = ? OR source_id = ?',
      whereArgs: [itemId, itemId],
    );

    final sigId = itemId.startsWith('sig_')
        ? int.tryParse(itemId.replaceAll('sig_', ''))
        : int.tryParse(itemId);
    if (sigId != null) {
      StudentSignalStatus sigStatus;
      switch (status) {
        case AttentionStatus.acknowledged:
          sigStatus = StudentSignalStatus.acknowledged;
          break;
        case AttentionStatus.snoozed:
          sigStatus = StudentSignalStatus.snoozed;
          break;
        case AttentionStatus.resolved:
          sigStatus = StudentSignalStatus.resolved;
          break;
        case AttentionStatus.dismissed:
          sigStatus = StudentSignalStatus.acknowledged;
          break;
        default:
          sigStatus = StudentSignalStatus.active;
      }
      await _signalService.updateSignalStatus(
        sigId,
        sigStatus,
        snoozedUntil: snoozedUntil,
      );
    }
  }

  /// Batched recomputation & Source Reconciliation
  Future<void> _recomputeAllAttentionItems({
    bool forceScheduleRecompute = false,
  }) async {
    final db = await _dbHelper.database;
    final totalSw = Stopwatch()..start();

    final activeSignals = await _signalService.getAllActiveSignals();
    final txRows = await db.query(
      'payment_transactions',
      where: 'status = ?',
      whereArgs: ['NEED_REVIEW'],
    );

    List<Map<String, dynamic>> commRows = [];
    try {
      commRows = await db.query(
        'parent_communications',
        where: 'trang_thai = ?',
        whereArgs: ['READY'],
      );
    } catch (e, st) {
      developer.log('[AttentionQueue] Failed to query parent_communications: $e', name: 'AttentionQueueService', error: e, stackTrace: st);
    }

    final studentIdsToFetch = <int>{};
    for (var sig in activeSignals) {
      studentIdsToFetch.add(sig.studentId);
    }
    for (var r in txRows) {
      final hsId = r['hoc_sinh_id'] as int?;
      if (hsId != null && hsId > 0) studentIdsToFetch.add(hsId);
    }
    for (var r in commRows) {
      final hsId = (r['id_hoc_sinh'] ?? r['student_id']) as int?;
      if (hsId != null && hsId > 0) studentIdsToFetch.add(hsId);
    }

    final studentMap = <int, HS>{};
    if (studentIdsToFetch.isNotEmpty) {
      final placeholders = List.filled(studentIdsToFetch.length, '?').join(',');
      final hsRows = await db.rawQuery(
        'SELECT * FROM ${DBHelper.tenBangHS} WHERE id IN ($placeholders)',
        studentIdsToFetch.toList(),
      );
      for (var r in hsRows) {
        final hs = HS.fromMap(r);
        if (hs.id != null) studentMap[hs.id!] = hs;
      }
    }

    final activeItemKeysInSources = <String>{};

    for (var sig in activeSignals) {
      final hs = studentMap[sig.studentId];
      if (hs == null) continue;

      if (sig.signalType == StudentSignalType.POSITIVE_STREAK) {
        continue;
      }

      AttentionType attType;
      AttentionSeverity sev;
      AttentionPriority prio;
      String actionType = 'timeline';
      String actionLabel = 'Xem Timeline';

      switch (sig.signalType) {
        case StudentSignalType.UNEXCUSED_ABSENCE_WARNING:
          attType = AttentionType.UNEXCUSED_ABSENCE;
          sev = AttentionSeverity.critical;
          prio = AttentionPriority.urgent;
          actionType = 'zalo';
          actionLabel = 'Liên hệ PH';
          break;
        case StudentSignalType.HOMEWORK_REPEATED_WARNING:
          attType = AttentionType.REPEATED_HOMEWORK_MISSING;
          sev = AttentionSeverity.warning;
          prio = AttentionPriority.high;
          actionType = 'timeline';
          actionLabel = 'Xem 5 buổi';
          break;
        case StudentSignalType.LEARNING_SUPPORT_WARNING:
          attType = AttentionType.LEARNING_SUPPORT_NEEDED;
          sev = AttentionSeverity.attention;
          prio = AttentionPriority.normal;
          actionType = 'timeline';
          actionLabel = 'Xem Timeline';
          break;
        case StudentSignalType.PAYMENT_OVERDUE:
          attType = AttentionType.TUITION_REMINDER_DUE;
          sev = AttentionSeverity.warning;
          prio = AttentionPriority.high;
          actionType = 'payment';
          actionLabel = 'Xem học phí';
          break;
        case StudentSignalType.POSITIVE_STREAK:
          attType = AttentionType.BEHAVIOR_ATTENTION;
          sev = AttentionSeverity.info;
          prio = AttentionPriority.low;
          actionType = 'timeline';
          actionLabel = 'Tuyên dương';
          break;
      }

      final itemKey = 'sig_${sig.id}';
      activeItemKeysInSources.add(itemKey);

      await _upsertAttentionItem(
        id: itemKey,
        type: attType,
        severity: sev,
        priority: prio,
        status: _convertSignalStatus(sig.status),
        title: '${hs.ten}: ${sig.title}',
        summary: sig.description,
        studentId: hs.id,
        studentName: hs.ten,
        sourceType: 'signal',
        sourceId: sig.id,
        createdAt: sig.createdAt,
        snoozedUntil: sig.snoozedUntil,
        actionType: actionType,
        actionLabel: actionLabel,
        metadata: sig.metadata,
      );
    }

    for (var row in txRows) {
      final txId = row['transaction_id']?.toString() ?? row['id'].toString();
      final hsId = row['hoc_sinh_id'] as int?;
      final amount = (row['amount'] as num?)?.toInt() ?? 0;
      final rawContent = row['raw_content'] as String? ?? 'Giao dịch ngân hàng';
      final itemKey = 'tx_$txId';
      activeItemKeysInSources.add(itemKey);

      final hs = hsId != null ? studentMap[hsId] : null;

      await _upsertAttentionItem(
        id: itemKey,
        type: AttentionType.PAYMENT_NEEDS_REVIEW,
        severity: AttentionSeverity.critical,
        priority: AttentionPriority.urgent,
        status: AttentionStatus.active,
        title: 'Giao dịch cần duyệt: ${NumberFormat("#,##0").format(amount)}đ',
        summary: hs != null
            ? 'Cần xác nhận khớp học phí cho ${hs.ten}: "$rawContent"'
            : 'Giao dịch chưa xác định được học sinh: "$rawContent"',
        studentId: hsId,
        studentName: hs?.ten,
        classId: row['lop_id'] as int?,
        sourceType: 'payment_transaction',
        sourceId: txId,
        createdAt:
            DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
        actionType: 'payment_review',
        actionLabel: 'Duyệt giao dịch',
        metadata: {'amount': amount, 'rawContent': rawContent, 'transactionId': row['id']},
      );
    }

    for (var row in commRows) {
      final commId = row['id'] as int;
      final hsId = (row['id_hoc_sinh'] ?? row['student_id']) as int?;
      if (hsId == null) continue;
      final hs = studentMap[hsId];
      if (hs == null) continue;

      final title =
          (row['ly_do'] ?? row['trigger_reason']) as String? ??
          'Cần nhắn phụ huynh';
      final msg =
          (row['noi_dung'] ?? row['prepared_message']) as String? ?? '';
      final classId = (row['id_lop'] ?? row['class_id']) as int?;
      final itemKey = 'comm_$commId';
      activeItemKeysInSources.add(itemKey);

      await _upsertAttentionItem(
        id: itemKey,
        type: AttentionType.PARENT_CONTACT_PENDING,
        severity: AttentionSeverity.warning,
        priority: AttentionPriority.high,
        status: AttentionStatus.active,
        title: 'Liên hệ PH ${hs.ten}: $title',
        summary: msg.isNotEmpty
            ? msg
            : 'Có tin nhắn đã chuẩn bị cho phụ huynh.',
        studentId: hsId,
        studentName: hs.ten,
        classId: classId,
        sourceType: 'parent_communication',
        sourceId: commId,
        createdAt:
            DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
        actionType: 'zalo',
        actionLabel: 'Liên hệ Zalo',
        metadata: {'preparedMessage': msg},
      );
    }

    final now = DateTime.now();
    final shouldRecomputeSchedule = forceScheduleRecompute ||
        _lastScheduleRecomputeTime == null ||
        now.difference(_lastScheduleRecomputeTime!) > _scheduleRecomputeTtl;

    if (shouldRecomputeSchedule) {
      try {
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final weekStartStr = monday.toIso8601String().substring(0, 10);
        final lopList = await _lopService.docDanhSachLop();

        for (var lop in lopList) {
          if (lop.id == null) continue;
          final res = await SmartSchedulingService.instance
              .analyzeBatchWeeklySchedules(
                classId: lop.id!,
                weekStartDate: weekStartStr,
              );

          final exceptions = [
            ...res.conflictedStudents,
            ...res.suggestedChanges,
          ];

          for (var item in exceptions) {
            final itemKey = 'sched_${item.studentId}_$weekStartStr';
            activeItemKeysInSources.add(itemKey);

            await _upsertAttentionItem(
              id: itemKey,
              type: AttentionType.SCHEDULE_CONFLICT,
              severity: AttentionSeverity.warning,
              priority: AttentionPriority.high,
              status: AttentionStatus.active,
              title: 'Xung đột lịch: ${item.studentName}',
              summary: '${item.conflictSummary} (Lớp ${lop.ten})',
              studentId: item.studentId,
              studentName: item.studentName,
              classId: lop.id,
              className: lop.ten,
              sourceType: 'schedule_conflict',
              sourceId: '${item.studentId}_$weekStartStr',
              createdAt: DateTime.now(),
              actionType: 'schedule',
              actionLabel: 'Xếp lịch tuần',
              metadata: {'weekRange': res.weekRange},
            );
          }
        }
        _lastScheduleRecomputeTime = now;
      } catch (e, st) {
        developer.log('[AttentionQueue] Error computing schedule conflicts: $e', name: 'AttentionQueueService', error: e, stackTrace: st);
      }
    }

    try {
      final existingItems = await db.query(
        DBHelper.tenBangAttentionItems,
        where: "status IN ('ACTIVE', 'ACKNOWLEDGED', 'SNOOZED')",
      );

      for (var r in existingItems) {
        final id = r['id'] as String;
        final sourceType = r['source_type'] as String?;

        if (sourceType != null &&
            [
              'signal',
              'payment_transaction',
              'parent_communication',
              'schedule_conflict',
            ].contains(sourceType)) {
          if (!activeItemKeysInSources.contains(id)) {
            await db.update(
              DBHelper.tenBangAttentionItems,
              {'status': 'RESOLVED'},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }
    } catch (e, st) {
      developer.log('[AttentionQueue] Error reconciling stale items: $e', name: 'AttentionQueueService', error: e, stackTrace: st);
    }

    totalSw.stop();
    developer.log('[AttentionQueue] _recomputeAllAttentionItems TOTAL durationMs=${totalSw.elapsedMilliseconds}', name: 'AttentionQueueService');
  }

  AttentionStatus _convertSignalStatus(StudentSignalStatus st) {
    switch (st) {
      case StudentSignalStatus.acknowledged:
        return AttentionStatus.acknowledged;
      case StudentSignalStatus.snoozed:
        return AttentionStatus.snoozed;
      case StudentSignalStatus.resolved:
        return AttentionStatus.resolved;
      default:
        return AttentionStatus.active;
    }
  }

  Future<void> _upsertAttentionItem({
    required String id,
    required AttentionType type,
    required AttentionSeverity severity,
    required AttentionPriority priority,
    required AttentionStatus status,
    required String title,
    required String summary,
    int? studentId,
    String? studentName,
    int? classId,
    String? className,
    int? sessionId,
    required String sourceType,
    dynamic sourceId,
    required DateTime createdAt,
    DateTime? snoozedUntil,
    required String actionType,
    required String actionLabel,
    Map<String, dynamic> metadata = const {},
  }) async {
    final db = await _dbHelper.database;

    final existingById = await db.query(
      DBHelper.tenBangAttentionItems,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    List<Map<String, dynamic>> existing = existingById;
    if (existing.isEmpty) {
      final whereParts = <String>['type = ?'];
      final whereArgs = <dynamic>[type.name];
      if (studentId != null) {
        whereParts.add('student_id = ?');
        whereArgs.add(studentId);
      }
      if (classId != null) {
        whereParts.add('class_id = ?');
        whereArgs.add(classId);
      }
      if (sessionId != null) {
        whereParts.add('session_id = ?');
        whereArgs.add(sessionId);
      }
      if (sourceId != null) {
        whereParts.add('source_id = ?');
        whereArgs.add(sourceId.toString());
      }

      existing = await db.query(
        DBHelper.tenBangAttentionItems,
        where: whereParts.join(' AND '),
        whereArgs: whereArgs,
        limit: 1,
      );
    }

    final item = AttentionItem(
      id: id,
      type: type,
      severity: severity,
      priority: priority,
      status: status,
      title: title,
      summary: summary,
      studentId: studentId,
      studentName: studentName,
      classId: classId,
      className: className,
      sessionId: sessionId,
      sourceType: sourceType,
      sourceId: sourceId,
      createdAt: createdAt,
      snoozedUntil: snoozedUntil,
      actionType: actionType,
      actionLabel: actionLabel,
      metadata: metadata,
    );

    if (existing.isEmpty) {
      await db.insert(DBHelper.tenBangAttentionItems, item.toMap());
    } else {
      final existingRow = existing.first;
      final existingId = existingRow['id'] as String;
      final existingStatus = existingRow['status'] as String?;
      final currentStatusStr =
          (existingStatus == 'ACKNOWLEDGED' ||
                  existingStatus == 'SNOOZED' ||
                  existingStatus == 'RESOLVED' ||
                  existingStatus == 'DISMISSED')
              ? existingStatus
              : status.name.toUpperCase();

      await db.update(
        DBHelper.tenBangAttentionItems,
        {
          'title': title,
          'summary': summary,
          'severity': severity.name.toUpperCase(),
          'priority': priority.name.toUpperCase(),
          'status': currentStatusStr,
          'student_id': studentId,
          'student_name': studentName,
          'class_id': classId,
          'class_name': className,
          'session_id': sessionId,
          'source_type': sourceType,
          'source_id': sourceId?.toString(),
          'action_type': actionType,
          'action_label': actionLabel,
          'metadata': jsonEncode(metadata),
        },
        where: 'id = ?',
        whereArgs: [existingId],
      );
    }
  }
}
