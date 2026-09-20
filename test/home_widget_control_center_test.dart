// File: test/home_widget_control_center_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tuition2025/models/home_widget_snapshot.dart';
import 'package:tuition2025/widgets/home_widget_snapshot_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  Widget buildCard(
    HomeWidgetSnapshot snapshot, {
    Function(HomeWidgetActionPayload)? onNavigatePayload,
    Function(String)? onNavigate,
    VoidCallback? onRefresh,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: HomeWidgetSnapshotCard(
          snapshot: snapshot,
          onNavigatePayload: onNavigatePayload,
          onNavigate: onNavigate,
          onRefresh: onRefresh,
        ),
      ),
    );
  }

  group('Home Widget Control Center Final Mini-Fix Tests', () {
    // TEST 1: attendance action -> đúng session payload
    testWidgets(
      'TEST 1: Attendance action dispatches attendance payload with session identity',
      (tester) async {
        HomeWidgetActionPayload? receivedPayload;

        final snapshot = HomeWidgetSnapshot(
          date: '2026-09-18',
          dateFormatted: 'Thứ Sáu (18/09/2026)',
          widgetState: 'CURRENT_SESSION',
          todaySessionCount: 1,
          completedSessionCount: 0,
          currentClassId: 105,
          currentScheduleId: 42,
          currentSessionDate: '2026-09-18',
          currentSessionName: 'Lớp 12A',
          currentStart: '17:30',
          currentEnd: '19:00',
          attentionCount: 0,
          criticalCount: 0,
          unexcusedAbsenceCount: 0,
          tuitionReminderCount: 0,
          parentContactPendingCount: 0,
          studentAttentionCount: 0,
          lastUpdatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          buildCard(
            snapshot,
            onNavigatePayload: (payload) {
              receivedPayload = payload;
            },
          ),
        );

        await tester.tap(find.text('TIẾP TỤC ĐIỂM DANH'));
        await tester.pump();

        expect(receivedPayload, isNotNull);
        expect(receivedPayload!.action, equals(HomeWidgetAction.attendance));
        expect(receivedPayload!.classId, equals(105));
        expect(receivedPayload!.scheduleId, equals(42));
      },
    );

    // TEST 2: sessionClose -> KHÔNG mở DiemDanhPage, dispatches sessionClose
    testWidgets(
      'TEST 2: sessionClose dispatches sessionClose payload and does NOT route to attendance',
      (tester) async {
        HomeWidgetActionPayload? receivedPayload;
        String? legacyRoute;

        final snapshot = HomeWidgetSnapshot(
          date: '2026-09-18',
          dateFormatted: 'Thứ Sáu (18/09/2026)',
          widgetState: 'SESSION_ENDED',
          todaySessionCount: 1,
          completedSessionCount: 0,
          currentClassId: 88,
          currentScheduleId: 19,
          currentSessionName: 'Lớp 11B',
          attentionCount: 0,
          criticalCount: 0,
          unexcusedAbsenceCount: 0,
          tuitionReminderCount: 0,
          parentContactPendingCount: 0,
          studentAttentionCount: 0,
          lastUpdatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          buildCard(
            snapshot,
            onNavigatePayload: (payload) {
              receivedPayload = payload;
            },
            onNavigate: (route) {
              legacyRoute = route;
            },
          ),
        );

        await tester.tap(find.text('KẾT THÚC CA'));
        await tester.pump();

        expect(receivedPayload, isNotNull);
        expect(receivedPayload!.action, equals(HomeWidgetAction.sessionClose));
        expect(
          receivedPayload!.action,
          isNot(equals(HomeWidgetAction.attendance)),
        );
        expect(legacyRoute, isNot(equals('diemdanh')));
      },
    );

    // TEST 3: dailyBrief -> KHÔNG map sang attention, dispatches dailyBrief
    testWidgets(
      'TEST 3: dailyBrief dispatches dailyBrief action and NOT attention',
      (tester) async {
        HomeWidgetActionPayload? receivedPayload;
        String? legacyRoute;

        final snapshot = HomeWidgetSnapshot(
          date: '2026-09-18',
          dateFormatted: 'Thứ Sáu (18/09/2026)',
          widgetState: 'MORNING',
          todaySessionCount: 3,
          completedSessionCount: 0,
          attentionCount: 0,
          criticalCount: 0,
          unexcusedAbsenceCount: 0,
          tuitionReminderCount: 0,
          parentContactPendingCount: 0,
          studentAttentionCount: 0,
          lastUpdatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          buildCard(
            snapshot,
            onNavigatePayload: (payload) {
              receivedPayload = payload;
            },
            onNavigate: (route) {
              legacyRoute = route;
            },
          ),
        );

        await tester.tap(find.text('XEM DAILY BRIEF'));
        await tester.pump();

        expect(receivedPayload, isNotNull);
        expect(receivedPayload!.action, equals(HomeWidgetAction.dailyBrief));
        expect(
          receivedPayload!.action,
          isNot(equals(HomeWidgetAction.attention)),
        );
        expect(legacyRoute, isNot(equals('attention')));
      },
    );

    // TEST 4: invalid snapshot.date -> CTA disabled & renders Dữ liệu ngày chưa hợp lệ
    testWidgets(
      'TEST 4: Invalid snapshot.date disables deep-link CTA and shows invalid date warning',
      (tester) async {
        HomeWidgetActionPayload? receivedPayload;

        final snapshot = HomeWidgetSnapshot(
          date: '', // invalid / missing date
          dateFormatted: '',
          widgetState: 'CURRENT_SESSION',
          todaySessionCount: 1,
          completedSessionCount: 0,
          currentClassId: 10,
          currentSessionName: 'Lớp 12A',
          currentStart: '17:30',
          currentEnd: '19:00',
          attentionCount: 0,
          criticalCount: 0,
          unexcusedAbsenceCount: 0,
          tuitionReminderCount: 0,
          parentContactPendingCount: 0,
          studentAttentionCount: 0,
          lastUpdatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          buildCard(
            snapshot,
            onNavigatePayload: (payload) {
              receivedPayload = payload;
            },
          ),
        );

        expect(find.text('Dữ liệu ngày chưa hợp lệ'), findsOneWidget);

        final buttonFinder = find.byType(FilledButton);
        final FilledButton button = tester.widget(buttonFinder);
        expect(button.onPressed, isNull); // CTA disabled

        await tester.tap(buttonFinder);
        await tester.pump();
        expect(receivedPayload, isNull);
      },
    );

    // TEST 5: start without end -> renders Bắt đầu 17:30
    testWidgets(
      'TEST 5: Start time without end time renders Bắt đầu 17:30 without trailing dash',
      (tester) async {
        final snapshot = HomeWidgetSnapshot(
          date: '2026-09-18',
          dateFormatted: 'Thứ Sáu (18/09/2026)',
          widgetState: 'CURRENT_SESSION',
          todaySessionCount: 1,
          completedSessionCount: 0,
          currentClassId: 10,
          currentSessionName: 'Lớp 12A',
          currentStart: '17:30',
          currentEnd: null, // missing end time
          attentionCount: 0,
          criticalCount: 0,
          unexcusedAbsenceCount: 0,
          tuitionReminderCount: 0,
          parentContactPendingCount: 0,
          studentAttentionCount: 0,
          lastUpdatedAt: DateTime.now(),
        );

        await tester.pumpWidget(buildCard(snapshot));
        expect(find.textContaining('17:30–'), findsNothing);
        expect(find.textContaining('Bắt đầu 17:30'), findsOneWidget);
      },
    );

    // TEST 6: ended session reviewDone=true -> renders ✓ Đánh giá
    testWidgets(
      'TEST 6: Session ended with reviewDone=true renders ✓ Đánh giá',
      (tester) async {
        final snapshot = HomeWidgetSnapshot(
          date: '2026-09-18',
          dateFormatted: 'Thứ Sáu (18/09/2026)',
          widgetState: 'SESSION_ENDED',
          todaySessionCount: 1,
          completedSessionCount: 1,
          currentClassId: 10,
          currentSessionName: 'Lớp 12A',
          attendanceDone: true,
          reviewDone: true,
          homeworkDone: false,
          parentActionPending: 0,
          attentionCount: 0,
          criticalCount: 0,
          unexcusedAbsenceCount: 0,
          tuitionReminderCount: 0,
          parentContactPendingCount: 0,
          studentAttentionCount: 0,
          lastUpdatedAt: DateTime.now(),
        );

        await tester.pumpWidget(buildCard(snapshot));
        expect(find.textContaining('✓ Đánh giá'), findsOneWidget);
        expect(find.textContaining('○ Chưa đánh giá'), findsNothing);
      },
    );

    // TEST 7: homeworkDone=true -> renders ✓ Giao BTVN
    testWidgets(
      'TEST 7: Session ended with homeworkDone=true renders ✓ Giao BTVN',
      (tester) async {
        final snapshot = HomeWidgetSnapshot(
          date: '2026-09-18',
          dateFormatted: 'Thứ Sáu (18/09/2026)',
          widgetState: 'SESSION_ENDED',
          todaySessionCount: 1,
          completedSessionCount: 1,
          currentClassId: 10,
          currentSessionName: 'Lớp 12A',
          attendanceDone: true,
          reviewDone: true,
          homeworkDone: true,
          parentActionPending: 0,
          attentionCount: 0,
          criticalCount: 0,
          unexcusedAbsenceCount: 0,
          tuitionReminderCount: 0,
          parentContactPendingCount: 0,
          studentAttentionCount: 0,
          lastUpdatedAt: DateTime.now(),
        );

        await tester.pumpWidget(buildCard(snapshot));
        expect(find.textContaining('✓ Giao BTVN'), findsOneWidget);
        expect(find.textContaining('○ Chưa giao BTVN'), findsNothing);
      },
    );

    // TEST 8: Sentence case text formatting
    testWidgets('TEST 8: Titles use clean sentence case formatting', (
      tester,
    ) async {
      final snapshot = HomeWidgetSnapshot(
        date: '2026-09-18',
        dateFormatted: 'Thứ Sáu (18/09/2026)',
        widgetState: 'CURRENT_SESSION',
        todaySessionCount: 1,
        completedSessionCount: 0,
        currentClassId: 10,
        currentSessionName: 'Lớp 12A',
        currentStart: '17:30',
        currentEnd: '19:00',
        attentionCount: 0,
        criticalCount: 0,
        unexcusedAbsenceCount: 0,
        tuitionReminderCount: 0,
        parentContactPendingCount: 0,
        studentAttentionCount: 0,
        lastUpdatedAt: DateTime.now(),
      );

      await tester.pumpWidget(buildCard(snapshot));
      expect(find.text('Đang dạy'), findsOneWidget);
      expect(find.text('● ĐANG DẠY'), findsNothing);
    });
  });
}
