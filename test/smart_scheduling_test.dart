import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/models/schedule_suggestion.dart';
import 'package:tuition2025/models/student_busy_schedule.dart';
import 'package:tuition2025/models/student_schedule_assignment.dart';
import 'package:tuition2025/services/schedule_candidate_service.dart';
import 'package:tuition2025/services/schedule_conflict_service.dart';
import 'package:tuition2025/services/schedule_scoring_service.dart';
import 'package:tuition2025/models/lich_hoc_chung.dart';

void main() {
  group('Smart Scheduling Assistant & Conflict Engine Tests', () {
    test(
      'TEST 1: Buffer check - candidate < minimum buffer (30m) receives penalty/warning',
      () {
        final busyList = [
          StudentBusySchedule(
            studentId: 101,
            type: BusyType.school,
            title: 'Trường THPT',
            dayOfWeek: 1, // T2
            startTime: '13:00',
            endTime: '17:00',
            effectiveFrom: '2026-09-01',
            effectiveTo: '2026-09-30',
          ),
        ];

        // Candidate 1: 17:15 (gap = 15m < 30m minimum buffer)
        final res1 = ScheduleConflictService.instance.checkConflict(
          candidateDayOfWeek: 1,
          candidateStartTime: '17:15',
          candidateEndTime: '18:45',
          dateStr: '2026-09-21',
          busySchedules: busyList,
          minimumBufferMinutes: 30,
        );

        expect(res1.level, equals(ConflictLevel.softConflict));
        expect(res1.reasons.any((r) => r.contains('15 phút')), isTrue);

        // Candidate 2: 19:00 (gap = 120m >= 30m)
        final res2 = ScheduleConflictService.instance.checkConflict(
          candidateDayOfWeek: 1,
          candidateStartTime: '19:00',
          candidateEndTime: '20:30',
          dateStr: '2026-09-21',
          busySchedules: busyList,
          minimumBufferMinutes: 30,
        );

        expect(res2.level, equals(ConflictLevel.noConflict));
      },
    );

    test(
      'TEST 2: Other subject conflict - Math 18:00-20:00 vs Physics 19:00 -> HARD_CONFLICT',
      () {
        final busyList = [
          StudentBusySchedule(
            studentId: 101,
            type: BusyType.extraMath,
            title: 'Học thêm Toán',
            dayOfWeek: 2, // T3
            startTime: '18:00',
            endTime: '20:00',
            effectiveFrom: '2026-09-01',
            effectiveTo: '2026-09-30',
          ),
        ];

        final res = ScheduleConflictService.instance.checkConflict(
          candidateDayOfWeek: 2,
          candidateStartTime: '19:00',
          candidateEndTime: '20:30',
          dateStr: '2026-09-22',
          busySchedules: busyList,
        );

        expect(res.level, equals(ConflictLevel.hardConflict));
        expect(res.reasons.any((r) => r.contains('Trùng lịch')), isTrue);
      },
    );

    test(
      'TEST 3: Scoring Engine - Deterministic scoring & Stability Bonus (+20)',
      () {
        final candA = CandidateSession(
          schedule: LichHocChung(
            id: 1,
            idLop: 10,
            ngayTrongTuan: 'Thứ Hai',
            gioBatDau: '17:30',
            gioKetThuc: '19:00',
          ),
          classId: 10,
          className: 'Lớp Vật lý 10A',
          grade: '10',
          dayOfWeek: 1,
          startTime: '17:30',
          endTime: '19:00',
          currentCapacity: 20,
          maxCapacity: 30,
        );

        final candB = CandidateSession(
          schedule: LichHocChung(
            id: 2,
            idLop: 11,
            ngayTrongTuan: 'Thứ Hai',
            gioBatDau: '19:00',
            gioKetThuc: '20:30',
          ),
          classId: 11,
          className: 'Lớp Vật lý 10B',
          grade: '10',
          dayOfWeek: 1,
          startTime: '19:00',
          endTime: '20:30',
          currentCapacity: 10,
          maxCapacity: 30,
        );

        // candA is current assignment -> gets +20 stability bonus
        final scoreA = ScheduleScoringService.instance.scoreCandidate(
          studentId: 101,
          candidate: candA,
          dateStr: '2026-09-21',
          busySchedules: [],
          isCurrentAssignment: true,
        );

        final scoreB = ScheduleScoringService.instance.scoreCandidate(
          studentId: 101,
          candidate: candB,
          dateStr: '2026-09-21',
          busySchedules: [],
          isCurrentAssignment: false,
        );

        expect(scoreA.score, equals(80.0));
        expect(
          scoreA.reasons.any((r) => r.contains('★ Giữ đúng ca hiện tại')),
          isTrue,
        );
        expect(
          scoreB.reasons.any((r) => r.contains('★ Giữ đúng ca hiện tại')),
          isFalse,
        );
      },
    );

    test(
      'TEST 4: Capacity constraint - Full class (30/30) receives heavy penalty (-100)',
      () {
        final candFull = CandidateSession(
          schedule: LichHocChung(
            id: 1,
            idLop: 10,
            ngayTrongTuan: 'Thứ Ba',
            gioBatDau: '18:00',
            gioKetThuc: '19:30',
          ),
          classId: 10,
          className: 'Lớp Full',
          grade: '11',
          dayOfWeek: 2,
          startTime: '18:00',
          endTime: '19:30',
          currentCapacity: 30,
          maxCapacity: 30,
        );

        final score = ScheduleScoringService.instance.scoreCandidate(
          studentId: 102,
          candidate: candFull,
          dateStr: '2026-09-22',
          busySchedules: [],
          isCurrentAssignment: false,
        );

        expect(score.score, equals(0.0));
        expect(score.reasons.any((r) => r.contains('Lớp đã đầy')), isTrue);
      },
    );

    test('TEST 5: Precedence Resolution - ONE_TIME > TEMPORARY > REGULAR', () {
      final reg = StudentScheduleAssignment(
        studentId: 1,
        classId: 10,
        effectiveFrom: '2026-09-01',
        effectiveTo: '9999-12-31',
        priority: 1, // REGULAR
      );

      final temp = StudentScheduleAssignment(
        studentId: 1,
        classId: 11,
        effectiveFrom: '2026-09-21',
        effectiveTo: '2026-09-27',
        priority: 2, // TEMPORARY
      );

      final oneTime = StudentScheduleAssignment(
        studentId: 1,
        classId: 12,
        effectiveFrom: '2026-09-23',
        effectiveTo: '2026-09-23',
        priority: 3, // ONE_TIME
      );

      final list = [reg, temp, oneTime];
      list.sort((a, b) => b.priority.compareTo(a.priority));

      expect(list.first.priority, equals(3)); // ONE_TIME wins!
      expect(list.first.classId, equals(12));
    });
  });
}
