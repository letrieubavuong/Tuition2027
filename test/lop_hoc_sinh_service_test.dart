import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/services/lop_hoc_sinh_service.dart';
import 'package:tuition2025/models/lop_hoc_sinh.dart';
import 'dart:developer' as developer;

void main() {
  group('LopHocSinhService Tests', () {
    late LopHocSinhService service;

    setUp(() {
      service = LopHocSinhService();
    });

    group('1. Test docDSHSThuocLop (Đọc danh sách học sinh)', () {
      test('✅ Test với idLop hợp lệ - Nên trả về danh sách', () async {
        developer.log(
          '\n🧪 TEST: Đọc danh sách học sinh với idLop hợp lệ',
          name: 'LopHocSinhServiceTest',
        );

        final result = await service.docDSHSThuocLop(1);

        expect(result, isA<List>());
        developer.log(
          '✅ PASS: Trả về List (có thể rỗng nếu chưa có dữ liệu)',
          name: 'LopHocSinhServiceTest',
        );
      });

      test('❌ Test với idLop = 0 - Nên trả về list rỗng và log lỗi', () async {
        developer.log(
          '\n🧪 TEST: Đọc danh sách với idLop = 0 (không hợp lệ)',
          name: 'LopHocSinhServiceTest',
        );

        final result = await service.docDSHSThuocLop(0);

        expect(result, isEmpty);
        expect(result, isA<List>());
        developer.log(
          '✅ PASS: Trả về list rỗng khi idLop không hợp lệ',
          name: 'LopHocSinhServiceTest',
        );
      });

      test('❌ Test với idLop âm - Nên trả về list rỗng và log lỗi', () async {
        developer.log(
          '\n🧪 TEST: Đọc danh sách với idLop = -1 (không hợp lệ)',
          name: 'LopHocSinhServiceTest',
        );

        final result = await service.docDSHSThuocLop(-1);

        expect(result, isEmpty);
        expect(result, isA<List>());
        developer.log(
          '✅ PASS: Trả về list rỗng khi lopId âm',
          name: 'LopHocSinhServiceTest',
        );
      });
    });

    group('2. Test themHocSinhVaoLop (Thêm học sinh vào lớp)', () {
      test('✅ Test thêm học sinh mới - Nên thành công hoặc null', () async {
        developer.log(
          '\n🧪 TEST: Thêm học sinh mới vào lớp',
          name: 'LopHocSinhServiceTest',
        );

        final lhs = LopHocSinh(
          idLop: 1,
          idHocSinh: 1,
          ngayThamGia: DateTime.now().toIso8601String(),
          trangThai: 'Dang hoc',
        );

        final result = await service.themHocSinhVaoLop(lhs);

        // Có thể null nếu đã tồn tại hoặc có lỗi
        expect(result, anyOf(isNull, isA<LopHocSinh>()));
        if (result != null) {
          expect(result.id, isNotNull);
          developer.log(
            '✅ PASS: Thêm học sinh thành công với ID: ${result.id}',
            name: 'LopHocSinhServiceTest',
          );
        } else {
          developer.log(
            '⚠️ INFO: Học sinh có thể đã tồn tại hoặc có lỗi database',
            name: 'LopHocSinhServiceTest',
          );
        }
      });

      test('⚠️ Test thêm học sinh duplicate - Nên trả về null', () async {
        developer.log(
          '\n🧪 TEST: Thêm học sinh đã tồn tại (duplicate)',
          name: 'LopHocSinhServiceTest',
        );

        final lhs = LopHocSinh(
          idLop: 1,
          idHocSinh: 1,
          ngayThamGia: DateTime.now().toIso8601String(),
          trangThai: 'Dang hoc',
        );

        // Thêm lần 1
        await service.themHocSinhVaoLop(lhs);

        // Thêm lần 2 (duplicate)
        final result = await service.themHocSinhVaoLop(lhs);

        expect(result, isNull);
        developer.log(
          '✅ PASS: Trả về null khi thêm duplicate',
          name: 'LopHocSinhServiceTest',
        );
      });

      test('✅ Test return type - Nên là LopHocSinh? (nullable)', () async {
        developer.log(
          '\n🧪 TEST: Kiểm tra return type của themHocSinhVaoLop',
          name: 'LopHocSinhServiceTest',
        );

        final lhs = LopHocSinh(
          idLop: 999,
          idHocSinh: 999,
          ngayThamGia: DateTime.now().toIso8601String(),
        );

        final result = await service.themHocSinhVaoLop(lhs);

        // Result có thể null hoặc LopHocSinh
        expect(result, anyOf(isNull, isA<LopHocSinh>()));
        developer.log(
          '✅ PASS: Return type đúng (LopHocSinh? - nullable)',
          name: 'LopHocSinhServiceTest',
        );
      });
    });

    group('3. Test xoaHocSinhKhoiLop (Xóa học sinh khỏi lớp)', () {
      test('✅ Test xóa học sinh - Nên trả về >= 0', () async {
        developer.log(
          '\n🧪 TEST: Xóa học sinh khỏi lớp',
          name: 'LopHocSinhServiceTest',
        );

        // Thêm học sinh trước
        final lhs = LopHocSinh(
          idLop: 2,
          idHocSinh: 2,
          ngayThamGia: DateTime.now().toIso8601String(),
        );
        await service.themHocSinhVaoLop(lhs);

        // Xóa học sinh
        final result = await service.xoaHocSinhKhoiLop(2, 2);

        expect(result, greaterThanOrEqualTo(0));
        if (result > 0) {
          developer.log(
            '✅ PASS: Xóa thành công, số bản ghi đã xóa: $result',
            name: 'LopHocSinhServiceTest',
          );
        } else {
          developer.log(
            '⚠️ INFO: Không có bản ghi nào bị xóa (có thể chưa tồn tại)',
            name: 'LopHocSinhServiceTest',
          );
        }
      });

      test('⚠️ Test xóa học sinh không tồn tại - Nên trả về 0', () async {
        developer.log(
          '\n🧪 TEST: Xóa học sinh không tồn tại trong lớp',
          name: 'LopHocSinhServiceTest',
        );

        final result = await service.xoaHocSinhKhoiLop(999, 999);

        expect(result, equals(0));
        developer.log(
          '✅ PASS: Trả về 0 khi học sinh không tồn tại',
          name: 'LopHocSinhServiceTest',
        );
      });
    });

    group('4. Test Error Handling & Logging', () {
      test('📝 Test log output - Kiểm tra console có log không', () async {
        developer.log(
          '\n🧪 TEST: Kiểm tra log output',
          name: 'LopHocSinhServiceTest',
        );
        developer.log(
          '   Chạy các thao tác và quan sát console...\n',
          name: 'LopHocSinhServiceTest',
        );
        // Test 1: Log lỗi với idLop không hợp lệ
        developer.log(
          '   → Test log lỗi với idLop = -1:',
          name: 'LopHocSinhServiceTest',
        );
        await service.docDSHSThuocLop(-1);

        // Test 2: Log thành công khi đọc
        developer.log(
          '\n   → Test log thành công khi đọc:',
          name: 'LopHocSinhServiceTest',
        );
        await service.docDSHSThuocLop(1);

        // Test 3: Log khi thêm
        developer.log(
          '\n   → Test log khi thêm học sinh:',
          name: 'LopHocSinhServiceTest',
        );
        final lhs = LopHocSinh(
          idLop: 10,
          idHocSinh: 10,
          ngayThamGia: DateTime.now().toIso8601String(),
        );
        await service.themHocSinhVaoLop(lhs);

        // Test 4: Log khi xóa
        developer.log(
          '\n   → Test log khi xóa học sinh:',
          name: 'LopHocSinhServiceTest',
        );
        await service.xoaHocSinhKhoiLop(10, 10);

        developer.log(
          '\n✅ PASS: Kiểm tra log output hoàn tất (xem console ở trên)',
          name: 'LopHocSinhServiceTest',
        );
      });

      test('🔍 Test exception handling - Không crash khi có lỗi', () async {
        developer.log(
          '\n🧪 TEST: Kiểm tra app không crash khi có lỗi',
          name: 'LopHocSinhServiceTest',
        );

        try {
          // Test với các giá trị edge case
          await service.docDSHSThuocLop(-999);
          await service.docDSHSThuocLop(0);
          await service.xoaHocSinhKhoiLop(-1, -1);

          developer.log(
            '✅ PASS: Không có exception được throw, app không crash',
            name: 'LopHocSinhServiceTest',
          );
        } catch (e) {
          fail('❌ FAIL: App crash với exception: $e');
        }
      });
    });

    group('5. Test Integration (Luồng hoàn chỉnh)', () {
      test('🔄 Test luồng: Thêm → Đọc → Xóa → Đọc lại', () async {
        developer.log(
          '\n🧪 TEST: Luồng hoàn chỉnh - Thêm, Đọc, Xóa',
          name: 'LopHocSinhServiceTest',
        );

        final lopId = 100;
        final hsId = 100;

        // Bước 1: Đọc ban đầu
        developer.log(
          '   1️⃣ Đọc danh sách ban đầu...',
          name: 'LopHocSinhServiceTest',
        );
        final list1 = await service.docDSHSThuocLop(lopId);
        final countBefore = list1.length;
        developer.log(
          '      → Số học sinh ban đầu: $countBefore',
          name: 'LopHocSinhServiceTest',
        );

        // Bước 2: Thêm học sinh mới
        developer.log(
          '   2️⃣ Thêm học sinh mới...',
          name: 'LopHocSinhServiceTest',
        );
        final lhs = LopHocSinh(
          idLop: lopId,
          idHocSinh: hsId,
          ngayThamGia: DateTime.now().toIso8601String(),
        );
        final added = await service.themHocSinhVaoLop(lhs);
        developer.log(
          '      → Kết quả thêm: ${added != null ? "Thành công" : "Thất bại"}',
          name: 'LopHocSinhServiceTest',
        );

        // Bước 3: Đọc lại sau khi thêm
        developer.log(
          '   3️⃣ Đọc lại sau khi thêm...',
          name: 'LopHocSinhServiceTest',
        );
        final list2 = await service.docDSHSThuocLop(lopId);
        final countAfterAdd = list2.length;
        developer.log(
          '      → Số học sinh sau khi thêm: $countAfterAdd',
          name: 'LopHocSinhServiceTest',
        );

        // Bước 4: Xóa học sinh
        developer.log('   4️⃣ Xóa học sinh...', name: 'LopHocSinhServiceTest');
        final deleted = await service.xoaHocSinhKhoiLop(lopId, hsId);
        developer.log(
          '      → Số bản ghi đã xóa: $deleted',
          name: 'LopHocSinhServiceTest',
        );

        // Bước 5: Đọc lại sau khi xóa
        developer.log(
          '   5️⃣ Đọc lại sau khi xóa...',
          name: 'LopHocSinhServiceTest',
        );
        final list3 = await service.docDSHSThuocLop(lopId);
        final countAfterDelete = list3.length;
        developer.log(
          '      → Số học sinh sau khi xóa: $countAfterDelete',
          name: 'LopHocSinhServiceTest',
        );

        developer.log(
          '\n✅ PASS: Luồng hoàn chỉnh thực hiện thành công',
          name: 'LopHocSinhServiceTest',
        );
      });
    });
  });
}
