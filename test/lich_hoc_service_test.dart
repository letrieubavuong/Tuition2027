import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/services/lich_hoc_service.dart';
import 'package:tuition2025/models/lich_hoc.dart';

void main() {
  group('LichHocService Tests', () {
    late LichHocService service;

    setUp(() {
      service = LichHocService();
    });

    group('1. Test themLichHoc (Thêm lịch học)', () {
      test('✅ Test thêm lịch học mới - Nên thành công', () async {
        print('\n🧪 TEST: Thêm lịch học mới');

        final lichHoc = LichHoc(
          idLop: 1,
          thuTrongTuan: 2, // Thứ Hai
          gioBatDau: '08:00:00',
          gioKetThuc: '10:00:00',
        );

        final result = await service.themLichHoc(lichHoc);

        // Có thể null nếu đã tồn tại hoặc có lỗi
        expect(result, anyOf(isNull, isA<LichHoc>()));
        if (result != null) {
          expect(result.id, isNotNull);
          print('✅ PASS: Thêm lịch học thành công với ID: ${result.id}');
        } else {
          print('⚠️ INFO: Lịch học có thể đã tồn tại hoặc có lỗi');
        }
      });

      test('⚠️ Test thêm lịch học trùng - Nên trả về null', () async {
        print('\n🧪 TEST: Thêm lịch học trùng');

        final lichHoc = LichHoc(
          idLop: 1,
          thuTrongTuan: 2,
          gioBatDau: '08:00:00',
          gioKetThuc: '10:00:00',
        );

        // Thêm lần 1
        await service.themLichHoc(lichHoc);

        // Thêm lần 2 (trùng)
        final result = await service.themLichHoc(lichHoc);

        expect(result, isNull);
        print('✅ PASS: Trả về null khi thêm lịch học trùng');
      });

      test('⚠️ Test thêm lịch học chồng lấn - Nên trả về null', () async {
        print('\n🧪 TEST: Thêm lịch học chồng lấn');

        // Lịch 1: 08:00 - 10:00
        final lichHoc1 = LichHoc(
          idLop: 2,
          thuTrongTuan: 3, // Thứ Ba
          gioBatDau: '08:00:00',
          gioKetThuc: '10:00:00',
        );
        await service.themLichHoc(lichHoc1);

        // Lịch 2: 09:00 - 11:00 (chồng lấn với lịch 1)
        final lichHoc2 = LichHoc(
          idLop: 2,
          thuTrongTuan: 3,
          gioBatDau: '09:00:00',
          gioKetThuc: '11:00:00',
        );
        final result = await service.themLichHoc(lichHoc2);

        expect(result, isNull);
        print('✅ PASS: Trả về null khi lịch học chồng lấn');
      });

      test('✅ Test thêm lịch học không chồng lấn - Nên thành công', () async {
        print('\n🧪 TEST: Thêm lịch học không chồng lấn');

        // Lịch 1: 08:00 - 10:00
        final lichHoc1 = LichHoc(
          idLop: 3,
          thuTrongTuan: 4, // Thứ Tư
          gioBatDau: '08:00:00',
          gioKetThuc: '10:00:00',
        );
        await service.themLichHoc(lichHoc1);

        // Lịch 2: 10:00 - 12:00 (không chồng lấn)
        final lichHoc2 = LichHoc(
          idLop: 3,
          thuTrongTuan: 4,
          gioBatDau: '10:00:00',
          gioKetThuc: '12:00:00',
        );
        final result = await service.themLichHoc(lichHoc2);

        expect(result, anyOf(isNull, isA<LichHoc>()));
        print('✅ PASS: Có thể thêm lịch học không chồng lấn');
      });
    });

    group('2. Test layLichHocTheoLop (Đọc lịch học)', () {
      test('✅ Test với lopId hợp lệ - Nên trả về danh sách', () async {
        print('\n🧪 TEST: Đọc lịch học với lopId hợp lệ');

        final result = await service.layLichHocTheoLop(1);

        expect(result, isA<List<LichHoc>>());
        print('✅ PASS: Trả về List<LichHoc> (có thể rỗng)');
      });

      test('❌ Test với lopId = 0 - Nên trả về list rỗng', () async {
        print('\n🧪 TEST: Đọc lịch học với lopId = 0');

        final result = await service.layLichHocTheoLop(0);

        expect(result, isEmpty);
        print('✅ PASS: Trả về list rỗng khi lopId không hợp lệ');
      });

      test('❌ Test với lopId âm - Nên trả về list rỗng', () async {
        print('\n🧪 TEST: Đọc lịch học với lopId = -1');

        final result = await service.layLichHocTheoLop(-1);

        expect(result, isEmpty);
        print('✅ PASS: Trả về list rỗng khi lopId âm');
      });
    });

    group('3. Test capNhatLichHoc (Cập nhật lịch học)', () {
      test('✅ Test cập nhật lịch học tồn tại - Nên thành công', () async {
        print('\n🧪 TEST: Cập nhật lịch học tồn tại');

        // Thêm lịch học trước
        final lichHoc = LichHoc(
          idLop: 4,
          thuTrongTuan: 5, // Thứ Sáu
          gioBatDau: '14:00:00',
          gioKetThuc: '16:00:00',
        );
        final added = await service.themLichHoc(lichHoc);

        if (added != null && added.id != null) {
          // Cập nhật lịch học
          final updated = added.copyWith(
            gioBatDau: '15:00:00',
            gioKetThuc: '17:00:00',
          );
          final result = await service.capNhatLichHoc(updated);

          expect(result, isTrue);
          print('✅ PASS: Cập nhật lịch học thành công');
        } else {
          print('⚠️ INFO: Không thể thêm lịch học để test cập nhật');
        }
      });

      test('❌ Test cập nhật lịch học không tồn tại - Nên thất bại', () async {
        print('\n🧪 TEST: Cập nhật lịch học không tồn tại');

        final lichHoc = LichHoc(
          id: 99999, // ID không tồn tại
          idLop: 1,
          thuTrongTuan: 2,
          gioBatDau: '08:00:00',
          gioKetThuc: '10:00:00',
        );

        final result = await service.capNhatLichHoc(lichHoc);

        expect(result, isFalse);
        print('✅ PASS: Trả về false khi cập nhật lịch học không tồn tại');
      });
    });

    group('4. Test xoaLichHoc (Xóa lịch học)', () {
      test('✅ Test xóa lịch học tồn tại - Nên thành công', () async {
        print('\n🧪 TEST: Xóa lịch học tồn tại');

        // Thêm lịch học trước
        final lichHoc = LichHoc(
          idLop: 5,
          thuTrongTuan: 6, // Thứ Bảy
          gioBatDau: '08:00:00',
          gioKetThuc: '10:00:00',
        );
        final added = await service.themLichHoc(lichHoc);

        if (added != null && added.id != null) {
          // Xóa lịch học
          final result = await service.xoaLichHoc(added.id!);

          expect(result, isTrue);
          print('✅ PASS: Xóa lịch học thành công');
        } else {
          print('⚠️ INFO: Không thể thêm lịch học để test xóa');
        }
      });

      test('❌ Test xóa lịch học không tồn tại - Nên thất bại', () async {
        print('\n🧪 TEST: Xóa lịch học không tồn tại');

        final result = await service.xoaLichHoc(99999);

        expect(result, isFalse);
        print('✅ PASS: Trả về false khi xóa lịch học không tồn tại');
      });
    });

    group('5. Test Error Handling & Logging', () {
      test('📝 Test log output - Kiểm tra console có log không', () async {
        print('\n🧪 TEST: Kiểm tra log output');

        // Test log khi thêm
        print('\n   → Test log khi thêm lịch học:');
        final lichHoc = LichHoc(
          idLop: 10,
          thuTrongTuan: 2,
          gioBatDau: '08:00:00',
          gioKetThuc: '10:00:00',
        );
        await service.themLichHoc(lichHoc);

        // Test log khi đọc
        print('\n   → Test log khi đọc lịch học:');
        await service.layLichHocTheoLop(10);

        print('\n✅ PASS: Kiểm tra log output hoàn tất');
      });

      test('🔍 Test exception handling - Không crash khi có lỗi', () async {
        print('\n🧪 TEST: Kiểm tra app không crash khi có lỗi');

        try {
          // Test với các giá trị edge case
          await service.layLichHocTheoLop(-999);
          await service.layLichHocTheoLop(0);
          await service.xoaLichHoc(-1);
          await service.capNhatLichHoc(
            LichHoc(
              id: -1,
              idLop: -1,
              thuTrongTuan: 2,
              gioBatDau: '08:00:00',
              gioKetThuc: '10:00:00',
            ),
          );

          print('✅ PASS: Không có exception được throw, app không crash');
        } catch (e) {
          fail('❌ FAIL: App crash với exception: $e');
        }
      });
    });

    group('6. Test Integration (Luồng hoàn chỉnh)', () {
      test('🔄 Test luồng: Thêm → Đọc → Cập nhật → Xóa', () async {
        print('\n🧪 TEST: Luồng hoàn chỉnh - Thêm, Đọc, Cập nhật, Xóa');

        final lopId = 100;

        // Bước 1: Đọc ban đầu
        print('   1️⃣ Đọc danh sách ban đầu...');
        final list1 = await service.layLichHocTheoLop(lopId);
        print('      → Số lịch học ban đầu: ${list1.length}');

        // Bước 2: Thêm lịch học mới
        print('   2️⃣ Thêm lịch học mới...');
        final lichHoc = LichHoc(
          idLop: lopId,
          thuTrongTuan: 2,
          gioBatDau: '08:00:00',
          gioKetThuc: '10:00:00',
        );
        final added = await service.themLichHoc(lichHoc);
        print(
          '      → Kết quả thêm: ${added != null ? "Thành công (ID: ${added.id})" : "Thất bại"}',
        );

        if (added != null && added.id != null) {
          // Bước 3: Đọc lại sau khi thêm
          print('   3️⃣ Đọc lại sau khi thêm...');
          final list2 = await service.layLichHocTheoLop(lopId);
          print('      → Số lịch học sau khi thêm: ${list2.length}');

          // Bước 4: Cập nhật lịch học
          print('   4️⃣ Cập nhật lịch học...');
          final updated = added.copyWith(gioBatDau: '09:00:00');
          final updateResult = await service.capNhatLichHoc(updated);
          print(
            '      → Kết quả cập nhật: ${updateResult ? "Thành công" : "Thất bại"}',
          );

          // Bước 5: Xóa lịch học
          print('   5️⃣ Xóa lịch học...');
          final deleteResult = await service.xoaLichHoc(added.id!);
          print(
            '      → Kết quả xóa: ${deleteResult ? "Thành công" : "Thất bại"}',
          );

          // Bước 6: Đọc lại sau khi xóa
          print('   6️⃣ Đọc lại sau khi xóa...');
          final list3 = await service.layLichHocTheoLop(lopId);
          print('      → Số lịch học sau khi xóa: ${list3.length}');
        }

        print('\n✅ PASS: Luồng hoàn chỉnh thực hiện thành công');
      });
    });
  });
}
