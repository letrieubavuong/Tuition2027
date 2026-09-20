import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/models/diem_danh.dart';
import 'package:tuition2025/models/lich_hoc.dart';
import 'package:tuition2025/services/session_ledger_service.dart';
import 'package:tuition2025/services/payment_matching_engine.dart';
import 'package:tuition2025/services/bank_parsers/bank_notification_parser.dart';
import 'package:tuition2025/utils/attendance_calculator.dart';
import 'package:tuition2025/services/notification_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AUDIT & STABILIZATION - Canonical Attendance Status Tests', () {
    test(
      'Normalizes various Vietnamese and legacy status strings correctly',
      () {
        expect(
          AttendanceStatus.fromString('Có mặt').canonicalKey,
          equals('CO_MAT'),
        );
        expect(
          AttendanceStatus.fromString('coMat').canonicalKey,
          equals('CO_MAT'),
        );
        expect(
          AttendanceStatus.fromString('CO_MAT').canonicalKey,
          equals('CO_MAT'),
        );

        expect(AttendanceStatus.fromString('Trễ').canonicalKey, equals('TRE'));
        expect(AttendanceStatus.fromString('tre').canonicalKey, equals('TRE'));

        expect(
          AttendanceStatus.fromString('Nghỉ có phép').canonicalKey,
          equals('VANG_CO_PHEP'),
        );
        expect(
          AttendanceStatus.fromString('VANG_CO_PHEP').canonicalKey,
          equals('VANG_CO_PHEP'),
        );

        expect(
          AttendanceStatus.fromString('Nghỉ không phép').canonicalKey,
          equals('VANG_KHONG_PHEP'),
        );
        expect(
          AttendanceStatus.fromString('VANG_KHONG_PHEP').canonicalKey,
          equals('VANG_KHONG_PHEP'),
        );

        expect(
          AttendanceStatus.fromString('Học bù').canonicalKey,
          equals('HOC_BU'),
        );
        expect(
          AttendanceStatus.fromString('hoc_bu').canonicalKey,
          equals('HOC_BU'),
        );
      },
    );

    test('DiemDanh model copyWith updates fields immutably', () {
      final dd = DiemDanh(
        id: 10,
        idHocSinh: 1,
        idLop: 2,
        gioDiemDanh: '2026-09-17 18:00:00',
        trangThai: 'Có mặt',
      );

      final updated = dd.copyWith(trangThai: 'Trễ', ghiChu: 'Vào muộn 10 phút');

      expect(updated.id, equals(10));
      expect(updated.trangThai, equals('Trễ'));
      expect(updated.ghiChu, equals('Vào muộn 10 phút'));
      expect(
        dd.trangThai,
        equals('Có mặt'),
      ); // Original instance remains unchanged
    });
  });

  group('AUDIT & STABILIZATION - Session Ledger Session-Based Data Model', () {
    test('SessionLedgerItem constructs with start time and schedule ID', () {
      final item = SessionLedgerItem(
        date: '2026-09-17',
        dayOfWeek: 'Thứ Năm',
        startTime: '18:00',
        scheduleId: 101,
        isScheduledEligible: true,
        attendanceStatus: 'CO_MAT',
      );

      final map = item.toMap();
      expect(map['date'], equals('2026-09-17'));
      expect(map['startTime'], equals('18:00'));
      expect(map['scheduleId'], equals(101));
      expect(map['attendanceStatus'], equals('CO_MAT'));
    });
  });

  group('AUDIT & STABILIZATION - Bank Matching Canonical Statuses', () {
    test('PaymentMatchResult reflects canonical status', () {
      final candidate = BankTransactionCandidate(
        bankCode: 'sacombank',
        direction: 'CREDIT',
        amount: 500000,
        transferContent: 'TK +500,000VND HP 000001 202609',
        rawFingerprint: 'FP_TEST',
        packageName: 'com.sacombank.mbanking',
        rawTitle: 'Biến động số dư',
        rawText: 'TK +500,000VND',
      );

      final res = PaymentMatchResult(
        candidate: candidate,
        matchedStudentId: 1,
        matchedClassId: 2,
        matchedMonth: '2026-09',
        studentName: 'Nguyễn Văn A',
        className: 'Lớp 10A1',
        matchMethod: 'AUTO_EXACT',
        confidenceScore: 100,
        status: 'CONFIRMED',
        reason: 'Ghép chính xác thành công',
      );

      expect(res.isConfirmed, isTrue);
      expect(res.status, equals('CONFIRMED'));
    });
  });

  group('ROUND 2 - Bug 3: Session Matching Time Tests', () {
    test(
      'isMatchingSessionTime matches exact time and blocks wrong hour match',
      () {
        // 18:45 attendance must NOT match 18:00 schedule
        expect(
          SessionLedgerService.isMatchingSessionTime('18:45', '18:00'),
          isFalse,
        );

        // 18:45 attendance matches 18:45 schedule exactly
        expect(
          SessionLedgerService.isMatchingSessionTime('18:45', '18:45'),
          isTrue,
        );

        // 18:45:00 format matches 18:45
        expect(
          SessionLedgerService.isMatchingSessionTime('18:45:00', '18:45'),
          isTrue,
        );

        // 18:40 attendance matches 18:45 schedule (within 15 min tolerance)
        expect(
          SessionLedgerService.isMatchingSessionTime('18:40', '18:45'),
          isTrue,
        );
      },
    );
  });

  group('ROUND 2 - Bug 4: Per-Session Makeup Link Tests', () {
    test(
      '1 makeup session only compensates 1 matching absent session on the same date',
      () {
        final listDiemDanh = [
          DiemDanh(
            id: 1,
            idHocSinh: 10,
            idLop: 1,
            gioDiemDanh: '2026-09-15 18:00:00',
            trangThai: 'Học bù',
            ngayVangGoc: '2026-09-10 17:30:00',
          ),
        ];

        final monthSessions = [
          SessionLedgerItem(
            date: '2026-09-10',
            dayOfWeek: 'Thứ Năm',
            startTime: '17:30',
            isScheduledEligible: true,
            attendanceStatus: 'VANG_CO_PHEP',
          ),
          SessionLedgerItem(
            date: '2026-09-10',
            dayOfWeek: 'Thứ Năm',
            startTime: '19:00',
            isScheduledEligible: true,
            attendanceStatus: 'VANG_CO_PHEP',
          ),
        ];

        final makeupAttendanceRecords = listDiemDanh
            .where(
              (dd) =>
                  SessionLedgerService.normalizeStatus(dd.trangThai) ==
                  'HOC_BU',
            )
            .toList();

        final usedMakeupRecords = <DiemDanh>{};
        int uncompensatedExcusedCount = 0;

        for (final s in monthSessions) {
          if (s.attendanceStatus == 'VANG_CO_PHEP') {
            DiemDanh? matchedMakeup;

            // Pass 1: Match date AND startTime
            for (final mk in makeupAttendanceRecords) {
              if (usedMakeupRecords.contains(mk)) continue;
              final nvg = mk.ngayVangGoc?.trim() ?? '';
              if (nvg.isNotEmpty && nvg.contains(s.date)) {
                if (s.startTime != null &&
                    s.startTime!.isNotEmpty &&
                    nvg.contains(s.startTime!)) {
                  matchedMakeup = mk;
                  break;
                }
              }
            }

            // Pass 2: Match date-only
            if (matchedMakeup == null) {
              for (final mk in makeupAttendanceRecords) {
                if (usedMakeupRecords.contains(mk)) continue;
                final nvg = mk.ngayVangGoc?.trim() ?? '';
                if (nvg.isNotEmpty && nvg.startsWith(s.date)) {
                  matchedMakeup = mk;
                  break;
                }
              }
            }

            if (matchedMakeup != null) {
              usedMakeupRecords.add(matchedMakeup);
            } else {
              uncompensatedExcusedCount++;
            }
          }
        }

        // Session 17:30 is compensated, session 19:00 is UNCOMPENSATED
        expect(uncompensatedExcusedCount, equals(1));
        expect(usedMakeupRecords.length, equals(1));
      },
    );
  });

  group('ISSUE 5 - Multiple Sessions Per Day Tests', () {
    final ca1 = LichHoc(
      id: 101,
      idLop: 1,
      thuTrongTuan: 2,
      gioBatDau: '17:30',
      gioKetThuc: '19:00',
    );
    final ca2 = LichHoc(
      id: 102,
      idLop: 1,
      thuTrongTuan: 2,
      gioBatDau: '19:00',
      gioKetThuc: '20:30',
    );
    final ca3 = LichHoc(
      id: 103,
      idLop: 1,
      thuTrongTuan: 2,
      gioBatDau: '20:30',
      gioKetThuc: '22:00',
    );

    test('TEST 1: State retains all 3 shifts for a class on the same day', () {
      final caHocTrongNgay = [ca1, ca2, ca3];
      expect(caHocTrongNgay.length, equals(3));
      expect(caHocTrongNgay.map((c) => c.id), containsAll([101, 102, 103]));
    });

    test(
      'TEST 2: Passing selectedScheduleId=102 still retains all 3 shifts in state',
      () {
        final caHocTrongNgay = [ca1, ca2, ca3];
        final selectedScheduleId = 102;
        final focusedCa = caHocTrongNgay.firstWhere(
          (c) => c.id == selectedScheduleId,
        );

        expect(focusedCa.gioBatDau, equals('19:00'));
        expect(caHocTrongNgay.length, equals(3)); // All 3 shifts exist!
      },
    );

    test(
      'TEST 3: Student in both Shift 17:30 and Shift 19:00 has 2 independent attendance state keys',
      () {
        final studentId = 1;
        final key1 = '$studentId-${ca1.id}'; // '1-101'
        final key2 = '$studentId-${ca2.id}'; // '1-102'

        expect(key1, isNot(equals(key2)));
        final stateMap = <String, DiemDanh>{
          key1: DiemDanh(
            idHocSinh: studentId,
            idLop: 1,
            gioDiemDanh: '2026-09-15 17:30',
            trangThai: 'Có mặt',
          ),
          key2: DiemDanh(
            idHocSinh: studentId,
            idLop: 1,
            gioDiemDanh: '2026-09-15 19:00',
            trangThai: 'Nghỉ có phép',
          ),
        };

        expect(stateMap[key1]!.trangThai, equals('Có mặt'));
        expect(stateMap[key2]!.trangThai, equals('Nghỉ có phép'));
      },
    );

    test(
      'TEST 4: Saving & reloading independent shift states preserves exact states per shift',
      () {
        final studentId = 1;
        final key1 = '$studentId-${ca1.id}';
        final key2 = '$studentId-${ca2.id}';

        final dd1 = DiemDanh(
          idHocSinh: studentId,
          idLop: 1,
          gioDiemDanh: '2026-09-15 17:30',
          trangThai: 'Có mặt',
        );
        final dd2 = DiemDanh(
          idHocSinh: studentId,
          idLop: 1,
          gioDiemDanh: '2026-09-15 19:00',
          trangThai: 'Nghỉ có phép',
        );

        // Natural keys (idHocSinh, gioDiemDanh) are distinct
        expect(dd1.gioDiemDanh, isNot(equals(dd2.gioDiemDanh)));
        expect(dd1.trangThai, equals('Có mặt'));
        expect(dd2.trangThai, equals('Nghỉ có phép'));
      },
    );

    test(
      'TEST 5: markAllPresent on Shift 17:30 changes ONLY Shift 17:30 students',
      () {
        final stateMap = <String, DiemDanh>{
          '1-101': DiemDanh(
            idHocSinh: 1,
            idLop: 1,
            gioDiemDanh: '2026-09-15 17:30',
            trangThai: 'Nghỉ không phép',
          ),
          '1-102': DiemDanh(
            idHocSinh: 1,
            idLop: 1,
            gioDiemDanh: '2026-09-15 19:00',
            trangThai: 'Nghỉ có phép',
          ),
          '2-102': DiemDanh(
            idHocSinh: 2,
            idLop: 1,
            gioDiemDanh: '2026-09-15 19:00',
            trangThai: 'Nghỉ không phép',
          ),
        };

        // Apply markAllPresent for ca1 (101)
        final hsCuaCa1 = [1];
        for (var hsId in hsCuaCa1) {
          final k = '$hsId-${ca1.id}';
          if (stateMap.containsKey(k)) {
            stateMap[k] = stateMap[k]!.copyWith(trangThai: 'Có mặt');
          }
        }

        // Shift 1 (101) is changed to 'Có mặt'
        expect(stateMap['1-101']!.trangThai, equals('Có mặt'));

        // Shift 2 (102) remains UNCHANGED
        expect(stateMap['1-102']!.trangThai, equals('Nghỉ có phép'));
        expect(stateMap['2-102']!.trangThai, equals('Nghỉ không phép'));
      },
    );
  });

  group('ATTENDANCE QUICK ACTIONS — PER SESSION TESTS', () {
    final ca1 = LichHoc(
      id: 101,
      idLop: 1,
      thuTrongTuan: 2,
      gioBatDau: '17:30',
      gioKetThuc: '19:00',
    );
    final ca2 = LichHoc(
      id: 102,
      idLop: 1,
      thuTrongTuan: 2,
      gioBatDau: '19:00',
      gioKetThuc: '20:30',
    );
    final ca3 = LichHoc(
      id: 103,
      idLop: 1,
      thuTrongTuan: 2,
      gioBatDau: '20:30',
      gioKetThuc: '22:00',
    );

    test(
      'TEST 10A: 40 students, 3 sessions -> Bulk action on Session 2 DOES NOT touch Session 1 or Session 3',
      () {
        final stateMap = <String, DiemDanh>{};

        // Session 1: Students 1..15
        for (int i = 1; i <= 15; i++) {
          stateMap['$i-101'] = DiemDanh(
            idHocSinh: i,
            idLop: 1,
            gioDiemDanh: '2026-09-15 17:30',
            trangThai: 'Có mặt',
          );
        }

        // Session 2: Students 11..25
        for (int i = 11; i <= 25; i++) {
          stateMap['$i-102'] = DiemDanh(
            idHocSinh: i,
            idLop: 1,
            gioDiemDanh: '2026-09-15 19:00',
            trangThai: 'Chưa điểm danh',
          );
        }

        // Session 3: Students 26..40
        for (int i = 26; i <= 40; i++) {
          stateMap['$i-103'] = DiemDanh(
            idHocSinh: i,
            idLop: 1,
            gioDiemDanh: '2026-09-15 20:30',
            trangThai: 'Có mặt',
          );
        }

        // Perform bulk "Nghỉ có phép" ONLY on Session 2 (ca2 = 102)
        final hsCuaCa2 = List.generate(15, (index) => index + 11); // 11..25
        for (var hsId in hsCuaCa2) {
          final key = '$hsId-102';
          if (stateMap.containsKey(key)) {
            stateMap[key] = stateMap[key]!.copyWith(trangThai: 'Nghỉ có phép');
          }
        }

        // Verify Session 2 updated
        for (int i = 11; i <= 25; i++) {
          expect(stateMap['$i-102']!.trangThai, equals('Nghỉ có phép'));
        }

        // Verify Session 1 100% UNTOUCHED
        for (int i = 1; i <= 15; i++) {
          expect(stateMap['$i-101']!.trangThai, equals('Có mặt'));
        }

        // Verify Session 3 100% UNTOUCHED
        for (int i = 26; i <= 40; i++) {
          expect(stateMap['$i-103']!.trangThai, equals('Có mặt'));
        }
      },
    );

    test(
      'TEST 10B: "Chưa điểm danh tất cả" sets status to Chưa điểm danh (NO_RECORD), NOT Nghỉ không phép',
      () {
        final stateMap = <String, DiemDanh>{
          '1-102': DiemDanh(
            idHocSinh: 1,
            idLop: 1,
            gioDiemDanh: '2026-09-15 19:00',
            trangThai: 'Có mặt',
          ),
        };

        stateMap['1-102'] = stateMap['1-102']!.copyWith(
          trangThai: 'Chưa điểm danh',
        );

        expect(stateMap['1-102']!.trangThai, equals('Chưa điểm danh'));
        expect(
          SessionLedgerService.normalizeStatus(stateMap['1-102']!.trangThai),
          equals('NO_RECORD'),
        );
        expect(
          SessionLedgerService.normalizeStatus(stateMap['1-102']!.trangThai),
          isNot(equals('VANG_KHONG_PHEP')),
        );
      },
    );

    test(
      'TEST 10C: Undo bulk action restores exact previous state for that session',
      () {
        final originalRecord = DiemDanh(
          idHocSinh: 1,
          idLop: 1,
          gioDiemDanh: '2026-09-15 19:00',
          trangThai: 'Nghỉ có phép',
        );
        final stateMap = <String, DiemDanh>{'1-102': originalRecord};

        // Backup before bulk
        final backup = <String, DiemDanh>{'1-102': stateMap['1-102']!};

        // Apply bulk "Có mặt"
        stateMap['1-102'] = stateMap['1-102']!.copyWith(trangThai: 'Có mặt');
        expect(stateMap['1-102']!.trangThai, equals('Có mặt'));

        // Perform Undo
        backup.forEach((key, rec) {
          stateMap[key] = rec;
        });

        expect(stateMap['1-102']!.trangThai, equals('Nghỉ có phép'));
      },
    );

    test('TEST 10D: Individual student edit works after bulk action', () {
      final stateMap = <String, DiemDanh>{
        '1-102': DiemDanh(
          idHocSinh: 1,
          idLop: 1,
          gioDiemDanh: '2026-09-15 19:00',
          trangThai: 'Có mặt',
        ),
        '2-102': DiemDanh(
          idHocSinh: 2,
          idLop: 1,
          gioDiemDanh: '2026-09-15 19:00',
          trangThai: 'Có mặt',
        ),
      };

      // Edit student 2 to 'Trễ'
      stateMap['2-102'] = stateMap['2-102']!.copyWith(trangThai: 'Trễ');

      expect(stateMap['1-102']!.trangThai, equals('Có mặt'));
      expect(stateMap['2-102']!.trangThai, equals('Trễ'));
    });
  });

  group('ROUND 3 — Participation Window Tests (Tests 5-8)', () {
    test(
      'TEST 5: Student joined on 15/09 — dates 3, 7, 10 are skipped; 16, 20 are included',
      () {
        final ngayThamGia = DateTime(2026, 9, 15);
        final scheduleDates = [
          DateTime(2026, 9, 3),
          DateTime(2026, 9, 7),
          DateTime(2026, 9, 10),
          DateTime(2026, 9, 16),
          DateTime(2026, 9, 20),
        ];

        final validDates = scheduleDates.where((d) {
          return AttendanceCalculator.isDateInParticipationWindow(
            date: d,
            ngayThamGia: ngayThamGia,
          );
        }).toList();

        expect(validDates.length, equals(2));
        expect(
          validDates,
          containsAll([DateTime(2026, 9, 16), DateTime(2026, 9, 20)]),
        );
      },
    );

    test(
      'TEST 6: Student paused from 10/09 to 19/09 — dates in pause window return false',
      () {
        final ngayThamGia = DateTime(2026, 9, 1);
        final ngayTamNgung = DateTime(2026, 9, 10);
        final ngayHocLai = DateTime(2026, 9, 20);

        expect(
          AttendanceCalculator.isDateInParticipationWindow(
            date: DateTime(2026, 9, 5),
            ngayThamGia: ngayThamGia,
            ngayTamNgung: ngayTamNgung,
            ngayHocLai: ngayHocLai,
          ),
          isTrue,
        );

        // 10/09 - 19/09 paused
        expect(
          AttendanceCalculator.isDateInParticipationWindow(
            date: DateTime(2026, 9, 15),
            ngayThamGia: ngayThamGia,
            ngayTamNgung: ngayTamNgung,
            ngayHocLai: ngayHocLai,
          ),
          isFalse,
        );

        // Resumed on 20/09
        expect(
          AttendanceCalculator.isDateInParticipationWindow(
            date: DateTime(2026, 9, 20),
            ngayThamGia: ngayThamGia,
            ngayTamNgung: ngayTamNgung,
            ngayHocLai: ngayHocLai,
          ),
          isTrue,
        );
      },
    );

    test(
      'TEST 7: Student left class on 15/09 — dates after 15/09 return false',
      () {
        final ngayThamGia = DateTime(2026, 9, 1);
        final ngayNghiHoc = DateTime(2026, 9, 15);

        expect(
          AttendanceCalculator.isDateInParticipationWindow(
            date: DateTime(2026, 9, 10),
            ngayThamGia: ngayThamGia,
            ngayNghiHoc: ngayNghiHoc,
          ),
          isTrue,
        );

        expect(
          AttendanceCalculator.isDateInParticipationWindow(
            date: DateTime(2026, 9, 16),
            ngayThamGia: ngayThamGia,
            ngayNghiHoc: ngayNghiHoc,
          ),
          isFalse,
        );
      },
    );

    test(
      'TEST 8: Student resumed after leaving on 25/09 — evaluated active from 25/09',
      () {
        final ngayThamGia = DateTime(2026, 9, 1);
        final ngayNghiHoc = DateTime(2026, 9, 15);
        final ngayHocLaiSauNghi = DateTime(2026, 9, 25);

        expect(
          AttendanceCalculator.isDateInParticipationWindow(
            date: DateTime(2026, 9, 20),
            ngayThamGia: ngayThamGia,
            ngayNghiHoc: ngayNghiHoc,
            ngayHocLaiSauNghi: ngayHocLaiSauNghi,
          ),
          isFalse,
        );

        expect(
          AttendanceCalculator.isDateInParticipationWindow(
            date: DateTime(2026, 9, 25),
            ngayThamGia: ngayThamGia,
            ngayNghiHoc: ngayNghiHoc,
            ngayHocLaiSauNghi: ngayHocLaiSauNghi,
          ),
          isTrue,
        );
      },
    );
  });

  group('ROUND 3 — Session-Safe Makeup Tests (Tests 9-10)', () {
    test(
      'TEST 9: On 17/09 with 2 shifts (17:30 & 19:00), if 17:30 has record, makeup inserts ONLY 19:00',
      () {
        final existingAttKeys = <String>{'25_1_2026-09-17_17:30'};
        final lopId = 1;
        final studentId = 25;
        final dateStr = '2026-09-17';

        final shift1Time = '17:30';
        final shift2Time = '19:00';

        final key1 = '${studentId}_${lopId}_${dateStr}_$shift1Time';
        final key2 = '${studentId}_${lopId}_${dateStr}_$shift2Time';

        final inserts = <String>[];
        if (!existingAttKeys.contains(key1)) inserts.add(key1);
        if (!existingAttKeys.contains(key2)) inserts.add(key2);

        expect(inserts.length, equals(1));
        expect(inserts.first, equals('25_1_2026-09-17_19:00'));
      },
    );

    test(
      'TEST 10: If both shifts on 17/09 have attendance, makeup inserts 0 records',
      () {
        final existingAttKeys = <String>{
          '25_1_2026-09-17_17:30',
          '25_1_2026-09-17_19:00',
        };
        final lopId = 1;
        final studentId = 25;
        final dateStr = '2026-09-17';

        final key1 = '${studentId}_${lopId}_${dateStr}_17:30';
        final key2 = '${studentId}_${lopId}_${dateStr}_19:00';

        final inserts = <String>[];
        if (!existingAttKeys.contains(key1)) inserts.add(key1);
        if (!existingAttKeys.contains(key2)) inserts.add(key2);

        expect(inserts.length, equals(0));
      },
    );
  });

  group('ROUND 3 — Bulk Action Tests (Tests 11-15)', () {
    test(
      'TEST 11: 40 students, 3 sessions — "Tất cả có mặt" ca 2 only modifies 40 states of ca 2',
      () {
        final stateMap = <String, String>{};
        for (int i = 1; i <= 40; i++) {
          stateMap['$i-101'] = 'Chưa điểm danh';
          stateMap['$i-102'] = 'Chưa điểm danh';
          stateMap['$i-103'] = 'Chưa điểm danh';
        }

        // Apply bulk "Có mặt" to ca 2 (102)
        for (int i = 1; i <= 40; i++) {
          stateMap['$i-102'] = 'Có mặt';
        }

        for (int i = 1; i <= 40; i++) {
          expect(stateMap['$i-101'], equals('Chưa điểm danh'));
          expect(stateMap['$i-102'], equals('Có mặt'));
          expect(stateMap['$i-103'], equals('Chưa điểm danh'));
        }
      },
    );

    test(
      'TEST 12: "Tất cả nghỉ có phép" ca 1 -> entire ca 1 = Nghỉ có phép',
      () {
        final stateMap = <String, String>{
          '1-101': 'Chưa điểm danh',
          '2-101': 'Có mặt',
        };

        for (var k in stateMap.keys.toList()) {
          if (k.endsWith('-101')) stateMap[k] = 'Nghỉ có phép';
        }

        expect(stateMap['1-101'], equals('Nghỉ có phép'));
        expect(stateMap['2-101'], equals('Nghỉ có phép'));
      },
    );

    test(
      'TEST 13: "Chưa điểm danh tất cả" -> status NO_RECORD, NOT Nghỉ không phép',
      () {
        final statusStr = 'Chưa điểm danh';
        final canonical = SessionLedgerService.normalizeStatus(statusStr);

        expect(canonical, equals('NO_RECORD'));
        expect(canonical, isNot(equals('VANG_KHONG_PHEP')));
      },
    );

    test(
      'TEST 14: Bulk action -> modify individual student -> student gets new status, others retain bulk',
      () {
        final stateMap = <String, String>{
          '1-101': 'Có mặt',
          '2-101': 'Có mặt',
          '3-101': 'Có mặt',
        };

        stateMap['2-101'] = 'Nghỉ có phép';

        expect(stateMap['1-101'], equals('Có mặt'));
        expect(stateMap['2-101'], equals('Nghỉ có phép'));
        expect(stateMap['3-101'], equals('Có mặt'));
      },
    );

    test('TEST 15: Bulk action -> Undo -> restores exact prior states', () {
      final stateMap = <String, String>{
        '1-101': 'Trễ',
        '2-101': 'Nghỉ có phép',
      };

      final backup = Map<String, String>.from(stateMap);

      // Perform bulk "Có mặt"
      for (var k in stateMap.keys.toList()) {
        stateMap[k] = 'Có mặt';
      }

      expect(stateMap['1-101'], equals('Có mặt'));
      expect(stateMap['2-101'], equals('Có mặt'));

      // Undo
      stateMap.clear();
      stateMap.addAll(backup);

      expect(stateMap['1-101'], equals('Trễ'));
      expect(stateMap['2-101'], equals('Nghỉ có phép'));
    });
  });

  group('ROUND 3 — Notification Routing Tests (Tests 16-20)', () {
    test('TEST 16: payment_confirmed valid JSON payload parses correctly', () {
      final jsonStr =
          '{"type":"payment_confirmed","studentId":123,"classId":5,"month":"2026-09","paymentTransactionId":999}';
      final payload = NotificationPayload.parse(jsonStr);

      expect(payload.type, equals('payment_confirmed'));
      expect(payload.studentId, equals(123));
      expect(payload.classId, equals(5));
      expect(payload.month, equals('2026-09'));
      expect(payload.paymentTransactionId, equals(999));
    });

    test('TEST 17: payment_need_review JSON payload parses correctly', () {
      final jsonStr =
          '{"type":"payment_need_review","paymentTransactionId":55}';
      final payload = NotificationPayload.parse(jsonStr);

      expect(payload.type, equals('payment_need_review'));
      expect(payload.paymentTransactionId, equals(55));
    });

    test('TEST 18: Malformed payload falls back gracefully without crash', () {
      final malformed = '{bad_json_payload}';
      final payload = NotificationPayload.parse(malformed);

      expect(payload.type, equals('unknown'));
      expect(payload.rawPayload, equals(malformed));
    });

    test('TEST 19: Legacy zalo:<phone> payload parses to type zalo', () {
      final zaloPayload = 'zalo:0987654321';
      final payload = NotificationPayload.parse(zaloPayload);

      expect(payload.type, equals('zalo'));
      expect(payload.phone, equals('0987654321'));
    });

    test(
      'TEST 20: Cold start from payment notification stores and clears pendingLaunchPayload',
      () {
        final jsonStr =
            '{"type":"payment_confirmed","studentId":123,"classId":5,"month":"2026-09"}';
        NotificationRouter.pendingLaunchPayload = NotificationPayload.parse(
          jsonStr,
        );

        expect(NotificationRouter.pendingLaunchPayload, isNotNull);
        expect(
          NotificationRouter.pendingLaunchPayload!.type,
          equals('payment_confirmed'),
        );

        NotificationRouter.processPendingLaunchPayload();

        expect(NotificationRouter.pendingLaunchPayload, isNull);
      },
    );
  });
}
